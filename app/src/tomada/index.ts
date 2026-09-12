import type { Campo, Celula, Lancamento, Negocio, Problema, ResultadoLeitura, Template, Tipo } from './tipos'
import { detectar } from './detectar'
import { abrir } from './abrir'
import { acharTabelas } from './acharTabela'
import { perfilar } from './perfilar'
import { mapear } from './mapear'
import { limparTexto, normalizarDescricao, parseData, parseDinheiro } from './normalizar'
import { hashArquivo, hashLinha } from './dedup'
import { NEUTROS } from './sinonimos'

export * from './tipos'
export { detectar, abrir, acharTabelas, perfilar, mapear, hashLinha, hashArquivo }
export * from './normalizar'
export * from './areas'
export * from './lerArea'
export * from './dedup'

export interface OpcoesLeitura {
  fonteId: string
  negocio?: Negocio
  templates?: Template[]
  /** quando a tabela só tem valores positivos e o humano já disse o que é */
  tipoFixo?: Tipo
  tetoValor?: number
  /** anos aceitos: [passado, futuro] em relação a hoje */
  janelaAnos?: [number, number]
  hoje?: Date
}

/**
 * O pipeline inteiro para um arquivo, sem tocar no banco:
 * detectar → abrir → achar tabelas → perfilar → mapear → normalizar → hash.
 * Dedup contra o que já existe é do chamador (ver dedup.marcarDuplicatas) — aqui só se marca repetição dentro do arquivo.
 */
export async function lerArquivo(bytes: Uint8Array, nome: string, op: OpcoesLeitura): Promise<ResultadoLeitura> {
  const deteccao = detectar(bytes, nome)
  const grades = abrir(bytes, deteccao)
  const tabelas = grades.flatMap(acharTabelas)
  const perfis = tabelas.map(perfilar)
  const mapas = await Promise.all(tabelas.map((t, i) => mapear(t.cabecalho, perfis[i], op.templates)))

  const lancamentos: Lancamento[] = []
  const rejeitados: Problema[] = []
  const revisao: Problema[] = []
  const hoje = op.hoje ?? new Date()
  const [anosAtras, anosFrente] = op.janelaAnos ?? [10, 2]
  const vistos = new Set<string>()

  for (let t = 0; t < tabelas.length; t++) {
    const tabela = tabelas[t], perfil = perfis[t], mapa = mapas[t]
    const idx = (c: Campo) => Number(Object.keys(mapa.colunas).find((k) => mapa.colunas[Number(k)] === c) ?? -1)
    const iData = idx('data'), iDesc = idx('descricao'), iCat = idx('categoria'), iSub = idx('subcategoria')
    const iContra = idx('contraparte'), iRef = idx('referencia_externa'), iNeg = idx('negocio')
    const formatoData = perfil[iData]?.formatoData
    const template = op.templates?.find((x) => x.fingerprint === mapa.fingerprint)

    for (const linha of tabela.linhas) {
      const c = linha.celulas
      const prob = (codigo: Problema['codigo'], mensagem: string, campo?: Campo): Problema => ({ aba: tabela.aba, linha: linha.n, campo, codigo, mensagem })

      // data
      if (iData < 0) { rejeitados.push(prob('data_ausente', 'nenhuma coluna de data foi encontrada', 'data')); continue }
      const data = parseData(c[iData], formatoData, hoje.getFullYear())
      if (!data) { rejeitados.push(prob(c[iData] === null ? 'data_ausente' : 'data_invalida', `data "${limparTexto(c[iData])}" não reconhecida`, 'data')); continue }
      const ano = Number(data.slice(0, 4))
      if (ano < hoje.getFullYear() - anosAtras || ano > hoje.getFullYear() + anosFrente) {
        rejeitados.push(prob('data_fora_da_janela', `data ${data} fora da janela aceita`, 'data')); continue
      }

      // valor + tipo
      let valor: number | null = null
      let tipo: Tipo | null = null
      const s = mapa.sinal
      const dinheiro = (i: number) => parseDinheiro(c[i], perfil[i]?.estiloMoeda)
      if (s.modo === 'debito_credito') {
        const d = dinheiro(s.debito), cr = dinheiro(s.credito)
        if (d !== null && d !== 0) { valor = Math.abs(d); tipo = 'SAIDA' }
        else if (cr !== null && cr !== 0) { valor = Math.abs(cr); tipo = 'ENTRADA' }
      } else if (s.valor >= 0) {
        const v = dinheiro(s.valor)
        if (v !== null) {
          valor = Math.abs(v)
          if (s.modo === 'sinal') tipo = v < 0 ? 'SAIDA' : 'ENTRADA'
          else if (s.modo === 'flag') {
            const f = limparTexto(c[s.flag]).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
            tipo = s.saida.includes(f) ? 'SAIDA' : 'ENTRADA'
          } else {
            tipo = op.tipoFixo ?? template?.tipoFixo ?? (v < 0 ? 'SAIDA' : null)
          }
        }
      }
      if (valor === null) { rejeitados.push(prob('valor_ausente', 'linha sem valor', 'valor')); continue }
      if (valor === 0) { rejeitados.push(prob('valor_invalido', 'valor zero', 'valor')); continue }
      if (!tipo) { rejeitados.push(prob('tipo_indeterminado', 'não dá para saber se é entrada ou saída: valores só positivos e sem coluna de tipo', 'valor')); continue }

      // texto
      const descricao = limparTexto(iDesc >= 0 ? c[iDesc] : null) || limparTexto(iContra >= 0 ? c[iContra] : null)
      if (!descricao) { rejeitados.push(prob('descricao_ausente', 'linha sem descrição', 'descricao')); continue }
      const descricaoNormalizada = normalizarDescricao(descricao)

      const extras: Record<string, Celula> = {}
      tabela.cabecalho.forEach((h, i) => { if (!(i in mapa.colunas) && perfil[i]?.tipo !== 'vazia' && c[i] !== null) extras[h] = c[i] })

      const neutro = NEUTROS.find(([, re]) => re.test(descricaoNormalizada))
      const l: Lancamento = {
        data, tipo, valor, descricao, descricaoNormalizada,
        categoria: neutro ? neutro[0] : (iCat >= 0 ? limparTexto(c[iCat]) || undefined : undefined),
        subcategoria: iSub >= 0 ? limparTexto(c[iSub]) || undefined : undefined,
        contraparte: iContra >= 0 ? limparTexto(c[iContra]) || undefined : undefined,
        referenciaExterna: iRef >= 0 ? limparTexto(c[iRef]) || undefined : undefined,
        negocio: (iNeg >= 0 ? (limparTexto(c[iNeg]).toLowerCase() as Negocio) : undefined) ?? op.negocio,
        extras, origem: { aba: tabela.aba, linha: linha.n }, hashLinha: '', neutro: !!neutro,
      }
      l.hashLinha = await hashLinha(op.fonteId, l)
      if (vistos.has(l.hashLinha)) { revisao.push(prob('duplicado_no_arquivo', 'linha idêntica a outra no mesmo arquivo')); }
      vistos.add(l.hashLinha)
      if (op.tetoValor && valor > op.tetoValor) revisao.push(prob('acima_do_teto', `R$ ${valor.toFixed(2)} acima do teto da fonte`, 'valor'))
      lancamentos.push(l)
    }
  }

  return { deteccao, hashArquivo: await hashArquivo(bytes), tabelas, perfis, mapas, lancamentos, rejeitados, revisao }
}

/** O pipeline inteiro para uma área que não é finanças (gado, estoque, almoxarifado, ferramentas, pasto). */
export async function lerArquivoArea(bytes: Uint8Array, nome: string, op: OpcoesLeitura & { area: Exclude<import('./areas').Area, 'financas'>; origemRegistro?: import('./lerArea').OrigemRegistro }) {
  const { mapearArea, registrosDaArea } = await import('./lerArea')
  const deteccao = detectar(bytes, nome)
  const grades = abrir(bytes, deteccao)
  const tabelas = grades.flatMap(acharTabelas)
  const perfis = tabelas.map(perfilar)
  const mapas = await Promise.all(tabelas.map((t, i) => mapearArea(op.area, t.cabecalho, perfis[i])))
  const registros = []
  const rejeitados = []
  for (let i = 0; i < tabelas.length; i++) {
    const r = await registrosDaArea(tabelas[i], perfis[i], mapas[i], { fonteId: op.fonteId, area: op.area, origemRegistro: op.origemRegistro, hoje: op.hoje })
    registros.push(...r.registros); rejeitados.push(...r.rejeitados)
  }
  return { deteccao, hashArquivo: await hashArquivo(bytes), tabelas, perfis, mapas, registros, rejeitados }
}

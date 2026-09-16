import type { Campo, Celula, PerfilColuna, Problema, Tabela } from './tipos'
import { AREAS, EVENTOS_GADO, OBRIGATORIOS, SINONIMOS_AREA, TIPOS_MOV_ESTOQUE, type Area } from './areas'
import { limparTexto, normalizarCabecalho, normalizarDescricao, parseData, parseDinheiro } from './normalizar'
import { fingerprint } from './mapear'
import { sha256Hex } from './dedup'

export type OrigemRegistro = 'leitura' | 'http' | 'abertura' | 'manual'

/** Registro canônico de uma área que não é finanças. Campos variam por área; origem e hash não. */
export interface RegistroArea {
  area: Area
  campos: Record<string, string | number | null>
  extras: Record<string, Celula>
  origem: { aba: string; linha: number }
  origemRegistro: OrigemRegistro
  hashLinha: string
}

export interface MapaArea {
  colunas: Record<number, string>
  fingerprint: string
}

const idxDe = (colunas: Record<number, string>, campo: string) =>
  Number(Object.keys(colunas).find((k) => colunas[Number(k)] === campo) ?? -1)

/** Mapeia cabeçalhos para o canônico da área, com o mesmo cuidado de `mapear`: dicionário + coerência com o perfil. */
export async function mapearArea(area: Exclude<Area, 'financas'>, cabecalho: string[], perfis: PerfilColuna[]): Promise<MapaArea> {
  const dic = SINONIMOS_AREA[area]
  const colunas: Record<number, string> = {}
  const usados = new Set<string>()
  const casar = (h: string): string | null => {
    const n = normalizarCabecalho(h)
    if (!n) return null
    for (const [campo, termos] of dic) if (termos.includes(n)) return campo
    for (const [campo, termos] of dic) for (const t of termos) if (t.length >= 4 && n.startsWith(t + ' ')) return campo
    for (const [campo, termos] of dic) for (const t of termos) if (t.length >= 5 && n.includes(t)) return campo
    return null
  }
  cabecalho.forEach((h, i) => {
    const p = perfis[i]
    if (p?.tipo === 'vazia') return
    let campo = casar(h)
    if (campo && usados.has(campo)) return
    // coerência: campo numérico precisa de coluna numérica, data precisa de data
    const numericos = ['peso_kg', 'quantidade', 'custo_unitario', 'minimo', 'area_ha', 'capacidade_ua']
    if (campo && numericos.includes(campo) && p && !['dinheiro', 'inteiro'].includes(p.tipo)) campo = null
    if (campo === 'data' || campo === 'nascimento') { if (p && p.tipo !== 'data') campo = null }
    if (!campo) return
    colunas[i] = campo
    usados.add(campo)
  })
  // sem coluna de data mapeada: a primeira coluna de data serve
  if (!usados.has('data')) {
    const d = perfis.find((p) => p.tipo === 'data' && !(p.indice in colunas))
    if (d) { colunas[d.indice] = 'data'; usados.add('data') }
  }
  return { colunas, fingerprint: await fingerprint(cabecalho) }
}

function classificar(valor: string, tabela: Array<[string, RegExp]>): string | null {
  const n = normalizarDescricao(valor)
  for (const [nome, re] of tabela) if (re.test(n)) return nome
  return null
}

export interface OpcoesArea {
  fonteId: string
  area: Exclude<Area, 'financas'>
  origemRegistro?: OrigemRegistro
  hoje?: Date
}

/** Etapas 6–10 para uma área que não é finanças: normaliza, valida obrigatórios e gera hash. */
export async function registrosDaArea(tabela: Tabela, perfis: PerfilColuna[], mapa: MapaArea, op: OpcoesArea): Promise<{ registros: RegistroArea[]; rejeitados: Problema[] }> {
  const registros: RegistroArea[] = []
  const rejeitados: Problema[] = []
  const hoje = op.hoje ?? new Date()
  const { colunas } = mapa
  const NUM = new Set(['peso_kg', 'quantidade', 'custo_unitario', 'minimo', 'area_ha', 'capacidade_ua'])
  const DATAS = new Set(['data', 'nascimento'])

  for (const linha of tabela.linhas) {
    const c = linha.celulas
    const campos: Record<string, string | number | null> = {}
    for (const k of Object.keys(colunas)) {
      const i = Number(k), campo = colunas[i], bruto = c[i]
      if (NUM.has(campo)) {
        const n = parseDinheiro(bruto, perfis[i]?.estiloMoeda)
        campos[campo] = n === null ? null : Math.abs(n)
      } else if (DATAS.has(campo)) {
        campos[campo] = parseData(bruto, perfis[i]?.formatoData, hoje.getFullYear())
      } else {
        campos[campo] = limparTexto(bruto) || null
      }
    }

    // Coluna em arrobas: guarda a arroba como veio e converte a 15 kg/@ (padrão brasileiro).
    // Se a planilha registra arroba de carcaça, o kg derivado é kg de carcaça — ver PERGUNTAS.md A19.
    const iPeso = idxDe(colunas, 'peso_kg')
    if (iPeso >= 0 && /arroba|@/i.test(tabela.cabecalho[iPeso]) && typeof campos.peso_kg === 'number') {
      campos.arrobas = campos.peso_kg
      campos.peso_kg = Math.round(campos.peso_kg * 15 * 100) / 100
    }
    // eventos e tipos de movimento: texto livre → vocabulário fechado
    if (op.area === 'gado' && typeof campos.evento === 'string') campos.evento = classificar(campos.evento, EVENTOS_GADO) ?? campos.evento
    if (op.area === 'gado' && !campos.evento) campos.evento = campos.peso_kg != null ? 'pesagem' : null
    if ((op.area === 'estoque' || op.area === 'almoxarifado') && typeof campos.tipo_mov === 'string') {
      campos.tipo_mov = classificar(campos.tipo_mov, TIPOS_MOV_ESTOQUE) ?? campos.tipo_mov
    }
    if ((op.area === 'estoque' || op.area === 'almoxarifado') && !campos.tipo_mov) {
      campos.tipo_mov = op.origemRegistro === 'abertura' ? 'saldo' : null
    }

    // quantidade zero: num movimento não existe; num saldo é estoque zerado, legítimo
    if ((op.area === 'estoque' || op.area === 'almoxarifado') && campos.quantidade === 0 && campos.tipo_mov !== 'saldo') {
      rejeitados.push({ aba: tabela.aba, linha: linha.n, campo: 'valor' as Campo, codigo: 'valor_invalido', mensagem: 'movimento com quantidade zero' })
      continue
    }

    // obrigatórios da área: grupos em OU
    const faltando = OBRIGATORIOS[op.area].find((grupo) => grupo.every((campo) => campos[campo] === null || campos[campo] === undefined))
    if (faltando) {
      rejeitados.push({
        aba: tabela.aba, linha: linha.n, campo: faltando[0] as Campo,
        codigo: faltando.includes('data') ? 'data_ausente' : 'descricao_ausente',
        mensagem: `linha sem ${faltando.join(' nem ')}`,
      })
      continue
    }

    const extras: Record<string, Celula> = {}
    tabela.cabecalho.forEach((h, i) => { if (!(i in colunas) && perfis[i]?.tipo !== 'vazia' && c[i] !== null) extras[h] = c[i] })

    const chave = [op.fonteId, op.area, campos.brinco ?? campos.item ?? campos.pasto ?? '', campos.lote ?? '', campos.data ?? '', campos.evento ?? campos.tipo_mov ?? '', campos.peso_kg ?? campos.quantidade ?? '', campos.responsavel ?? ''].join('|')
    registros.push({
      area: op.area, campos, extras,
      origem: { aba: tabela.aba, linha: linha.n },
      origemRegistro: op.origemRegistro ?? 'leitura',
      hashLinha: await sha256Hex(chave),
    })
  }
  return { registros, rejeitados }
}

export { AREAS, type Area }

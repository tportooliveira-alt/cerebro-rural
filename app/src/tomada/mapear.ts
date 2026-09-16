import type { Campo, ConvencaoSinal, Mapa, OrigemMapa, PerfilColuna, Template } from './tipos'
import { SINONIMOS } from './sinonimos'
import { normalizarCabecalho } from './normalizar'
import { sha256Hex } from './dedup'

export async function fingerprint(cabecalho: string[]): Promise<string> {
  return sha256Hex(cabecalho.map(normalizarCabecalho).join('|'))
}

/** Tenta casar um cabeçalho com o dicionário: igual, depois começa-com, depois contém (só para termos ≥ 4 letras). */
export function campoPorSinonimo(cabecalho: string): Campo | null {
  const h = normalizarCabecalho(cabecalho)
  if (!h) return null
  for (const [campo, termos] of SINONIMOS) if (termos.includes(h)) return campo
  for (const [campo, termos] of SINONIMOS) for (const t of termos) if (t.length >= 4 && h.startsWith(t + ' ')) return campo
  for (const [campo, termos] of SINONIMOS) for (const t of termos) if (t.length >= 5 && h.includes(t)) return campo
  return null
}

/**
 * Convenção de sinal a partir do que foi mapeado e dos perfis:
 *  débito+crédito → duas colunas · valor com negativos → sinal · valor + flag → flag · só positivo → perguntar
 */
export function detectarSinal(colunas: Record<number, Campo>, perfis: PerfilColuna[]): ConvencaoSinal {
  const idx = (c: Campo) => Number(Object.keys(colunas).find((k) => colunas[Number(k)] === c) ?? -1)
  const debito = idx('debito'), credito = idx('credito'), valor = idx('valor'), flag = idx('flag_dc')
  if (debito >= 0 && credito >= 0) return { modo: 'debito_credito', debito, credito }
  if (valor >= 0) {
    const p = perfis[valor]
    if (p?.temNegativos) return { modo: 'sinal', valor }
    if (flag >= 0) return { modo: 'flag', valor, flag, saida: ['d', 'debito', 'saida', 's', '-', 'pago', 'despesa', 'debit'] }
    return { modo: 'perguntar', valor }
  }
  // só uma das duas: trata como valor com tipo fixo
  if (debito >= 0) return { modo: 'perguntar', valor: debito }
  if (credito >= 0) return { modo: 'perguntar', valor: credito }
  return { modo: 'perguntar', valor: -1 }
}

/**
 * Monta o mapa: template da fonte (se o fingerprint bater) → sinônimos → sobra sem mapa (para IA/humano).
 * Perfil corrige o dicionário: cabeçalho "valor" que na verdade é data, ou vice-versa, não passa.
 */
export async function mapear(cabecalho: string[], perfis: PerfilColuna[], templates: Template[] = []): Promise<Mapa> {
  const fp = await fingerprint(cabecalho)
  const tpl = templates.find((t) => t.fingerprint === fp)
  if (tpl) {
    const origem: Record<number, OrigemMapa> = {}
    for (const k of Object.keys(tpl.colunas)) origem[Number(k)] = 'template'
    return { colunas: { ...tpl.colunas }, origem, sinal: tpl.sinal, fingerprint: fp }
  }

  const colunas: Record<number, Campo> = {}
  const origem: Record<number, OrigemMapa> = {}
  const usados = new Set<Campo>()

  cabecalho.forEach((h, i) => {
    const p = perfis[i]
    if (p?.tipo === 'vazia') return
    let campo = campoPorSinonimo(h)
    // coerência com o perfil
    if (campo === 'data' && p && p.tipo !== 'data' && p.confianca > 0) campo = null
    if ((campo === 'valor' || campo === 'debito' || campo === 'credito') && p && p.tipo !== 'dinheiro' && p.tipo !== 'inteiro') campo = null
    if (campo === 'flag_dc' && p && p.tipo !== 'flag_dc' && p.tipo !== 'categoria') campo = null
    if (campo === 'referencia_externa' && p && p.tipo === 'dinheiro') campo = null
    if (!campo) {
      // sem sinônimo: o perfil ainda pode salvar a coluna
      if (p?.tipo === 'data' && !usados.has('data')) campo = 'data'
      else if (p?.tipo === 'flag_dc' && !usados.has('flag_dc')) campo = 'flag_dc'
    }
    if (!campo) return
    // campos únicos não se repetem; 'descricao' repetida vira extras
    if (usados.has(campo) && campo !== 'categoria') return
    colunas[i] = campo
    origem[i] = 'sinonimo'
    usados.add(campo)
  })

  // se não achou coluna de valor por nome, pega a coluna dinheiro de maior confiança
  if (!usados.has('valor') && !usados.has('debito') && !usados.has('credito')) {
    const dinheiro = perfis.filter((p) => p.tipo === 'dinheiro' && !(p.indice in colunas)).sort((a, b) => b.confianca - a.confianca)
    if (dinheiro.length >= 2 && !dinheiro[0].temNegativos && !dinheiro[1].temNegativos) {
      // duas colunas de dinheiro sem sinal e sem nome claro: a mais preenchida é débito (despesa é mais frequente)
      const [a, b] = dinheiro
      colunas[a.indice] = 'debito'; colunas[b.indice] = 'credito'
      origem[a.indice] = origem[b.indice] = 'sinonimo'
    } else if (dinheiro[0]) {
      colunas[dinheiro[0].indice] = 'valor'; origem[dinheiro[0].indice] = 'sinonimo'
    }
  }
  // sem descrição por nome: a coluna de texto mais variada
  if (!usados.has('descricao')) {
    const texto = perfis.filter((p) => (p.tipo === 'texto') && !(p.indice in colunas)).sort((a, b) => b.distintos - a.distintos)
    if (texto[0]) { colunas[texto[0].indice] = 'descricao'; origem[texto[0].indice] = 'sinonimo' }
  }

  return { colunas, origem, sinal: detectarSinal(colunas, perfis), fingerprint: fp }
}

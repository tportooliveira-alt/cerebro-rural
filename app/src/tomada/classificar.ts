import { REGRAS } from './plano-de-contas'
import type { Tipo } from './tipos'

export type OrigemClassificacao = 'regra' | 'memoria' | 'ia' | 'manual' | 'coluna'

export interface Classificacao {
  categoria?: string
  subcategoria?: string
  origem: OrigemClassificacao
}

/** Memória: descrição normalizada → o que um humano já disse que era, nesta fazenda. */
export type Memoria = Map<string, { categoria: string; subcategoria?: string }>

/**
 * Três camadas, parando na primeira que resolve (TOMADA.md §7):
 *   1. o que a própria planilha trouxe numa coluna de categoria
 *   2. memória — alguém já classificou esta mesma descrição antes
 *   3. regras do plano de contas
 * A IA é a quarta e entra só no Painel, marcada como sugestão. Sem palpite silencioso:
 * o que não casar volta sem categoria e aparece como "sem categoria" no Painel.
 */
export function classificar(
  descricaoNormalizada: string,
  tipo: Tipo,
  daColuna?: string,
  memoria?: Memoria,
): Classificacao {
  if (daColuna) return { categoria: daColuna, origem: 'coluna' }

  const lembrado = memoria?.get(descricaoNormalizada)
  if (lembrado) return { ...lembrado, origem: 'memoria' }

  for (const r of REGRAS) {
    if (r.tipo && r.tipo !== tipo) continue
    if (r.re.test(descricaoNormalizada)) return { categoria: r.categoria, subcategoria: r.subcategoria, origem: 'regra' }
  }
  return { origem: 'regra' }
}

import type { Lancamento } from './tipos'

const enc = new TextEncoder()

export async function sha256Hex(dados: string | Uint8Array): Promise<string> {
  const bytes = typeof dados === 'string' ? enc.encode(dados) : dados
  const buf = await crypto.subtle.digest('SHA-256', bytes as BufferSource)
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, '0')).join('')
}

export const hashArquivo = (bytes: Uint8Array) => sha256Hex(bytes)

/**
 * Chave de idempotência da linha. Mesma fonte + mesma data + mesmo valor + mesma descrição
 * normalizada + mesma referência externa = o mesmo lançamento, venha de que arquivo vier.
 */
export function chaveLinha(fonteId: string, l: Pick<Lancamento, 'data' | 'valor' | 'tipo' | 'descricaoNormalizada' | 'referenciaExterna'>): string {
  return [fonteId, l.data, l.valor.toFixed(2), l.tipo, l.descricaoNormalizada, l.referenciaExterna ?? ''].join('|')
}

export const hashLinha = (fonteId: string, l: Parameters<typeof chaveLinha>[1]) => sha256Hex(chaveLinha(fonteId, l))

export interface Marcacao {
  indice: number
  resultado: 'nova' | 'duplicada' | 'provavel'
  /** hash (duplicada) ou id/hash do par (provável) */
  par?: string
}

export interface Existente {
  hashLinha: string
  data: string
  valor: number
  fonteId: string
  id?: string
}

/**
 * Marca cada lançamento do arquivo contra o que já existe:
 *  - hash igual → duplicada (não grava)
 *  - mesma data + mesmo valor em OUTRA fonte → provável (vai para revisão, grava como pendente)
 *  - repetida dentro do próprio arquivo → duplicada
 */
export function marcarDuplicatas(fonteId: string, novos: Lancamento[], existentes: Existente[]): Marcacao[] {
  const porHash = new Map(existentes.map((e) => [e.hashLinha, e]))
  const porDataValor = new Map<string, Existente[]>()
  for (const e of existentes) {
    if (e.fonteId === fonteId) continue
    const k = `${e.data}|${e.valor.toFixed(2)}`
    porDataValor.set(k, [...(porDataValor.get(k) ?? []), e])
  }
  const vistosNoArquivo = new Set<string>()
  return novos.map((l, indice) => {
    if (porHash.has(l.hashLinha) || vistosNoArquivo.has(l.hashLinha)) {
      return { indice, resultado: 'duplicada', par: porHash.get(l.hashLinha)?.id ?? l.hashLinha }
    }
    vistosNoArquivo.add(l.hashLinha)
    const pares = porDataValor.get(`${l.data}|${l.valor.toFixed(2)}`)
    if (pares?.length) return { indice, resultado: 'provavel', par: pares[0].id ?? pares[0].hashLinha }
    return { indice, resultado: 'nova' }
  })
}

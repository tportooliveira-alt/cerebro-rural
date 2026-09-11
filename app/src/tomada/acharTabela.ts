import type { Celula, Grade, LinhaIgnorada, LinhaTabela, Tabela } from './tipos'
import { limparTexto } from './normalizar'

const RODAPE = /\b(total|totais|soma|somatorio|saldo|subtotal|sub total|resumo)\b|^\s*s\s+a\s+l\s+d\s+o\s*$/i
const TOPO = /\b(saldo anterior|saldo inicial|saldo do dia anterior)\b/i

const vazia = (c: Celula) => c === null || c === undefined || (typeof c === 'string' && c.trim() === '')
const linhaVazia = (l: Celula[]) => l.every(vazia)
const ehTexto = (c: Celula) => typeof c === 'string' && c.trim() !== '' && !/^[\d.,\s\-R$()]+$/.test(c)
const ehNumero = (c: Celula) => typeof c === 'number' || (typeof c === 'string' && /^\s*[-(]?\s*R?\$?\s*[\d.,]+\s*[)\-]?\s*[dDcC]?\s*$/.test(c) && /\d/.test(c))
const ehData = (c: Celula) => c instanceof Date || (typeof c === 'string' && /^\s*\d{1,2}[/\-.]\d{1,2}([/\-.]\d{2,4})?\s*$/.test(c)) || (typeof c === 'string' && /^\d{4}-\d{2}-\d{2}/.test(c)) || (typeof c === 'string' && /^\d{8}(\d{6})?(\[.*\])?$/.test(c.trim()))

/** Assinatura de tipo de uma célula para medir consistência entre linhas. */
function assinatura(c: Celula): string {
  if (vazia(c)) return '_'
  if (c instanceof Date || ehData(c)) return 'd'
  if (ehNumero(c)) return 'n'
  if (typeof c === 'boolean') return 'b'
  return 't'
}

/** Uma linha parece cabeçalho se tem ≥ 3 textos e nenhum número/data "de dado". */
function pareceCabecalho(l: Celula[]): boolean {
  const textos = l.filter(ehTexto).length
  const dados = l.filter((c) => !vazia(c) && (ehNumero(c) || ehData(c))).length
  return textos >= 3 && dados === 0 && textos >= l.filter((c) => !vazia(c)).length * 0.8
}

/** Mede se as `n` linhas seguintes têm tipos consistentes coluna a coluna (0..1). */
function consistencia(linhas: Celula[][], inicio: number, largura: number, n = 5): number {
  const amostra: Celula[][] = []
  for (let i = inicio; i < linhas.length && amostra.length < n; i++) if (!linhaVazia(linhas[i])) amostra.push(linhas[i])
  if (amostra.length < 2) return 0
  let colunasOk = 0, colunasAvaliadas = 0
  for (let c = 0; c < largura; c++) {
    const tipos = amostra.map((l) => assinatura(l[c] ?? null)).filter((t) => t !== '_')
    if (tipos.length < 2) continue
    colunasAvaliadas++
    const dominante = Math.max(...['d', 'n', 't', 'b'].map((t) => tipos.filter((x) => x === t).length))
    if (dominante / tipos.length >= 0.7) colunasOk++
  }
  return colunasAvaliadas ? colunasOk / colunasAvaliadas : 0
}

/**
 * Encontra as tabelas de verdade dentro de uma aba: pula título, acha o cabeçalho,
 * corta rodapé de totais e "saldo anterior", e repete para achar uma segunda tabela.
 * Devolve também o que ignorou, com número de linha e motivo — a prévia mostra os dois.
 */
export function acharTabelas(grade: Grade): Tabela[] {
  const L = grade.linhas
  const largura = Math.max(0, ...L.map((l) => l.length))
  const tabelas: Tabela[] = []
  let i = 0

  while (i < L.length) {
    // 1. procurar cabeçalho a partir de i
    let h = -1
    for (let k = i; k < L.length; k++) {
      if (pareceCabecalho(L[k]) && consistencia(L, k + 1, largura) >= 0.6) { h = k; break }
    }
    if (h < 0) {
      // sem cabeçalho detectável: se a aba inteira parece dados sem cabeçalho, cria cabeçalho posicional
      if (tabelas.length === 0 && L.filter((l) => !linhaVazia(l)).length >= 2 && consistencia(L, i, largura) >= 0.6) {
        h = i - 1 // cabeçalho virtual
      } else break
    }
    const cabecalho = h >= 0
      ? Array.from({ length: largura }, (_, c) => limparTexto(L[h][c] ?? null) || `coluna_${c + 1}`)
      : Array.from({ length: largura }, (_, c) => `coluna_${c + 1}`)

    const ignoradas: LinhaIgnorada[] = []
    for (let k = i; k < h; k++) if (!linhaVazia(L[k])) ignoradas.push({ n: k + 1, celulas: L[k], motivo: 'acima do cabeçalho (título)' })

    // 2. bloco: do cabeçalho até 2 linhas vazias seguidas ou até outro cabeçalho
    const linhas: LinhaTabela[] = []
    let k = h + 1
    let vaziasSeguidas = 0
    for (; k < L.length; k++) {
      const l = L[k]
      if (linhaVazia(l)) { vaziasSeguidas++; if (vaziasSeguidas >= 2) break; continue }
      if (vaziasSeguidas >= 1 && pareceCabecalho(l) && consistencia(L, k + 1, largura) >= 0.6) break // próxima tabela
      vaziasSeguidas = 0
      linhas.push({ n: k + 1, celulas: Array.from({ length: largura }, (_, c) => l[c] ?? null) })
    }

    // 3. cortar topo "saldo anterior" e rodapé de totais / só números
    while (linhas.length && linhas[0].celulas.some((c) => typeof c === 'string' && TOPO.test(c))) {
      const l = linhas.shift()!; ignoradas.push({ ...l, motivo: 'saldo anterior' })
    }
    while (linhas.length) {
      const ult = linhas[linhas.length - 1]
      const textos = ult.celulas.filter(ehTexto)
      const soNumeros = textos.length === 0 && ult.celulas.some(ehNumero)
      const total = ult.celulas.some((c) => typeof c === 'string' && RODAPE.test(c))
      if (total) { linhas.pop(); ignoradas.push({ ...ult, motivo: 'linha de total' }); continue }
      if (soNumeros) { linhas.pop(); ignoradas.push({ ...ult, motivo: 'só números, sem descrição (rodapé)' }); continue }
      break
    }
    // totais no meio (subtotal por mês) também saem
    for (let j = linhas.length - 1; j >= 0; j--) {
      if (linhas[j].celulas.some((c) => typeof c === 'string' && RODAPE.test(c) && c.trim().split(/\s+/).length <= 4)) {
        ignoradas.push({ ...linhas[j], motivo: 'linha de total' }); linhas.splice(j, 1)
      }
    }

    if (linhas.length) tabelas.push({ aba: grade.aba, linhaCabecalho: h + 1, cabecalho, linhas, ignoradas: ignoradas.sort((a, b) => a.n - b.n) })
    i = Math.max(k, h + 1)
    if (i <= h) break
  }
  return tabelas
}

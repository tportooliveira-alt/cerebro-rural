import type { Celula, PerfilColuna, Tabela, TipoColuna } from './tipos'
import { inferirEstiloMoeda, inferirFormatoData, parseData, parseDinheiro } from './normalizar'

const FLAGS = new Set(['d', 'c', 'debito', 'credito', 'saida', 'entrada', 's', 'e', '+', '-', 'pago', 'recebido', 'despesa', 'receita', 'debit', 'credit'])
const vazia = (c: Celula) => c === null || c === undefined || (typeof c === 'string' && c.trim() === '')
const norm = (c: Celula) => String(c).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().trim()

/** Infere o tipo de cada coluna a partir de uma amostra de até 200 valores. */
export function perfilar(tabela: Tabela): PerfilColuna[] {
  const largura = tabela.cabecalho.length
  const amostra = tabela.linhas.slice(0, 200)
  return Array.from({ length: largura }, (_, indice) => {
    const valores = amostra.map((l) => l.celulas[indice] ?? null)
    const cheios = valores.filter((v) => !vazia(v))
    const total = valores.length
    const vazios = total - cheios.length
    const distintos = new Set(cheios.map((v) => norm(v))).size
    const base = { indice, cabecalho: tabela.cabecalho[indice], distintos, vazios, total }

    if (total === 0 || cheios.length / Math.max(total, 1) < 0.05) return { ...base, tipo: 'vazia' as TipoColuna, confianca: 1 }

    const n = cheios.length
    const formatoData = inferirFormatoData(cheios)
    const datas = cheios.filter((v) => parseData(v, formatoData) !== null).length
    const estiloMoeda = inferirEstiloMoeda(cheios)
    const numeros = cheios.map((v) => parseDinheiro(v, estiloMoeda)).filter((x): x is number => x !== null)
    const inteiros = numeros.filter((x) => Number.isInteger(x)).length
    const flags = cheios.filter((v) => FLAGS.has(norm(v))).length
    const textos = cheios.filter((v) => typeof v === 'string' && !/^[\d.,\s\-R$()]+$/.test(v)).length

    // datas: números "pareceriam" dinheiro também — data ganha se a coluna bate como data e o cabeçalho ou o formato indicam
    const pareceDataPeloCabecalho = /\b(data|dt|dia|venc|emiss|compet|date)\b/i.test(tabela.cabecalho[indice])
    if (datas / n >= 0.8 && (formatoData !== 'serial' || pareceDataPeloCabecalho || datas === n && numeros.length < n)) {
      return { ...base, tipo: 'data', confianca: datas / n, formatoData }
    }
    if (flags / n >= 0.9 && distintos <= 4) return { ...base, tipo: 'flag_dc', confianca: flags / n }
    if (numeros.length / n >= 0.8) {
      const temNegativos = numeros.some((x) => x < 0)
      const temCentavos = cheios.some((v) => typeof v === 'string' && /[,.]\d{2}\b/.test(v)) || numeros.some((x) => !Number.isInteger(x))
      const pareceId = inteiros === numeros.length && !temCentavos && distintos / n > 0.9 && !/\b(valor|vlr|total|qtd|quant)\b/i.test(tabela.cabecalho[indice])
      if (pareceId) return { ...base, tipo: 'id', confianca: numeros.length / n }
      if (inteiros === numeros.length && !temCentavos && !/\b(valor|vlr|total|montante|preco|debito|credito)\b/i.test(tabela.cabecalho[indice])) {
        return { ...base, tipo: 'inteiro', confianca: numeros.length / n, temNegativos }
      }
      return { ...base, tipo: 'dinheiro', confianca: numeros.length / n, estiloMoeda, temNegativos }
    }
    if (textos / n >= 0.6) {
      if (n >= 20 && distintos <= Math.max(30, n * 0.15)) return { ...base, tipo: 'categoria', confianca: textos / n }
      if (distinctLooksLikeId(cheios, distintos)) return { ...base, tipo: 'id', confianca: textos / n }
      return { ...base, tipo: 'texto', confianca: textos / n }
    }
    return { ...base, tipo: 'texto', confianca: 0.5 }
  })
}

function distinctLooksLikeId(cheios: Celula[], distintos: number): boolean {
  if (distintos < cheios.length * 0.95 || cheios.length < 5) return false
  return cheios.every((v) => typeof v === 'string' && !/\s/.test(v.trim()) && /\d/.test(v))
}

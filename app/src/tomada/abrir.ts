import * as XLSX from 'xlsx'
import Papa from 'papaparse'
import type { Celula, Deteccao, Grade } from './tipos'
import { decodificar } from './detectar'
import { lerOfx } from './ofx'

/** Qualquer formato → grades (uma por aba). Nada é formatado aqui: célula sai como veio. */
export function abrir(bytes: Uint8Array, det: Deteccao): Grade[] {
  switch (det.formato) {
    case 'xlsx':
    case 'xls': {
      const wb = XLSX.read(bytes, { type: 'array', cellDates: true, cellNF: false, cellText: false })
      return wb.SheetNames.map((aba) => {
        const ws = wb.Sheets[aba]
        const linhas = XLSX.utils.sheet_to_json<Celula[]>(ws, { header: 1, raw: true, defval: null, blankrows: true }) as Celula[][]
        return { aba, linhas: linhas.map((l) => l.map(normalizarCelula)) }
      })
    }
    case 'csv':
    case 'tsv': {
      const texto = decodificar(bytes, det.encoding ?? 'utf-8', det.bom)
      const r = Papa.parse<string[]>(texto, { delimiter: det.separador ?? ';', skipEmptyLines: false })
      const linhas = r.data.map((l) => l.map((c) => (c === '' ? null : c)))
      return [{ aba: 'CSV', linhas }]
    }
    case 'ofx':
      return [lerOfx(decodificar(bytes, det.encoding ?? 'utf-8', det.bom))]
    case 'nfe_xml':
      return [lerNfe(decodificar(bytes, det.encoding ?? 'utf-8', det.bom))]
    default:
      throw new Error(`Formato não suportado: ${det.formato}`)
  }
}

function normalizarCelula(c: unknown): Celula {
  if (c === undefined) return null
  if (c instanceof Date || typeof c === 'number' || typeof c === 'boolean' || typeof c === 'string' || c === null) return c
  return String(c)
}

/** NF-e: uma linha por nota (emitente, número, emissão, valor). Itens ficam para a v1.2. */
function lerNfe(xml: string): Grade {
  const pega = (tag: string, de = xml) => de.match(new RegExp(`<${tag}>([^<]*)<`, 'i'))?.[1] ?? null
  const emit = xml.match(/<emit>[\s\S]*?<\/emit>/i)?.[0] ?? ''
  return {
    aba: 'NFe',
    linhas: [
      ['Emissão', 'Número', 'Fornecedor', 'CNPJ', 'Valor', 'Chave'],
      [pega('dhEmi') ?? pega('dEmi'), pega('nNF'), pega('xNome', emit), pega('CNPJ', emit), Number(pega('vNF') ?? 'NaN'), xml.match(/Id="NFe(\d{44})"/)?.[1] ?? null],
    ],
  }
}

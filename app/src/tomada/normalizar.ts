import type { Celula, EstiloMoeda, FormatoData } from './tipos'

// ───────── dinheiro ─────────

/**
 * Lê dinheiro em pt-BR (e em US quando o export é gringo). Devolve número com sinal.
 *   "R$ 1.234,56" → 1234.56   "(1.234,56)" → -1234.56   "1.234,56-" → -1234.56
 *   "1.234,56 D" → -1234.56   "1,234.56" (us) → 1234.56   "" → null
 */
export function parseDinheiro(v: Celula, estilo?: EstiloMoeda): number | null {
  if (v === null || v === undefined || v === '') return null
  if (typeof v === 'number') return Number.isFinite(v) ? arredondar(v) : null
  if (typeof v === 'boolean' || v instanceof Date) return null

  let s = v.replace(/R\$|BRL|US\$|\$/gi, '').trim()
  if (!s) return null
  let negativo = false

  if (/^\(.*\)$/.test(s)) { negativo = true; s = s.slice(1, -1) }
  if (/-\s*$/.test(s)) { negativo = true; s = s.replace(/-\s*$/, '') }
  if (/^\s*-/.test(s)) { negativo = true; s = s.replace(/^\s*-/, '') }
  if (/\s[dD]$/.test(s) || /^[dD]\s/.test(s)) { negativo = true }
  s = s.replace(/^[dDcC]\s+/, '').replace(/\s+[dDcC]$/, '')
  s = s.replace(/\s/g, '')
  if (/^[+]/.test(s)) s = s.slice(1)
  if (!/^[\d.,]+$/.test(s)) return null

  const temVirgula = s.includes(',')
  const temPonto = s.includes('.')
  let inteiro: string
  let decimal = ''

  if (temVirgula && temPonto) {
    // o último separador é o decimal
    const decimalEhVirgula = s.lastIndexOf(',') > s.lastIndexOf('.')
    const [i, d = ''] = decimalEhVirgula
      ? [s.replace(/\./g, '').split(',')[0], s.split(',').pop()!]
      : [s.replace(/,/g, '').split('.')[0], s.split('.').pop()!]
    inteiro = i; decimal = d
  } else if (temVirgula) {
    const partes = s.split(',')
    if (estilo === 'us' || partes.length > 2) {
      inteiro = partes.join(''); decimal = ''
    } else {
      // pt-BR: vírgula é decimal. "1,234" com 3 dígitos é ambíguo — no Brasil, decimal.
      decimal = partes.pop()!; inteiro = partes.join('')
    }
  } else if (temPonto) {
    const partes = s.split('.')
    const pareceMilhar = partes.length >= 2 && partes.slice(1).every((p) => p.length === 3) && partes[0].length <= 3
    if (estilo === 'us' || !pareceMilhar) { decimal = partes.pop()!; inteiro = partes.join('') }
    else { inteiro = partes.join(''); decimal = '' }
    if (estilo === 'br' && pareceMilhar) { inteiro = partes.join(''); decimal = '' }
  } else {
    inteiro = s
  }

  if (!/^\d+$/.test(inteiro) || (decimal && !/^\d+$/.test(decimal))) return null
  const n = Number(`${inteiro}.${decimal || '0'}`)
  if (!Number.isFinite(n)) return null
  return arredondar(negativo ? -n : n)
}

export function arredondar(n: number): number {
  return Math.round((n + Number.EPSILON) * 100) / 100
}

/** Decide, olhando a coluna inteira, se o export usa vírgula (br) ou ponto (us) como decimal. */
export function inferirEstiloMoeda(valores: Celula[]): EstiloMoeda {
  let br = 0, us = 0
  for (const v of valores) {
    if (typeof v !== 'string') continue
    const s = v.trim()
    if (/,\d{2}\s*[dDcC]?-?$/.test(s) || /\d\.\d{3},/.test(s)) br++
    else if (/\.\d{2}$/.test(s) || /\d,\d{3}\./.test(s)) us++
  }
  return us > br ? 'us' : 'br'
}

// ───────── datas ─────────

const MESES: Record<string, number> = {
  jan: 1, fev: 2, mar: 3, abr: 4, mai: 5, jun: 6, jul: 7, ago: 8, set: 9, out: 10, nov: 11, dez: 12,
  feb: 2, apr: 4, may: 5, aug: 8, sep: 9, oct: 10, dec: 12,
}

function iso(a: number, m: number, d: number): string | null {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null
  const dt = new Date(Date.UTC(a, m - 1, d))
  if (dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) return null
  return `${String(a).padStart(4, '0')}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`
}

function ano4(a: string): number {
  const n = Number(a)
  return a.length === 2 ? (n >= 70 ? 1900 + n : 2000 + n) : n
}

/** Serial do Excel (dias desde 1899-12-30) → ISO. */
export function serialParaIso(serial: number): string | null {
  if (!Number.isFinite(serial) || serial < 20000 || serial > 80000) return null
  const ms = Math.round((serial - 25569) * 86400 * 1000)
  const dt = new Date(ms)
  return iso(dt.getUTCFullYear(), dt.getUTCMonth() + 1, dt.getUTCDate())
}

/**
 * Lê data em qualquer formato que aparece em export brasileiro. Devolve YYYY-MM-DD ou null.
 * `formato` resolve a ambiguidade dd/mm × mm/dd — inferido pela coluna (ver inferirFormatoData).
 */
export function parseData(v: Celula, formato: FormatoData = 'dmy', anoPadrao?: number): string | null {
  if (v === null || v === undefined || v === '') return null
  if (v instanceof Date) {
    if (Number.isNaN(v.getTime())) return null
    // SheetJS cria Date em hora local; usamos os campos locais para não virar o dia
    return iso(v.getFullYear(), v.getMonth() + 1, v.getDate())
  }
  if (typeof v === 'number') return serialParaIso(v)
  if (typeof v === 'boolean') return null

  const s = v.trim().replace(/\s+/g, ' ')
  let m: RegExpMatchArray | null

  // OFX: YYYYMMDD[HHMMSS[.XXX]][[+/-TZ:NAME]]
  if ((m = s.match(/^(\d{4})(\d{2})(\d{2})(\d{6})?/)) && s.length >= 8 && !/[/\-.]/.test(s.slice(0, 8))) {
    return iso(+m[1], +m[2], +m[3])
  }
  // ISO
  if ((m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ].*)?$/))) return iso(+m[1], +m[2], +m[3])
  // dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy, dd/mm/yy (ou mm/dd conforme formato)
  if ((m = s.match(/^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2}|\d{4})(?:\s.*)?$/))) {
    const a = ano4(m[3])
    return formato === 'mdy' ? iso(a, +m[1], +m[2]) : iso(a, +m[2], +m[1])
  }
  // yyyy/mm/dd
  if ((m = s.match(/^(\d{4})[/.](\d{1,2})[/.](\d{1,2})$/))) return iso(+m[1], +m[2], +m[3])
  // dd/set, dd/set/26, dd set 2026, dd-set-2026, "10 de set de 2026"
  if ((m = s.match(/^(\d{1,2})(?:\s*(?:de)?\s*|[/\-.])([a-zç]{3})[a-zç]*\.?(?:(?:\s*(?:de)?\s*|[/\-.])(\d{2}|\d{4}))?$/i))) {
    const mes = MESES[m[2].toLowerCase().replace('ç', 'c')]
    if (!mes) return null
    const a = m[3] ? ano4(m[3]) : anoPadrao ?? new Date().getFullYear()
    return iso(a, mes, +m[1])
  }
  // set/26, setembro/2026 → dia 1
  if ((m = s.match(/^([a-zç]{3})[a-zç]*[/\-.\s](\d{2}|\d{4})$/i))) {
    const mes = MESES[m[1].toLowerCase().replace('ç', 'c')]
    return mes ? iso(ano4(m[2]), mes, 1) : null
  }
  // serial em texto
  if (/^\d{5}(\.\d+)?$/.test(s)) return serialParaIso(Number(s))
  return null
}

/** Olha a coluna inteira: se algum primeiro campo passa de 12, é dd/mm; se algum segundo passa, mm/dd. Empate → dd/mm (Brasil). */
export function inferirFormatoData(valores: Celula[]): FormatoData {
  let dmy = 0, mdy = 0, ymd = 0, serial = 0, date = 0
  for (const v of valores) {
    if (v instanceof Date) { date++; continue }
    if (typeof v === 'number') { serial++; continue }
    if (typeof v !== 'string') continue
    const s = v.trim()
    if (/^\d{4}-\d{1,2}-\d{1,2}/.test(s)) { ymd++; continue }
    const m = s.match(/^(\d{1,2})[/\-.](\d{1,2})[/\-.]\d{2,4}/)
    if (!m) continue
    if (+m[1] > 12) dmy++
    else if (+m[2] > 12) mdy++
  }
  if (date && date >= serial && date >= dmy + mdy + ymd) return 'date'
  if (serial > dmy + mdy + ymd) return 'serial'
  if (ymd > dmy + mdy) return 'ymd'
  return mdy > dmy ? 'mdy' : 'dmy'
}

// ───────── texto ─────────

export function limparTexto(v: Celula): string {
  if (v === null || v === undefined) return ''
  if (v instanceof Date) return parseData(v) ?? ''
  return String(v).replace(/\s+/g, ' ').trim()
}

/** Versão para memória e dedup: minúscula, sem acento, sem dígitos, sem pontuação. "PIX 12345 JOAO SILVA" → "pix joao silva" */
export function normalizarDescricao(v: Celula): string {
  return limparTexto(v)
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

/** Cabeçalho para comparação com sinônimos: sem acento, minúsculo, só letras/dígitos e espaço. */
export function normalizarCabecalho(v: Celula): string {
  return limparTexto(v)
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

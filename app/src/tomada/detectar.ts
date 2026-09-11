import type { Deteccao, Encoding } from './tipos'

const PK = [0x50, 0x4b, 0x03, 0x04]
const OLE = [0xd0, 0xcf, 0x11, 0xe0]
const BOM = [0xef, 0xbb, 0xbf]

function comeca(bytes: Uint8Array, assinatura: number[]): boolean {
  return assinatura.every((b, i) => bytes[i] === b)
}

/** Decodifica tentando UTF-8 estrito; se falhar, é latin1 (o que bancos costumam mandar). */
export function detectarEncoding(bytes: Uint8Array): { encoding: Encoding; bom: boolean } {
  const bom = comeca(bytes, BOM)
  try {
    new TextDecoder('utf-8', { fatal: true }).decode(bom ? bytes.subarray(3) : bytes)
    return { encoding: 'utf-8', bom }
  } catch {
    return { encoding: 'latin1', bom: false }
  }
}

export function decodificar(bytes: Uint8Array, encoding: Encoding, bom = false): string {
  const dados = bom ? bytes.subarray(3) : bytes
  return new TextDecoder(encoding === 'latin1' ? 'windows-1252' : 'utf-8').decode(dados)
}

/**
 * Escolhe o separador que aparece de forma mais consistente nas primeiras linhas.
 * `;` é o padrão pt-BR e ganha em empate.
 */
export function detectarSeparador(texto: string): string {
  const linhas = texto.split(/\r?\n/).filter((l) => l.trim()).slice(0, 20)
  const candidatos = [';', ',', '\t', '|']
  let melhor = ';'
  let melhorPontos = -1
  for (const sep of candidatos) {
    const contagens = linhas.map((l) => contarFora(l, sep))
    const comSep = contagens.filter((c) => c > 0)
    if (comSep.length === 0) continue
    const media = comSep.reduce((a, b) => a + b, 0) / comSep.length
    const variancia = comSep.reduce((a, c) => a + (c - media) ** 2, 0) / comSep.length
    // pontua presença em muitas linhas e baixa variância
    const pontos = comSep.length * 10 + media - variancia
    if (pontos > melhorPontos) {
      melhorPontos = pontos
      melhor = sep
    }
  }
  return melhor
}

/** conta ocorrências do separador fora de aspas */
function contarFora(linha: string, sep: string): number {
  let n = 0
  let aspas = false
  for (const ch of linha) {
    if (ch === '"') aspas = !aspas
    else if (!aspas && ch === sep) n++
  }
  return n
}

export function detectar(bytes: Uint8Array, nome = ''): Deteccao {
  if (comeca(bytes, PK)) return { formato: 'xlsx' }
  if (comeca(bytes, OLE)) return { formato: 'xls' }
  if (comeca(bytes, [0x25, 0x50, 0x44, 0x46])) return { formato: 'pdf' }

  const { encoding, bom } = detectarEncoding(bytes)
  const cabeca = decodificar(bytes.subarray(0, 4096), encoding, bom)
  const cabecaSemEspaco = cabeca.trimStart()

  if (/^OFXHEADER/i.test(cabecaSemEspaco) || /<OFX>/i.test(cabeca)) return { formato: 'ofx', encoding, bom }
  if (/<nfeProc|<NFe[\s>]/i.test(cabeca)) return { formato: 'nfe_xml', encoding, bom }

  const ext = nome.toLowerCase().split('.').pop() ?? ''
  if (ext === 'tsv') return { formato: 'tsv', encoding, bom, separador: '\t' }

  const separador = detectarSeparador(cabeca)
  if (separador === '\t') return { formato: 'tsv', encoding, bom, separador }
  if (/^[\x00-\x7f\x80-\xff]*$/.test(cabeca) && separador) return { formato: 'csv', encoding, bom, separador }
  return { formato: 'desconhecido', encoding, bom }
}

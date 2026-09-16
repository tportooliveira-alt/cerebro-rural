import type { Grade } from './tipos'

/**
 * Lê OFX v1 (SGML, sem fechamento de tag) e v2 (XML). Devolve uma grade com uma linha por STMTTRN.
 * Cabeçalhos são os nomes OFX — o dicionário de sinônimos já os conhece (DTPOSTED, TRNAMT, FITID, MEMO...).
 */
export const CABECALHO_OFX = ['DTPOSTED', 'TRNAMT', 'TRNTYPE', 'FITID', 'CHECKNUM', 'NAME', 'MEMO'] as const

export function lerOfx(texto: string): Grade {
  const linhas: Grade['linhas'] = [CABECALHO_OFX.slice()]
  const blocos = texto.match(/<STMTTRN>[\s\S]*?(?=<\/STMTTRN>|<STMTTRN>|<\/BANKTRANLIST>)/gi) ?? []
  for (const bloco of blocos) {
    const campo = (tag: string): string | null => {
      const m = bloco.match(new RegExp(`<${tag}>\\s*([^<\\r\\n]*)`, 'i'))
      return m ? decodificarEntidades(m[1].trim()) : null
    }
    const valor = campo('TRNAMT')
    linhas.push([
      campo('DTPOSTED'),
      valor === null ? null : Number(valor.replace(',', '.')),
      campo('TRNTYPE'),
      campo('FITID'),
      campo('CHECKNUM'),
      campo('NAME'),
      campo('MEMO'),
    ])
  }
  return { aba: 'OFX', linhas }
}

function decodificarEntidades(s: string): string {
  return s.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&apos;/g, "'")
}

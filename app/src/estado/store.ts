import { chaveFraca, lerArquivo, lerArquivoArea, marcarDuplicatas, marcarDuplicatasArea, type Area, type Lancamento, type Problema, type RegistroArea } from '../tomada'
import { SEED } from '../seed/arquivos'

export interface Fonte {
  id: string
  slug: string
  nome: string
  area: Area
  canal: string
  exemplo?: boolean
  ultimaLeitura?: string
  arquivos: number
}

export interface ArquivoLido {
  id: string
  fonteId: string
  nome: string
  hash: string
  lidoEm: string
  linhas: number
  novas: number
  duplicadas: number
  rejeitadas: number
  /** o bruto, para abrir a linha de origem */
  grade: Array<Array<string | number | boolean | Date | null>>
  aba: string
  linhaCabecalho: number
}

export interface Estado {
  fontes: Fonte[]
  arquivos: ArquivoLido[]
  lancamentos: Array<Lancamento & { fonteId: string; arquivoId: string }>
  registros: Array<RegistroArea & { fonteId: string; arquivoId: string }>
  rejeitados: Array<Problema & { fonteId: string; arquivoId: string }>
}

export const vazio = (): Estado => ({ fontes: [], arquivos: [], lancamentos: [], registros: [], rejeitados: [] })

const CHAVE = 'cerebro-rural-estado-v1'

export function carregar(): Estado | null {
  try {
    const bruto = localStorage.getItem(CHAVE)
    return bruto ? (JSON.parse(bruto) as Estado) : null
  } catch { return null }
}

export function salvar(e: Estado) {
  try { localStorage.setItem(CHAVE, JSON.stringify(e)) } catch { /* cota cheia ou modo privado: o Painel segue em memória */ }
}

export function limpar() {
  try { localStorage.removeItem(CHAVE) } catch { /* ignora */ }
}

const id = () => crypto.randomUUID()
const b64ParaBytes = (b64: string) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0))

export interface Previa {
  fonte: Fonte
  nome: string
  hash: string
  aba: string
  linhaCabecalho: number
  grade: ArquivoLido['grade']
  cabecalho: string[]
  ignoradas: Array<{ n: number; motivo: string }>
  mapa: Record<string, string>
  lancamentos: Lancamento[]
  registros: RegistroArea[]
  marcas: Array<'nova' | 'duplicada' | 'provavel'>
  rejeitados: Problema[]
  jaLido: boolean
}

/** Roda a Tomada de verdade no arquivo e devolve a prévia. Nada é gravado aqui. */
export async function preparar(estado: Estado, fonte: Fonte, nome: string, bytes: Uint8Array, origemRegistro?: 'abertura' | 'leitura'): Promise<Previa> {
  const base = { fonteId: fonte.slug, hoje: new Date() }
  if (fonte.area === 'financas') {
    const r = await lerArquivo(bytes, nome, base)
    const existentes = estado.lancamentos.map((l) => ({ hashLinha: l.hashLinha, data: l.data, valor: l.valor, fonteId: l.fonteId, id: l.hashLinha }))
    const marcas = marcarDuplicatas(fonte.slug, r.lancamentos, existentes)
    const t = r.tabelas[0]
    return {
      fonte, nome, hash: r.hashArquivo, aba: t?.aba ?? '', linhaCabecalho: t?.linhaCabecalho ?? 0,
      grade: r.tabelas.flatMap((x) => [x.cabecalho, ...x.linhas.map((l) => l.celulas)]),
      cabecalho: t?.cabecalho ?? [], ignoradas: r.tabelas.flatMap((x) => x.ignoradas.map((i) => ({ n: i.n, motivo: i.motivo }))),
      mapa: Object.fromEntries(r.mapas.flatMap((m) => Object.entries(m.colunas).map(([i, c]) => [t?.cabecalho[Number(i)] ?? i, c]))),
      lancamentos: r.lancamentos, registros: [], marcas: marcas.map((m) => m.resultado),
      rejeitados: r.rejeitados, jaLido: estado.arquivos.some((a) => a.hash === r.hashArquivo && a.fonteId === fonte.id),
    }
  }
  const r = await lerArquivoArea(bytes, nome, { ...base, area: fonte.area as Exclude<Area, 'financas'>, origemRegistro })
  const t = r.tabelas[0]
  const existentes = estado.registros.map((x) => ({ hashLinha: x.hashLinha, fonteId: x.fonteId, chaveFraca: chaveFraca(x.area, x.campos), id: x.hashLinha }))
  const marcasArea = marcarDuplicatasArea(fonte.slug === fonte.id ? fonte.slug : fonte.id, r.registros, existentes)
  return {
    fonte, nome, hash: r.hashArquivo, aba: t?.aba ?? '', linhaCabecalho: t?.linhaCabecalho ?? 0,
    grade: r.tabelas.flatMap((x) => [x.cabecalho, ...x.linhas.map((l) => l.celulas)]),
    cabecalho: t?.cabecalho ?? [], ignoradas: r.tabelas.flatMap((x) => x.ignoradas.map((i) => ({ n: i.n, motivo: i.motivo }))),
    mapa: Object.fromEntries(r.mapas.flatMap((m) => Object.entries(m.colunas).map(([i, c]) => [t?.cabecalho[Number(i)] ?? i, c]))),
    lancamentos: [], registros: r.registros,
    marcas: marcasArea.map((m) => m.resultado),
    rejeitados: r.rejeitados, jaLido: estado.arquivos.some((a) => a.hash === r.hashArquivo && a.fonteId === fonte.id),
  }
}

/** Grava a prévia: só o que está marcado como nova. */
export function gravar(estado: Estado, p: Previa): Estado {
  const fonteId = estado.fontes.find((f) => f.slug === p.fonte.slug)?.id ?? p.fonte.id
  const arquivoId = id()
  const novas = p.marcas.filter((m) => m === 'nova').length
  const arquivo: ArquivoLido = {
    id: arquivoId, fonteId, nome: p.nome, hash: p.hash, lidoEm: new Date().toISOString(),
    linhas: Math.max(p.lancamentos.length, p.registros.length), novas,
    duplicadas: p.marcas.filter((m) => m === 'duplicada').length,
    rejeitadas: p.rejeitados.length, grade: p.grade, aba: p.aba, linhaCabecalho: p.linhaCabecalho,
  }
  const manter = <T,>(arr: T[]) => arr.filter((_, i) => p.marcas[i] !== 'duplicada')
  return {
    fontes: estado.fontes.map((f) => (f.id === fonteId ? { ...f, ultimaLeitura: arquivo.lidoEm, arquivos: f.arquivos + 1 } : f)),
    arquivos: [arquivo, ...estado.arquivos],
    lancamentos: [...manter(p.lancamentos).map((l) => ({ ...l, fonteId, arquivoId })), ...estado.lancamentos],
    registros: [...manter(p.registros).map((r) => ({ ...r, fonteId, arquivoId })), ...estado.registros],
    rejeitados: [...p.rejeitados.map((r) => ({ ...r, fonteId, arquivoId })), ...estado.rejeitados],
  }
}

/** Primeira abertura: lê as fixtures de exemplo pela Tomada de verdade. */
export async function semear(): Promise<Estado> {
  let estado = vazio()
  estado.fontes = SEED.map((s) => ({ id: id(), slug: s.slug, nome: s.nome, area: s.area, canal: s.canal, exemplo: true, arquivos: 0 }))
  for (const s of SEED) {
    const fonte = estado.fontes.find((f) => f.slug === s.slug)!
    const p = await preparar(estado, fonte, s.arquivo, b64ParaBytes(s.b64), s.area === 'financas' ? 'leitura' : 'abertura')
    estado = gravar(estado, p)
  }
  return estado
}

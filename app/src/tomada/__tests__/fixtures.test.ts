import { describe, expect, it } from 'vitest'
import { readFileSync, readdirSync } from 'node:fs'
import { join } from 'node:path'
import { lerArquivo, marcarDuplicatas, type Lancamento } from '../index'

const DIR = join(__dirname, '../../../fixtures')
const ler = (nome: string) => new Uint8Array(readFileSync(join(DIR, nome)))
const HOJE = new Date(2026, 8, 11)

/** Projeção comparada com o golden file: só o que o humano escreveu à mão. */
function projetar(l: Lancamento, esperado: Record<string, unknown>) {
  const p: Record<string, unknown> = { data: l.data, tipo: l.tipo, valor: l.valor, descricao: l.descricao }
  if ('referenciaExterna' in esperado) p.referenciaExterna = l.referenciaExterna
  if ('contraparte' in esperado) p.contraparte = l.contraparte
  if ('categoria' in esperado) p.categoria = l.categoria
  if ('neutro' in esperado) p.neutro = l.neutro
  if ('linha' in esperado) p.linha = l.origem.linha
  if ('extras' in esperado) p.extras = Object.fromEntries(Object.entries(esperado.extras as object).map(([k]) => [k, String(l.extras[k])]))
  return p
}

const fixtures = readdirSync(DIR).filter((f) => f.endsWith('.esperado.json')).map((f) => f.replace('.esperado.json', ''))

describe.each(fixtures)('fixture %s', (base) => {
  const arquivo = readdirSync(DIR).find((f) => f.startsWith(base + '.') && !f.endsWith('.json'))!
  const esperado = JSON.parse(readFileSync(join(DIR, base + '.esperado.json'), 'utf8'))

  it('produz exatamente o golden file', async () => {
    const r = await lerArquivo(ler(arquivo), arquivo, { fonteId: base, hoje: HOJE })
    expect(r.deteccao.formato).toBe(esperado.formato)
    if (esperado.encoding) expect(r.deteccao.encoding).toBe(esperado.encoding)
    if (esperado.separador) expect(r.deteccao.separador).toBe(esperado.separador)
    if (esperado.bom) expect(r.deteccao.bom).toBe(true)
    if (esperado.tabelas) expect(r.tabelas).toHaveLength(esperado.tabelas)
    expect(r.rejeitados).toEqual([])
    expect(r.tabelas.flatMap((t) => t.ignoradas.map((i) => i.motivo))).toEqual(esperado.ignoradas)
    expect(r.lancamentos.map((l, i) => projetar(l, esperado.lancamentos[i] ?? {}))).toEqual(esperado.lancamentos)
  })

  it('reenviar o mesmo arquivo → 0 novas', async () => {
    const a = await lerArquivo(ler(arquivo), arquivo, { fonteId: base, hoje: HOJE })
    const existentes = a.lancamentos.map((l) => ({ hashLinha: l.hashLinha, data: l.data, valor: l.valor, fonteId: base, id: l.hashLinha.slice(0, 8) }))
    const b = await lerArquivo(ler(arquivo), arquivo, { fonteId: base, hoje: HOJE })
    const marcas = marcarDuplicatas(base, b.lancamentos, existentes)
    expect(marcas.every((m) => m.resultado === 'duplicada')).toBe(true)
    expect(a.hashArquivo).toBe(b.hashArquivo)
  })
})

describe('dedup entre fontes e sobreposição', () => {
  it('mesma data e valor em outra fonte → provável (caderno × FrigoGest, venda dos 12 bezerros)', async () => {
    const caderno = await lerArquivo(ler('caderno-fazenda.xlsx'), 'caderno-fazenda.xlsx', { fonteId: 'caderno', hoje: HOJE })
    const frigo = await lerArquivo(ler('frigogest-vendas.csv'), 'frigogest-vendas.csv', { fonteId: 'frigogest', hoje: HOJE })
    const existentes = caderno.lancamentos.map((l) => ({ hashLinha: l.hashLinha, data: l.data, valor: l.valor, fonteId: 'caderno', id: 'cad-' + l.origem.linha }))
    const marcas = marcarDuplicatas('frigogest', frigo.lancamentos, existentes)
    expect(marcas.map((m) => m.resultado)).toEqual(['provavel', 'nova', 'nova'])
    expect(marcas[0].par).toBe('cad-12')
  })

  it('extrato de 60 dias seguido do mês seguinte → só os 30 dias novos entram', async () => {
    const linha = (d: string, desc: string, v: string) => `${d};${desc};;${v};`
    const cab = 'Data;Histórico;Documento;Valor;'
    const julho = [linha('05/07/2026', 'POSTO TREVAO', '-200,00'), linha('20/07/2026', 'ALUGUEL MARIA', '1.800,00')]
    const agosto = [linha('05/08/2026', 'POSTO TREVAO', '-210,00'), linha('20/08/2026', 'ALUGUEL MARIA', '1.800,00')]
    const setembro = [linha('05/09/2026', 'POSTO TREVAO', '-190,00'), linha('20/09/2026', 'ALUGUEL MARIA', '1.800,00')]
    const arq1 = new Uint8Array(Buffer.from([cab, ...julho, ...agosto].join('\n'), 'latin1'))
    const arq2 = new Uint8Array(Buffer.from([cab, ...agosto, ...setembro].join('\n'), 'latin1'))
    const a = await lerArquivo(arq1, 'ext.csv', { fonteId: 'bb', hoje: new Date(2026, 9, 1) })
    expect(a.lancamentos).toHaveLength(4)
    const existentes = a.lancamentos.map((l) => ({ hashLinha: l.hashLinha, data: l.data, valor: l.valor, fonteId: 'bb' }))
    const b = await lerArquivo(arq2, 'ext.csv', { fonteId: 'bb', hoje: new Date(2026, 9, 1) })
    const marcas = marcarDuplicatas('bb', b.lancamentos, existentes)
    expect(marcas.map((m) => m.resultado)).toEqual(['duplicada', 'duplicada', 'nova', 'nova'])
    // o aluguel de 1.800 repete todo mês com a mesma descrição — só a data distingue, e ela basta
    expect(b.lancamentos.filter((_, i) => marcas[i].resultado === 'nova').map((l) => l.data)).toEqual(['2026-09-05', '2026-09-20'])
  })

  it('valores só positivos e sem coluna de tipo → tipo_indeterminado, nada entra em silêncio', async () => {
    const arq = new Uint8Array(Buffer.from('Data;Descrição;Valor\n01/08/2026;Sal mineral;1.850,00\n02/08/2026;Vacina;480,50\n', 'utf8'))
    const r = await lerArquivo(arq, 'x.csv', { fonteId: 'x', hoje: HOJE })
    expect(r.lancamentos).toHaveLength(0)
    expect(r.rejeitados.map((p) => p.codigo)).toEqual(['tipo_indeterminado', 'tipo_indeterminado'])
    const r2 = await lerArquivo(arq, 'x.csv', { fonteId: 'x', hoje: HOJE, tipoFixo: 'SAIDA' })
    expect(r2.lancamentos.map((l) => l.tipo)).toEqual(['SAIDA', 'SAIDA'])
  })

  it('teto da fonte manda para revisão sem rejeitar', async () => {
    const r = await lerArquivo(ler('frigogest-vendas.csv'), 'frigogest-vendas.csv', { fonteId: 'f', hoje: HOJE, tetoValor: 20000 })
    expect(r.lancamentos).toHaveLength(3)
    expect(r.revisao).toEqual([expect.objectContaining({ codigo: 'acima_do_teto', linha: 3 })])
  })
})

import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { lerArquivoArea } from '../index'

const DIR = join(__dirname, '../../../fixtures')
const ler = (p: string) => new Uint8Array(readFileSync(join(DIR, p)))
const HOJE = new Date(2026, 8, 12)

describe('gado', () => {
  it('rebanho.xlsx: brinco, arrobas → kg, pasto, nascimento, total ignorado', async () => {
    const r = await lerArquivoArea(ler('gado/rebanho.xlsx'), 'rebanho.xlsx', { fonteId: 'planilha-rebanho', area: 'gado', hoje: HOJE })
    expect(r.tabelas[0].ignoradas.map((i) => i.motivo)).toEqual([
      'acima do cabeçalho (título)', 'acima do cabeçalho (título)', 'linha de total',
    ])
    expect(r.rejeitados).toEqual([])
    expect(r.registros).toHaveLength(4)
    // 12,4 @ em coluna chamada "Arrobas" → 186 kg, e a arroba original é preservada
    expect(r.registros[0].campos).toMatchObject({
      brinco: 'BR-0412', lote: 'Lote 4', categoria_animal: 'Garrote', sexo: 'M', raca: 'Nelore',
      nascimento: '2024-05-12', pasto: 'Pasto Alto', arrobas: 12.4, peso_kg: 186, data: '2026-09-10', evento: 'pesagem',
    })
    // bezerro recém-nascido: sem pasto e sem peso, evento nascimento — entra, não é rejeitado
    expect(r.registros[3].campos).toMatchObject({ brinco: 'BR-0512', pasto: null, peso_kg: null, evento: 'entrada' })
  })

  it('calculadora-boi.csv: peso em kg direto, modo → evento, sem pasto (atribuído depois)', async () => {
    const r = await lerArquivoArea(ler('gado/calculadora-boi.csv'), 'calculadora-boi.csv', { fonteId: 'calculadora-boi', area: 'gado', hoje: HOJE })
    expect(r.rejeitados).toEqual([])
    expect(r.registros.map((x) => x.campos.peso_kg)).toEqual([186, 196.5, 279])
    expect(r.registros.map((x) => x.campos.evento)).toEqual(['pesagem', 'pesagem', 'saida'])
    expect(r.registros.every((x) => x.campos.pasto === undefined || x.campos.pasto === null)).toBe(true)
    // o valor da venda não é campo de gado: fica em extras, nada se perde
    expect(r.registros[2].extras).toMatchObject({ valor: '6.324,00' })
  })

  it('mesma pesagem lida duas vezes tem o mesmo hash; peso diferente tem hash diferente', async () => {
    const a = await lerArquivoArea(ler('gado/calculadora-boi.csv'), 'c.csv', { fonteId: 'calc', area: 'gado', hoje: HOJE })
    const b = await lerArquivoArea(ler('gado/calculadora-boi.csv'), 'c.csv', { fonteId: 'calc', area: 'gado', hoje: HOJE })
    expect(a.registros.map((x) => x.hashLinha)).toEqual(b.registros.map((x) => x.hashLinha))
    expect(new Set(a.registros.map((x) => x.hashLinha)).size).toBe(3)
  })
})

describe('estoque', () => {
  it('movimentos.csv: E/S viram entrada/saida, custo e mínimo lidos', async () => {
    const r = await lerArquivoArea(ler('estoque/movimentos.csv'), 'movimentos.csv', { fonteId: 'planilha-estoque', area: 'estoque', hoje: HOJE })
    expect(r.registros).toHaveLength(4)
    expect(r.registros[0].campos).toMatchObject({
      codigo: 'SAL-01', item: 'Sal mineral proteinado', unidade: 'SC 30kg', quantidade: 20,
      tipo_mov: 'entrada', data: '2026-08-02', local: 'Galpão', responsavel: 'Thiago', custo_unitario: 92.5, minimo: 10,
    })
    expect(r.registros[1].campos).toMatchObject({ quantidade: 6, tipo_mov: 'saida', responsavel: 'Peão Zé' })
    // quantidade 0 não tem sentido num movimento: rejeitada com motivo
    expect(r.rejeitados).toEqual([expect.objectContaining({ linha: 6, codigo: 'valor_invalido' })])
  })

  it('primeira leitura como abertura marca origemRegistro e tipo saldo', async () => {
    const r = await lerArquivoArea(ler('estoque/movimentos.csv'), 'm.csv', { fonteId: 'e', area: 'estoque', origemRegistro: 'abertura', hoje: HOJE })
    expect(r.registros.every((x) => x.origemRegistro === 'abertura')).toBe(true)
  })

  it('almoxarifado usa o mesmo canônico, área separada', async () => {
    const r = await lerArquivoArea(ler('estoque/movimentos.csv'), 'm.csv', { fonteId: 'a', area: 'almoxarifado', hoje: HOJE })
    expect(r.registros[0].area).toBe('almoxarifado')
    expect(r.registros[0].campos.item).toBe('Sal mineral proteinado')
  })
})

describe('ferramentas', () => {
  it('inventario.csv: responsável, local e estado', async () => {
    const r = await lerArquivoArea(ler('ferramentas/inventario.csv'), 'inventario.csv', { fonteId: 'planilha-ferramentas', area: 'ferramentas', hoje: HOJE })
    expect(r.rejeitados).toEqual([])
    expect(r.registros).toHaveLength(3)
    expect(r.registros[0].campos).toMatchObject({ codigo: 'FER-101', item: 'Roçadeira Stihl FS 220', responsavel: 'Peão Zé', local: 'Oficina', estado: 'ok', data: '2026-09-05' })
    expect(r.registros[2].campos.estado).toBe('manutenção')
  })
})

describe('duplicata entre fontes nas áreas', () => {
  it('a mesma pesagem vinda da Calculadora e da planilha de rebanho é marcada como provável, não gravada duas vezes', async () => {
    const { marcarDuplicatasArea, chaveFraca } = await import('../dedup')
    const calc = await lerArquivoArea(ler('gado/calculadora-boi.csv'), 'c.csv', { fonteId: 'calculadora-boi', area: 'gado', hoje: HOJE })
    const reb = await lerArquivoArea(ler('gado/rebanho.xlsx'), 'r.xlsx', { fonteId: 'planilha-rebanho', area: 'gado', hoje: HOJE })
    const existentes = calc.registros.map((r) => ({ hashLinha: r.hashLinha, fonteId: 'calculadora-boi', chaveFraca: chaveFraca('gado', r.campos), id: 'calc-' + r.origem.linha }))
    const marcas = marcarDuplicatasArea('planilha-rebanho', reb.registros, existentes)
    // BR-0412 e BR-0413 pesados em 10/09 nas duas fontes → prováveis; BR-0187 vendido na Calculadora e pesado na planilha → evento diferente, não é o mesmo fato
    expect(marcas.filter((m) => m.resultado === 'provavel')).toHaveLength(2)
    expect(marcas[0].par).toBe('calc-2')
    expect(marcas.filter((m) => m.resultado === 'nova')).toHaveLength(2)
  })

  it('reler a mesma fonte marca tudo como duplicada', async () => {
    const { marcarDuplicatasArea, chaveFraca } = await import('../dedup')
    const a = await lerArquivoArea(ler('estoque/movimentos.csv'), 'm.csv', { fonteId: 'est', area: 'estoque', hoje: HOJE })
    const existentes = a.registros.map((r) => ({ hashLinha: r.hashLinha, fonteId: 'est', chaveFraca: chaveFraca('estoque', r.campos) }))
    const b = await lerArquivoArea(ler('estoque/movimentos.csv'), 'm.csv', { fonteId: 'est', area: 'estoque', hoje: HOJE })
    expect(marcarDuplicatasArea('est', b.registros, existentes).every((m) => m.resultado === 'duplicada')).toBe(true)
  })
})

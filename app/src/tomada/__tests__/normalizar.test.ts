import { describe, expect, it } from 'vitest'
import { inferirEstiloMoeda, inferirFormatoData, normalizarCabecalho, normalizarDescricao, parseData, parseDinheiro, serialParaIso } from '../normalizar'

describe('parseDinheiro (pt-BR e US)', () => {
  it.each([
    ['R$ 1.234,56', 1234.56], ['1.234,56', 1234.56], ['1234,56', 1234.56], ['1234', 1234], ['0,50', 0.5],
    ['(1.234,56)', -1234.56], ['1.234,56-', -1234.56], ['-1.234,56', -1234.56], ['1.234,56 D', -1234.56], ['1.234,56 C', 1234.56],
    ['R$ -420,35', -420.35], ['+ 300,00', 300], ['12.500,00', 12500], ['1.000', 1000], ['1,5', 1.5],
  ])('%s → %d', (s, n) => expect(parseDinheiro(s)).toBe(n))
  it.each([['1,234.56', 1234.56], ['18400.50', 18400.5], ['210.4', 210.4], ['-312.90', -312.9]])('us %s → %d', (s, n) => expect(parseDinheiro(s, 'us')).toBe(n))
  it('sem estilo, decide pelo último separador', () => { expect(parseDinheiro('1,234.56')).toBe(1234.56); expect(parseDinheiro('1.234,56')).toBe(1234.56) })
  it('números já numéricos passam', () => { expect(parseDinheiro(1850)).toBe(1850); expect(parseDinheiro(1234.567)).toBe(1234.57) })
  it.each([['', null], [null, null], ['abc', null], ['S A L D O', null], [true, null]])('%s → null', (s, n) => expect(parseDinheiro(s as never)).toBe(n))
  it('inferirEstiloMoeda', () => {
    expect(inferirEstiloMoeda(['1.234,56', '350,00'])).toBe('br')
    expect(inferirEstiloMoeda(['1,234.56', '350.00'])).toBe('us')
    expect(inferirEstiloMoeda([1850, 350])).toBe('br')
  })
})

describe('parseData', () => {
  it.each([
    ['03/08/2026', '2026-08-03'], ['3/8/26', '2026-08-03'], ['03-08-2026', '2026-08-03'], ['03.08.2026', '2026-08-03'],
    ['2026-08-03', '2026-08-03'], ['2026-08-03T10:00:00Z', '2026-08-03'], ['2026/08/03', '2026-08-03'],
    ['20260803120000[-3:BRT]', '2026-08-03'], ['20260810', '2026-08-10'],
    ['10/set', `${new Date().getFullYear()}-09-10`], ['10/set/26', '2026-09-10'], ['10 set 2026', '2026-09-10'], ['10 de setembro de 2026', '2026-09-10'],
    ['set/26', '2026-09-01'], ['setembro/2026', '2026-09-01'], ['46237', '2026-08-03'],
  ])('%s → %s', (s, iso) => expect(parseData(s)).toBe(iso))
  it('mm/dd quando a coluna manda', () => expect(parseData('08/03/2026', 'mdy')).toBe('2026-08-03'))
  it('Date e serial', () => {
    expect(parseData(new Date(2026, 7, 3))).toBe('2026-08-03')
    expect(parseData(46237)).toBe('2026-08-03')
    expect(serialParaIso(46237)).toBe('2026-08-03')
  })
  it.each(['32/13/2026', '', 'abc', '99/99/99', '00/01/2026'])('inválida: %s', (s) => expect(parseData(s)).toBeNull())
  it('inferirFormatoData', () => {
    expect(inferirFormatoData(['03/08/2026', '25/08/2026'])).toBe('dmy')
    expect(inferirFormatoData(['08/03/2026', '08/25/2026'])).toBe('mdy')
    expect(inferirFormatoData(['01/02/2026', '03/04/2026'])).toBe('dmy') // empate → Brasil
    expect(inferirFormatoData(['2026-08-03'])).toBe('ymd')
    expect(inferirFormatoData([46236, 46240])).toBe('serial')
    expect(inferirFormatoData([new Date()])).toBe('date')
  })
})

describe('texto', () => {
  it('normalizarDescricao tira acento, dígitos e pontuação', () => {
    expect(normalizarDescricao('PIX 12345 João  da Silva - LTDA.')).toBe('pix joao da silva ltda')
    expect(normalizarDescricao('Transferência enviada para conta 1234-5')).toBe('transferencia enviada para conta')
  })
  it('normalizarCabecalho', () => {
    expect(normalizarCabecalho(' Histórico ')).toBe('historico')
    expect(normalizarCabecalho('N° documento')).toBe('n documento')
    expect(normalizarCabecalho('Valor (R$)')).toBe('valor r')
  })
})

describe('classificação pelo plano de contas', () => {
  it('a mesma palavra muda de lado conforme entrada ou saída', async () => {
    const { classificar } = await import('../classificar')
    expect(classificar('ted recebida frigorifico boa carne', 'ENTRADA')).toMatchObject({ categoria: 'Receita', subcategoria: 'Venda de Gado' })
    expect(classificar('compra garrotes fazenda santa rita', 'SAIDA')).toMatchObject({ categoria: 'Custo Produção', subcategoria: 'Compra de Gado' })
  })
  it.each([
    ['suplemento mineral nutriboi', 'SAIDA', 'Suplementação'],
    ['vacina aftosa doses', 'SAIDA', 'Sanidade'],
    ['compra com cartao posto trevao', 'SAIDA', 'Combustível'],
    ['pagamento de boleto energisa', 'SAIDA', 'Energia'],
    ['pagamento pix jose da silva diarista', 'SAIDA', 'Mão de Obra'],
    ['pix enviado agropecuaria sao joao', 'SAIDA', 'Suplementação'],
  ])('%s → %s', async (desc, tipo, sub) => {
    const { classificar } = await import('../classificar')
    expect(classificar(desc, tipo as 'SAIDA').subcategoria).toBe(sub)
  })
  it('memória vence regra; o que não casa volta sem categoria', async () => {
    const { classificar } = await import('../classificar')
    const mem = new Map([['posto trevao', { categoria: 'Pessoal', subcategoria: 'Transporte' }]])
    expect(classificar('posto trevao', 'SAIDA', undefined, mem)).toMatchObject({ categoria: 'Pessoal', origem: 'memoria' })
    expect(classificar('xyz abc qualquer coisa', 'SAIDA').categoria).toBeUndefined()
  })
  it('coluna da planilha vence tudo', async () => {
    const { classificar } = await import('../classificar')
    expect(classificar('posto trevao', 'SAIDA', 'Combustível da fazenda')).toMatchObject({ categoria: 'Combustível da fazenda', origem: 'coluna' })
  })
})

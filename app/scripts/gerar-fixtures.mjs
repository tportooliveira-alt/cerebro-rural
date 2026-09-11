// Fixtures SINTÉTICAS, fiéis aos layouts públicos. Substituir pelas reais (anonimizadas) quando chegarem — ver QUALIDADE.md Fase 0.
import { writeFileSync, mkdirSync } from 'node:fs'
import * as XLSX from 'xlsx'
mkdirSync('fixtures', { recursive: true })

// 1. Extrato estilo Banco do Brasil: latin-1, ';', valor com sinal, "Saldo Anterior" no topo e "S A L D O" no fim
const bb = [
  'Data;Histórico;Documento;Valor;',
  '01/08/2026;Saldo Anterior;;12.500,00;',
  '03/08/2026;Pix - Enviado AGROPECUÁRIA SÃO JOÃO;48211;-1.850,00;',
  '05/08/2026;Compra com Cartão - POSTO TREVÃO;;-420,35;',
  '10/08/2026;TED Recebida FRIGORIFICO BOA CARNE LTDA;77120;18.400,50;',
  '15/08/2026;Pagamento de Boleto ENERGISA;;-312,90;',
  '20/08/2026;Transferência enviada para conta 1234-5 Thiago;;-5.000,00;',
  '31/08/2026;S A L D O;;23.317,25;',
].join('\r\n') + '\r\n'
writeFileSync('fixtures/extrato-bb.csv', Buffer.from(bb, 'latin1'))

// 2. Extrato estilo Sicoob: UTF-8 com BOM, título em cima, Débito/Crédito separados, TOTAL no rodapé
const sicoob = '﻿' + [
  'EXTRATO CONTA CORRENTE - COOP. SICOOB;;;;',
  'Período: 01/08/2026 a 31/08/2026;;;;',
  ';;;;',
  'Data;Descrição;Documento;Débito;Crédito',
  '02/08/2026;PAGAMENTO PIX JOSE DA SILVA (DIARISTA);;350,00;',
  '07/08/2026;SUPLEMENTO MINERAL NUTRIBOI;10233;2.140,80;',
  '12/08/2026;ALUGUEL RECEBIDO MARIA SOUZA;;;1.800,00',
  '25/08/2026;DIVIDENDOS FII HGLG11;;;212,40',
  ';;;;',
  'TOTAL;;;2.490,80;2.012,40',
].join('\n') + '\n'
writeFileSync('fixtures/extrato-sicoob.csv', sicoob, 'utf8')

// 3. OFX v1 (SGML sem fechamento de tag)
const ofx = `OFXHEADER:100
DATA:OFXSGML
VERSION:102
SECURITY:NONE
ENCODING:USASCII
CHARSET:1252
COMPRESSION:NONE
OLDFILEUID:NONE
NEWFILEUID:NONE

<OFX>
<SIGNONMSGSRSV1><SONRS><STATUS><CODE>0<SEVERITY>INFO</STATUS><DTSERVER>20260901120000[-3:BRT]<LANGUAGE>POR</SONRS></SIGNONMSGSRSV1>
<BANKMSGSRSV1><STMTTRNRS><TRNUID>1<STATUS><CODE>0<SEVERITY>INFO</STATUS>
<STMTRS><CURDEF>BRL<BANKACCTFROM><BANKID>001<ACCTID>12345-6<ACCTTYPE>CHECKING</BANKACCTFROM>
<BANKTRANLIST><DTSTART>20260801<DTEND>20260831
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260803120000[-3:BRT]<TRNAMT>-1850.00<FITID>2026080300001<MEMO>PIX ENVIADO AGROPECUARIA SAO JOAO</STMTTRN>
<STMTTRN><TRNTYPE>CREDIT<DTPOSTED>20260810<TRNAMT>18400.50<FITID>2026081000007<CHECKNUM>77120<MEMO>TED RECEBIDA FRIGORIFICO BOA CARNE</STMTTRN>
<STMTTRN><TRNTYPE>DEBIT<DTPOSTED>20260815<TRNAMT>-312.90<FITID>2026081500002<MEMO>BOLETO ENERGISA</STMTTRN>
</BANKTRANLIST><LEDGERBAL><BALAMT>23317.25<DTASOF>20260831</LEDGERBAL></STMTRS></STMTTRNRS></BANKMSGSRSV1></OFX>
`
writeFileSync('fixtures/extrato.ofx', ofx, 'latin1')

// 4. Caderno da fazenda em xlsx: título, cabeçalho na linha 4, totais, DUAS tabelas na mesma aba, datas como Date
const d = (dia) => new Date(2026, 7, dia)
const aoa = [
  ['FAZENDA BOA VISTA'],
  ['Controle de caixa — agosto/2026'],
  [],
  ['Data', 'Descrição', 'Fornecedor', 'Valor', 'Tipo'],
  [d(2), 'Sal mineral 20 sacos', 'Agropecuária São João', 1850, 'S'],
  [d(9), 'Diária João (cerca)', 'João Silva', 350, 'S'],
  [d(16), 'Vacina aftosa 60 doses', 'Vet Center', 480.5, 'S'],
  ['TOTAL DESPESAS', null, null, 2680.5, null],
  [],
  [],
  ['Data', 'Descrição', 'Comprador', 'Valor', 'Tipo'],
  [d(20), 'Venda 12 bezerros', 'Frigorífico Boa Carne', 18400.5, 'E'],
  [d(28), 'Aluguel casa da rua 7', 'Maria Souza', 1800, 'E'],
  ['TOTAL RECEITAS', null, null, 20200.5, null],
]
const wb = XLSX.utils.book_new()
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet(aoa, { cellDates: true }), 'Agosto')
XLSX.writeFile(wb, 'fixtures/caderno-fazenda.xlsx', { cellDates: true })

// 5. Export limpo de app próprio (FrigoGest): UTF-8, ',', decimais em ponto, id próprio, flag Entrada/Saída
const frigo = [
  'id,data,tipo,cliente,descricao,cabecas,arrobas,valor',
  'V-88213,2026-08-20,Entrada,Frigorífico Boa Carne,Venda 12 bezerros lote 4,12,210.4,18400.50',
  'C-11002,2026-08-22,Saída,Fazenda Santa Rita,Compra 30 garrotes,30,0,42300.00',
  'V-88214,2026-08-29,Entrada,Casa de Carnes Central,Venda 8 novilhas,8,150.2,13120.75',
].join('\n') + '\n'
writeFileSync('fixtures/frigogest-vendas.csv', frigo, 'utf8')
console.log('fixtures geradas')

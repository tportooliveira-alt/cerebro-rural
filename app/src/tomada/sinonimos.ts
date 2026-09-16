import type { Campo } from './tipos'

/** Cabeçalhos normalizados (ver normalizarCabecalho) → campo canônico. Ordem importa: o primeiro que casar vence. */
export const SINONIMOS: Array<[Campo, string[]]> = [
  ['data', ['data', 'dt', 'dia', 'data mov', 'data movimento', 'data lancamento', 'data do lancamento', 'data pagamento', 'data pgto', 'vencimento', 'emissao', 'data emissao', 'competencia', 'dtposted', 'date']],
  ['debito', ['debito', 'debitos', 'saida', 'saidas', 'pago', 'pagamento', 'pagamentos', 'despesa', 'despesas', 'gasto', 'gastos', 'retirada', 'valor debito', 'debit']],
  ['credito', ['credito', 'creditos', 'entrada', 'entradas', 'recebido', 'recebimento', 'recebimentos', 'receita', 'receitas', 'deposito', 'valor credito', 'credit']],
  ['flag_dc', ['d c', 'dc', 'tipo', 'tipo mov', 'tipo movimento', 'natureza', 'e s', 'entrada saida', 'operacao', 'trntype']],
  ['valor', ['valor', 'vlr', 'vl', 'total', 'valor total', 'montante', 'quantia', 'importancia', 'valor r', 'valor rs', 'trnamt', 'amount', 'preco', 'valor liquido']],
  ['descricao', ['descricao', 'historico', 'memo', 'lancamento', 'lancamentos', 'detalhe', 'detalhes', 'observacao', 'obs', 'item', 'produto', 'discriminacao', 'name', 'description', 'titulo', 'historico completo']],
  ['subcategoria', ['subcategoria', 'sub categoria', 'subconta', 'sub conta']],
  ['categoria', ['categoria', 'conta', 'natureza da despesa', 'plano de contas', 'classificacao', 'grupo', 'tipo de despesa', 'tipo despesa', 'centro de custo', 'rubrica']],
  ['contraparte', ['fornecedor', 'cliente', 'favorecido', 'beneficiario', 'comprador', 'vendedor', 'pagador', 'recebedor', 'pessoa', 'nome', 'razao social', 'contraparte', 'para', 'de']],
  ['referencia_externa', ['documento', 'doc', 'n doc', 'num doc', 'numero', 'num', 'n', 'nf', 'nota', 'nota fiscal', 'ref', 'referencia', 'id', 'codigo', 'cod', 'fitid', 'checknum', 'controle', 'lote']],
  ['negocio', ['negocio', 'empresa', 'unidade', 'fazenda', 'propriedade', 'setor']],
]

/** Padrões na descrição NORMALIZADA (sem acento, minúscula) que denunciam movimento neutro. Conservadores de propósito: sugestão, não sentença. */
export const NEUTROS: Array<[string, RegExp]> = [
  ['Transferência', /\b(transf\w*|aplicacao|resgate|entre contas|mesma titularidade)\b/],
  ['Pagamento de Fatura', /\b(pagto|pagamento|pgto|pag)\b.*\b(fatura|cartao)\b/],
  ['Estorno', /\b(estorno|devolucao|reembolso)\b/],
]

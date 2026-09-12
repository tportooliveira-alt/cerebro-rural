// Áreas da Tomada (D11). Cada área tem seu canônico, seu dicionário e sua chave de dedup.
// O pipeline (detectar → abrir → achar tabela → perfilar → mapear) é o mesmo para todas.

export const AREAS = ['financas', 'gado', 'estoque', 'almoxarifado', 'ferramentas', 'pasto'] as const
export type Area = (typeof AREAS)[number]

export type CampoGado =
  | 'brinco' | 'lote' | 'categoria_animal' | 'sexo' | 'raca' | 'nascimento'
  | 'pasto' | 'peso_kg' | 'data' | 'evento' | 'observacao'
export type CampoEstoque =
  | 'item' | 'unidade' | 'quantidade' | 'tipo_mov' | 'data' | 'local'
  | 'responsavel' | 'custo_unitario' | 'minimo' | 'codigo'
export type CampoFerramenta = 'item' | 'codigo' | 'responsavel' | 'local' | 'estado' | 'data' | 'observacao'
export type CampoPasto = 'pasto' | 'area_ha' | 'capacidade_ua' | 'lote' | 'data' | 'observacao'

/** Dicionário por área: campo canônico → cabeçalhos normalizados. A ordem importa. */
export const SINONIMOS_AREA: Record<Exclude<Area, 'financas'>, Array<[string, string[]]>> = {
  gado: [
    ['brinco', ['brinco', 'identificacao', 'identificador', 'sisbov', 'numero do animal', 'n animal', 'animal', 'chip', 'tag', 'matriz']],
    ['lote', ['lote', 'grupo', 'turma', 'rebanho']],
    ['categoria_animal', ['categoria', 'classe', 'tipo de animal', 'faixa']],
    ['sexo', ['sexo', 'genero', 'm f']],
    ['raca', ['raca', 'cruzamento', 'sangue']],
    ['nascimento', ['nascimento', 'data nascimento', 'dt nasc', 'nasc', 'idade']],
    ['pasto', ['pasto', 'piquete', 'modulo', 'invernada', 'retiro', 'localizacao']],
    ['peso_kg', ['peso', 'peso kg', 'kg', 'peso vivo', 'pv', 'peso atual', 'arrobas', 'arroba']],
    ['data', ['data', 'data pesagem', 'dt pesagem', 'data mov', 'dia', 'data evento']],
    ['evento', ['evento', 'movimento', 'ocorrencia', 'tipo', 'operacao', 'modo']],
    ['observacao', ['observacao', 'obs', 'anotacao', 'comentario']],
  ],
  estoque: [
    ['item', ['item', 'produto', 'insumo', 'descricao', 'material', 'mercadoria', 'nome']],
    ['codigo', ['codigo', 'cod', 'sku', 'referencia', 'ref']],
    ['unidade', ['unidade', 'un', 'und', 'medida', 'embalagem']],
    ['quantidade', ['quantidade', 'qtd', 'qtde', 'qt', 'saldo', 'estoque', 'estoque atual', 'volume']],
    ['tipo_mov', ['tipo', 'movimento', 'tipo mov', 'operacao', 'entrada saida', 'e s']],
    ['data', ['data', 'dia', 'data mov', 'data movimento', 'data entrada', 'data saida']],
    ['local', ['local', 'deposito', 'galpao', 'prateleira', 'setor', 'armazem']],
    ['responsavel', ['responsavel', 'retirado por', 'liberado por', 'solicitante', 'quem retirou', 'funcionario']],
    ['custo_unitario', ['custo', 'custo unitario', 'preco', 'preco unitario', 'valor unitario', 'vlr unit']],
    ['minimo', ['minimo', 'estoque minimo', 'min', 'ponto de pedido']],
  ],
  almoxarifado: [], // igual a estoque — preenchido abaixo
  ferramentas: [
    ['item', ['ferramenta', 'equipamento', 'item', 'descricao', 'bem', 'nome']],
    ['codigo', ['codigo', 'cod', 'patrimonio', 'n patrimonio', 'numero', 'serie']],
    ['responsavel', ['responsavel', 'quem esta com', 'com quem', 'usuario', 'funcionario', 'portador']],
    ['local', ['local', 'setor', 'galpao', 'oficina', 'onde esta']],
    ['estado', ['estado', 'condicao', 'situacao', 'status']],
    ['data', ['data', 'data mov', 'dia', 'data entrega', 'data devolucao']],
    ['observacao', ['observacao', 'obs', 'anotacao']],
  ],
  pasto: [
    ['pasto', ['pasto', 'piquete', 'modulo', 'invernada', 'nome', 'identificacao']],
    ['area_ha', ['area', 'area ha', 'hectares', 'ha', 'tamanho']],
    ['capacidade_ua', ['capacidade', 'lotacao', 'ua', 'ua ha', 'capacidade ua', 'suporte']],
    ['lote', ['lote', 'grupo', 'rebanho', 'lote atual']],
    ['data', ['data', 'entrada', 'data entrada', 'dia']],
    ['observacao', ['observacao', 'obs', 'situacao', 'forragem']],
  ],
}
SINONIMOS_AREA.almoxarifado = SINONIMOS_AREA.estoque

/** Campos sem os quais a linha não tem sentido — ausência é rejeição com motivo, nunca chute. */
export const OBRIGATORIOS: Record<Area, string[][]> = {
  financas: [['data'], ['valor'], ['descricao']],
  gado: [['brinco', 'lote'], ['data', 'nascimento']],  // ou brinco ou lote; ou data do evento ou nascimento
  estoque: [['item'], ['quantidade']],
  almoxarifado: [['item'], ['quantidade']],
  ferramentas: [['item']],
  pasto: [['pasto']],
}

/** Eventos de gado reconhecidos, e como o texto da planilha chega até eles. */
// Ordem = precedência. Uma pesagem feita para vender é uma SAÍDA; conferência é pesagem.
export const EVENTOS_GADO: Array<[string, RegExp]> = [
  ['morte', /\b(morte|morreu|obito|baixa)\b/],
  ['saida', /\b(saida|venda|vendida|vendido|abate|abatido)\b/],
  ['entrada', /\b(entrada|compra|comprada|comprado|nasceu|nascimento|nascida|nascido)\b/],
  ['mudanca_pasto', /\b(mudanca|mudou|transferencia|troca de pasto|apartacao)\b/],
  ['pesagem', /\b(pesagem|pesou|peso|balanca|conferencia|confere)\b/],
]

export const TIPOS_MOV_ESTOQUE: Array<[string, RegExp]> = [
  ['entrada', /^(e|entrada|entradas|compra|recebimento|\+)$/],
  ['saida', /^(s|saida|saidas|retirada|consumo|baixa|uso|-)$/],
  ['ajuste', /^(ajuste|correcao|inventario|balanco)$/],
  ['saldo', /^(saldo|estoque|estoque atual|atual|posicao)$/],
]

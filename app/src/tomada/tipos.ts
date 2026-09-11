// Tipos da Tomada. Espelham TOMADA.md — se divergirem, o código vence e o doc é corrigido.

export type Tipo = 'ENTRADA' | 'SAIDA'
export type Negocio = 'fazenda' | 'frigorifico' | 'imoveis' | 'comercio' | 'pessoal' | 'outro'
export type Formato = 'xlsx' | 'xls' | 'csv' | 'tsv' | 'ofx' | 'nfe_xml' | 'pdf' | 'desconhecido'
export type Encoding = 'utf-8' | 'latin1'

export interface Deteccao {
  formato: Formato
  encoding?: Encoding
  bom?: boolean
  separador?: string
}

/** Valor bruto de uma célula, como veio do arquivo. */
export type Celula = string | number | boolean | Date | null

/** Uma aba (ou o arquivo inteiro, para csv/ofx) como grade de células. */
export interface Grade {
  aba: string
  linhas: Celula[][]
}

export interface LinhaTabela {
  /** número da linha no arquivo original, 1-based */
  n: number
  celulas: Celula[]
}

export interface LinhaIgnorada extends LinhaTabela {
  motivo: string
}

/** Uma tabela de verdade encontrada dentro de uma aba. */
export interface Tabela {
  aba: string
  linhaCabecalho: number
  cabecalho: string[]
  linhas: LinhaTabela[]
  ignoradas: LinhaIgnorada[]
}

export type TipoColuna = 'data' | 'dinheiro' | 'inteiro' | 'texto' | 'categoria' | 'id' | 'flag_dc' | 'vazia'
export type FormatoData = 'dmy' | 'mdy' | 'ymd' | 'serial' | 'date'
export type EstiloMoeda = 'br' | 'us'

export interface PerfilColuna {
  indice: number
  cabecalho: string
  tipo: TipoColuna
  /** 0..1 — fração da amostra que bateu com o tipo */
  confianca: number
  formatoData?: FormatoData
  estiloMoeda?: EstiloMoeda
  temNegativos?: boolean
  distintos: number
  vazios: number
  total: number
}

export type ConvencaoSinal =
  | { modo: 'sinal'; valor: number }
  | { modo: 'debito_credito'; debito: number; credito: number }
  | { modo: 'flag'; valor: number; flag: number; saida: string[] }
  | { modo: 'perguntar'; valor: number }

export type Campo =
  | 'data' | 'valor' | 'debito' | 'credito' | 'flag_dc' | 'descricao'
  | 'categoria' | 'subcategoria' | 'contraparte' | 'referencia_externa' | 'negocio'

export type OrigemMapa = 'template' | 'sinonimo' | 'ia' | 'manual'

export interface Mapa {
  /** índice da coluna → campo canônico */
  colunas: Record<number, Campo>
  origem: Record<number, OrigemMapa>
  sinal: ConvencaoSinal
  /** sha256 dos cabeçalhos normalizados — identifica o layout */
  fingerprint: string
}

/** Template gravado por fonte: como ler este layout. */
export interface Template {
  fingerprint: string
  colunas: Record<number, Campo>
  sinal: ConvencaoSinal
  formatoData?: FormatoData
  estiloMoeda?: EstiloMoeda
  /** quando o arquivo tem só valores positivos e o humano disse "é tudo saída" */
  tipoFixo?: Tipo
}

export interface Lancamento {
  /** ISO date YYYY-MM-DD */
  data: string
  tipo: Tipo
  /** sempre positivo, 2 casas */
  valor: number
  descricao: string
  descricaoNormalizada: string
  categoria?: string
  subcategoria?: string
  contraparte?: string
  referenciaExterna?: string
  negocio?: Negocio
  /** colunas que não mapearam para o canônico, como vieram */
  extras: Record<string, Celula>
  origem: { aba: string; linha: number }
  hashLinha: string
  /** transferência/estorno ficam fora do resultado */
  neutro?: boolean
}

export type CodigoProblema =
  | 'valor_ausente' | 'valor_invalido' | 'data_ausente' | 'data_invalida' | 'data_fora_da_janela'
  | 'descricao_ausente' | 'tipo_indeterminado' | 'acima_do_teto' | 'duplicado_no_arquivo'

export interface Problema {
  aba: string
  linha: number
  campo?: Campo
  codigo: CodigoProblema
  mensagem: string
}

export interface ResultadoLeitura {
  deteccao: Deteccao
  hashArquivo: string
  tabelas: Tabela[]
  perfis: PerfilColuna[][]
  mapas: Mapa[]
  lancamentos: Lancamento[]
  rejeitados: Problema[]
  revisao: Problema[]
}

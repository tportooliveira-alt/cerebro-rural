// Plano de contas padrão (D17). O produtor renomeia e acrescenta pelo Painel — isto é só o ponto de partida.
import type { Tipo } from './tipos'

export interface Conta { categoria: string; subcategorias: string[]; tipo?: Tipo }

export const PLANO: Conta[] = [
  { tipo: 'ENTRADA', categoria: 'Receita', subcategorias: ['Venda de Gado', 'Venda de Carne/Abate', 'Aluguel', 'Serviço', 'Financeira', 'Outra'] },
  { tipo: 'SAIDA', categoria: 'Custo Produção', subcategorias: ['Suplementação', 'Sanidade', 'Pasto/Forragem', 'Combustível', 'Mão de Obra', 'Frete', 'Compra de Gado'] },
  { tipo: 'SAIDA', categoria: 'Custo Fixo', subcategorias: ['Folha', 'Encargos', 'Energia', 'Água', 'Telefone/Internet', 'Contador', 'Seguro', 'Tarifas bancárias'] },
  { tipo: 'SAIDA', categoria: 'Investimento', subcategorias: ['Máquina', 'Benfeitoria', 'Cerca', 'Animal de Reposição'] },
  { tipo: 'SAIDA', categoria: 'Imóveis', subcategorias: ['Manutenção', 'IPTU', 'Condomínio'] },
  { tipo: 'SAIDA', categoria: 'Pessoal', subcategorias: ['Alimentação', 'Saúde', 'Educação', 'Casa', 'Lazer', 'Transporte'] },
  { tipo: 'SAIDA', categoria: 'Impostos', subcategorias: ['ITR', 'Funrural', 'IR', 'Outros'] },
  { categoria: 'Transferência', subcategorias: [] },
  { categoria: 'Estorno', subcategorias: [] },
  { categoria: 'Pagamento de Fatura', subcategorias: [] },
]

/**
 * Regras iniciais de classificação por palavra na descrição normalizada (sem acento, minúscula, sem dígitos).
 * Ordem = precedência. `tipo` restringe a regra a entrada ou saída — a mesma palavra muda de lado:
 * "frigorífico" numa entrada é venda de gado; numa saída é compra.
 * Toda classificação daqui sai marcada como `regra` e pode ser corrigida no Painel — a correção vira memória.
 */
export interface Regra { re: RegExp; categoria: string; subcategoria?: string; tipo?: Tipo }

export const REGRAS: Regra[] = [
  // receitas
  { re: /\b(frigorifico|abate|abatedouro|casa de carnes|boiadeiro)\b/, tipo: 'ENTRADA', categoria: 'Receita', subcategoria: 'Venda de Gado' },
  { re: /\b(venda|vendidos?)\b.*\b(gado|boi|bois|bezerros?|novilhas?|garrotes?|vacas?|cabecas?)\b/, tipo: 'ENTRADA', categoria: 'Receita', subcategoria: 'Venda de Gado' },
  { re: /\b(aluguel|locacao|inquilin\w+)\b/, tipo: 'ENTRADA', categoria: 'Receita', subcategoria: 'Aluguel' },
  { re: /\b(dividendos?|jcp|rendimento|provento|fii|tesouro|cdb)\b/, tipo: 'ENTRADA', categoria: 'Receita', subcategoria: 'Financeira' },
  { re: /\b(leite|queijo|laticinio)\b/, tipo: 'ENTRADA', categoria: 'Receita', subcategoria: 'Outra' },

  // custo de produção
  { re: /\b(sal mineral|sal proteinado|suplemento|nutriboi|racao|nucleo|ureia)\b/, categoria: 'Custo Produção', subcategoria: 'Suplementação' },
  { re: /\b(vacina|vermifugo|carrapaticida|antibiotico|veterinari\w+|vet|aftosa|brucelose|farmacia veterinaria)\b/, categoria: 'Custo Produção', subcategoria: 'Sanidade' },
  { re: /\b(posto|combustivel|diesel|gasolina|etanol|arla)\b/, categoria: 'Custo Produção', subcategoria: 'Combustível' },
  { re: /\b(semente|adubo|fertilizante|calcario|herbicida|formicida|capim|braquiaria|mombaca)\b/, categoria: 'Custo Produção', subcategoria: 'Pasto/Forragem' },
  { re: /\b(diaria|diarista|empreita|servico de campo|roco|cerqueiro|vaqueiro|peao)\b/, categoria: 'Custo Produção', subcategoria: 'Mão de Obra' },
  { re: /\b(frete|transporte|carreto|caminhoneiro|boiadeiro transporte)\b/, categoria: 'Custo Produção', subcategoria: 'Frete' },
  { re: /\b(compra)\b.*\b(gado|boi|bois|bezerros?|garrotes?|novilhas?|matrizes?)\b/, tipo: 'SAIDA', categoria: 'Custo Produção', subcategoria: 'Compra de Gado' },
  { re: /\b(agropecuaria|agropec|agro center|casa do produtor|cooperativa)\b/, categoria: 'Custo Produção', subcategoria: 'Suplementação' },

  // custo fixo
  { re: /\b(energisa|coelba|cemig|cpfl|enel|energia eletrica|conta de luz)\b/, categoria: 'Custo Fixo', subcategoria: 'Energia' },
  { re: /\b(embasa|saneamento|conta de agua|sabesp)\b/, categoria: 'Custo Fixo', subcategoria: 'Água' },
  { re: /\b(vivo|claro|tim|oi|internet|telefonia|starlink)\b/, categoria: 'Custo Fixo', subcategoria: 'Telefone/Internet' },
  { re: /\b(contador|contabilidade|honorarios contabeis|escritorio contabil)\b/, categoria: 'Custo Fixo', subcategoria: 'Contador' },
  { re: /\b(seguro|apolice|porto seguro|bradesco seguros)\b/, categoria: 'Custo Fixo', subcategoria: 'Seguro' },
  { re: /\b(tarifa|cesta de servicos|manutencao de conta|iof|juros|anuidade)\b/, categoria: 'Custo Fixo', subcategoria: 'Tarifas bancárias' },
  { re: /\b(folha|salario|adiantamento|vale|rescisao|ferias|decimo terceiro)\b/, categoria: 'Custo Fixo', subcategoria: 'Folha' },
  { re: /\b(fgts|inss|encargos)\b/, categoria: 'Custo Fixo', subcategoria: 'Encargos' },

  // investimento
  { re: /\b(trator|colheitadeira|implemento|maquina|motor|bomba)\b/, categoria: 'Investimento', subcategoria: 'Máquina' },
  { re: /\b(cerca|mourao|arame|palanque)\b/, categoria: 'Investimento', subcategoria: 'Cerca' },
  { re: /\b(obra|construcao|curral|barracao|galpao|reforma|cimento|tijolo|telha)\b/, categoria: 'Investimento', subcategoria: 'Benfeitoria' },

  // impostos
  { re: /\b(itr)\b/, categoria: 'Impostos', subcategoria: 'ITR' },
  { re: /\b(funrural|senar)\b/, categoria: 'Impostos', subcategoria: 'Funrural' },
  { re: /\b(darf|irpf|imposto de renda|carne leao)\b/, categoria: 'Impostos', subcategoria: 'IR' },

  // pessoal
  { re: /\b(supermercado|mercado|padaria|acougue|hortifruti|atacadao|assai)\b/, categoria: 'Pessoal', subcategoria: 'Alimentação' },
  { re: /\b(drogaria|farmacia popular|unimed|plano de saude|hospital|laboratorio|clinica)\b/, categoria: 'Pessoal', subcategoria: 'Saúde' },
  { re: /\b(escola|faculdade|colegio|mensalidade|curso)\b/, categoria: 'Pessoal', subcategoria: 'Educação' },
  { re: /\b(uber|taxi|passagem|estacionamento|pedagio)\b/, categoria: 'Pessoal', subcategoria: 'Transporte' },
  { re: /\b(netflix|spotify|restaurante|lanchonete|bar |cinema)\b/, categoria: 'Pessoal', subcategoria: 'Lazer' },
]

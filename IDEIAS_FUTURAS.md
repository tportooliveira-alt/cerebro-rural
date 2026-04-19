# Ideias Futuras — Cérebro Rural

> Espaço para capturar ideias que surgem mas não entram na execução imediata.
> Revisar antes de cada sprint pra ver o que promover pro roadmap principal.

---

## Ideias de produto

### Comparador de preços entre fazendas
Se vários produtores estão na plataforma, o sistema pode mostrar (anonimizado):
- Preço médio da ração na sua região
- Quanto custou a arroba na última venda na sua micro-região
- Custo médio de construção de cerca por metro

Sem expor dados individuais — só estatística agregada.

### Agente de compras inteligente
IA que monitora histórico de consumo e sugere:
- "Seu sal mineral vai acabar em 12 dias. Comprou dos últimos 3 fornecedores por R$ X, Y, Z. Que tal pedir do fornecedor W?"

### Previsão de safra / abate
Baseado em:
- Curva de ganho de peso do lote
- Preço projetado da arroba
- Custo acumulado

Resposta: "melhor momento de vender o Lote 4 é em 45 dias, com margem esperada de X"

### Integração com contador
Portal separado onde o contador do produtor:
- Acessa só o que precisa (relatórios mensais)
- Exporta para softwares de contabilidade (Domínio, Alterdata)
- Comenta dúvidas em lançamentos específicos

### Parcelamento de compras automático
Ao lançar uma compra a prazo, o sistema automaticamente cria as parcelas no módulo Contas a Pagar, com alertas de vencimento.

### OCR de boletos
Foto do boleto → extrai valor, vencimento, beneficiário → programa no fluxo de caixa

### Fluxo de caixa futuro
Projeção de 30/60/90 dias baseado em:
- Contas a pagar já lançadas
- Recebíveis previstos (aluguéis, vendas programadas)
- Padrão sazonal de despesas

---

## Ideias técnicas

### Sincronização peer-to-peer local
Dois celulares da mesma fazenda sincronizam entre si via Bluetooth/Wi-Fi local, sem precisar de internet central. Útil pra peões no campo.

### Reconhecimento de voz específico para jargão rural
Modelo treinado com vocabulário do setor:
- "tou precisando de duas caixas de vermífugo" → entende "vermífugo"
- "o lote do paiol tá indo bem" → entende "paiol" como setor

### Leitura automática de notas fiscais eletrônicas (XML)
Produtor manda o XML da NF-e que recebeu do fornecedor. Sistema extrai 100% dos dados estruturados — sem OCR, sem erro.

### Alertas por SMS em regiões sem internet
Fazendas com sinal ruim recebem alertas críticos por SMS comum (fluxo de caixa negativo, vencimento, etc.)

---

## Ideias de negócio

### Onboarding assistido (serviço pago)
Pra cliente novo com muito histórico em planilhas:
- Sessão de 2h com atendente humano
- Importa tudo, configura setores, treina a IA com os dados do cliente
- Cobra uma taxa única de setup

### Parceria com cooperativas
Cooperativas oferecem o Cérebro Rural como benefício aos associados. A cooperativa paga um valor agregado e oferece subsídio ao produtor.

### Versão "peão" gratuita
App do peão é sempre grátis. Só o dono/gerente paga. Isso acelera adoção (dono compra, peão usa).

### Marketplace de serviços rurais
Se a plataforma tem muitos fazendeiros, pode virar ponto de encontro para:
- Vendedores de insumo
- Prestadores de serviço (veterinário, inseminador, transportador)
- Frigoríficos comprando gado

Fonte de receita adicional além da assinatura.

---

## Módulos futuros (depois dos 9 principais)

### Módulo Reprodução
- Controle de cobertura, prenhez, parto
- Histórico genealógico
- Indicadores de fertilidade

### Módulo Sanidade
- Calendário de vacinação
- Histórico de tratamentos
- Gestão de carência de medicamentos

### Módulo Máquinas
- Horímetro de trator
- Manutenção preventiva
- Consumo de combustível por máquina

### Módulo Clima
- Integração com estações meteorológicas
- Previsão de chuva por fazenda
- Alertas de geada, seca prolongada

### Módulo Carbono / ESG
- Cálculo de pegada de carbono
- Crédito de carbono gerado
- Relatórios pra exportação (mercado europeu)

### Módulo Veículos Particulares
- Gastos do carro pessoal
- IPVA, seguro, combustível
- Separado do módulo Máquinas (que é produtivo)

---

*Quando promover uma ideia pro roadmap principal, apagar daqui e adicionar em `ROADMAP.md`.*

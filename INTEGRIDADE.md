# Camada de Integridade — Cérebro Rural

> Pilar fundamental do sistema. Toda informação que entra passa por cinco checkpoints.
> Nenhum dado é gravado no banco sem aprovação final. Zero tolerância para duplicatas, erros de formato ou dados suspeitos.

---

## Princípio

**Conexão entre apps só é confiável por dois motivos: ausência de erros e excesso de assertividade.**

Um sistema que grava dados errados silenciosamente é pior que um sistema que não grava nada. A camada de integridade é obsessiva na prevenção.

---

## Os cinco checkpoints

Todo dado, vindo de qualquer fonte (app nativo, WhatsApp, email, foto de nota, importação Excel), atravessa os mesmos cinco checkpoints em ordem.

### Checkpoint 1 — Validação de formato

**O que faz:** confere se os campos obrigatórios existem, se os tipos batem, se os valores estão em range permitido.

**Regras por tipo de campo:**
- `valor`: número positivo, máximo 8 dígitos antes da vírgula
- `data`: formato ISO válido, não pode ser mais de 10 anos no passado ou 2 anos no futuro
- `fazenda_id`: UUID válido e pertencente ao usuário logado
- `tipo`: apenas ENTRADA, SAIDA ou TRANSFERENCIA
- `quantidade`: número positivo, até 3 casas decimais

**Ação em caso de erro:** bloqueio imediato. Retorna a mensagem específica indicando qual campo e por quê.

**Exemplo:**
```
❌ Erro: campo "valor" está vazio.
❌ Erro: data "32/13/2026" não é válida.
❌ Erro: quantidade negativa (-5) não é permitida.
```

---

### Checkpoint 2 — Detecção de duplicatas

**O que faz:** impede que o mesmo evento seja registrado duas vezes.

**Estratégias:**

1. **Hash de conteúdo**
   - Gera um hash a partir de: `fazenda_id + app_origem + referencia_tipo + descricao + valor + data (com precisão de minuto)`
   - Se o hash já existe no banco nas últimas 48h → marca como possível duplicata

2. **Janela de tempo para multi-canal**
   - Mesmo usuário registra algo similar por WhatsApp e pelo app em menos de 5 minutos → alerta
   - IA compara o conteúdo e pergunta: "isso é a mesma coisa que você já registrou?"

3. **Chave única por contexto**
   - Nota fiscal: `fornecedor + numero_nota` é único
   - Folha: `funcionario_id + competencia` é único
   - Recebimento de aluguel: `contrato_id + competencia` é único
   - Se já existe, bloqueia e mostra o registro original

**Ação em caso de duplicata:**
- Duplicata certa (chave única): bloqueia com link pro registro original
- Duplicata provável (hash próximo): pergunta ao usuário

---

### Checkpoint 3 — Perguntas específicas da IA

**O que faz:** resolve ambiguidades antes de gravar. A IA nunca assume — sempre pergunta.

**Gatilhos de pergunta:**

| Situação                                      | Pergunta que a IA faz                          |
|-----------------------------------------------|------------------------------------------------|
| Nome de pessoa com múltiplos match            | "Qual João? João Silva ou João Santos?"        |
| Item não cadastrado                           | "Esse item não existe. Criar novo ou é sinônimo de X?" |
| Valor sem indicação de entrada/saída          | "É entrada ou saída?"                          |
| Pasto sem nome específico                     | "Qual pasto? Pasto 1, Pasto 3 ou Curral?"      |
| Quantidade sem unidade                        | "50 do quê? Sacos, kg ou cabeças?"             |
| Data ausente                                  | "A data é hoje ou outra? Me confirma"          |
| Voz transcrita com baixa confiança            | "Entendi isso: [transcrição]. Está correto?"   |

**Comportamento:**
- IA faz **uma pergunta por vez**
- Apresenta opções como botões quando possível (evita digitação)
- Se o usuário não souber responder: salva como "rascunho" e pede revisão depois

---

### Checkpoint 4 — Detecção estatística de anomalias

**O que faz:** compara o novo dado com o histórico e alerta quando algo foge muito do padrão.

**Métricas monitoradas:**

1. **Valor fora do padrão da categoria**
   - Média + desvio padrão dos últimos 6 meses por subcategoria
   - Se o novo valor está acima de 3 desvios padrão → alerta
   - Exemplo: "Compra de sal mineral geralmente é R$ 400. Esta é R$ 4.800. Confirmar?"

2. **Preço de mercado (quando aplicável)**
   - Arroba do boi: consulta preço CEPEA ou tabela manual
   - Se o preço registrado está fora do range esperado → alerta
   - Exemplo: "Preço de R$ 50/@ está muito abaixo. Mercado está em R$ 320/@. Confirmar?"

3. **Volume fora do padrão**
   - Saídas de ração hoje = 15 sacos, média diária = 3 sacos → alerta
   - "Saída de ração hoje está 5x acima da média. Conferir?"

4. **Fornecedor novo em compra de alto valor**
   - Primeira compra de um fornecedor + valor > R$ 5.000 → alerta
   - "Este é um fornecedor novo. Confirma a compra de R$ 8.000?"

5. **Funcionário com lançamento fora do expediente**
   - Saída registrada pelo peão às 3h da manhã → alerta

**Ação:** não bloqueia, mas exige confirmação explícita com justificativa.

---

### Checkpoint 5 — Confirmação humana

**O que faz:** mostra um preview final do que vai ser gravado, já com tudo classificado, e espera o OK.

**Formato do preview:**

```
Vou registrar:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📤 SAÍDA
R$ 450,00
Data: 19/04/2026 14:32

Item: Ração proteinada (2 sacos)
Setor: Pasto 3
Retirado por: José
Liberado por: Thiago
Motivo: alimentação do lote 4

Categoria financeira:
Custo de Produção / Insumo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[✅ Confirmar]  [✏️ Corrigir]  [❌ Cancelar]
```

**Regras:**
- Nenhum lançamento entra sem esse passo (exceto se configurado como "modo rápido" para usuários avançados)
- Usuário pode editar qualquer campo antes de confirmar
- Cancelar descarta completamente (nem salva como rascunho)

---

## Alertas em tempo real (pós-gravação)

Depois que o dado está no banco, o sistema monitora e emite alertas quando algo precisa de atenção imediata:

- 🔴 **Saldo de item ficou negativo** — erro de registro ou furto
- 🟠 **Estoque abaixo do mínimo** — precisa repor
- 🟠 **Conta vencendo em 3 dias** — lembrete de pagamento
- 🟠 **Aluguel atrasado** — inquilino não pagou
- 🔴 **Fluxo de caixa vai ficar negativo em X dias** — projeção
- 🟠 **Pasto superlotado** — UA acima da capacidade
- 🟡 **Pasto em descanso há muito tempo** — hora de voltar a usar

**Canais de alerta:**
- Push notification no PWA
- WhatsApp (se configurado)
- Email diário consolidado

---

## Correção e aprendizado

### Quando o usuário corrige uma classificação da IA
- Sistema registra a correção
- Usa como treino para não errar de novo naquela fazenda
- Exemplo: "quando o usuário X fala 'Jorge', ele quase sempre quer dizer Jorge Almeida"

### Log de todas as decisões da IA
- Toda pergunta feita, toda anomalia detectada, toda classificação sugerida fica registrada
- Permite auditoria: "por que o sistema classificou X como Y?"

---

## Métricas de qualidade do sistema

Monitorar continuamente:

| Métrica                           | Meta           |
|-----------------------------------|----------------|
| Taxa de duplicatas bloqueadas     | > 99%          |
| Taxa de anomalias capturadas      | > 95%          |
| Tempo médio de confirmação        | < 10 segundos  |
| Taxa de correção pós-confirmação  | < 2%           |
| Taxa de erros reportados pelo contador | 0%        |

**Se alguma métrica degradar, é sinal de que a camada de integridade precisa ser reforçada.**

---

## Princípio de falha segura

**Na dúvida, o sistema sempre:**
1. Não grava
2. Pergunta
3. Prefere bloquear um lançamento correto a permitir um errado

Um lançamento bloqueado gera uma pergunta rápida. Um lançamento errado gera horas de auditoria e retrabalho com o contador.

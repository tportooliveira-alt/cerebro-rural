# Testes mínimos — Cérebro Rural

Todo micro-app precisa passar nos 4 testes abaixo antes de entrar no conector universal.

---

## Teste 1 — Lançamento correto

**Cenário:** usuário cria um registro no app.
**Esperado:** registro aparece na lista do próprio app e (quando conectado) gera lançamento em `lancamentos` com:
- `tipo` correto (ENTRADA ou SAIDA)
- `categoria` correta
- `app_origem` preenchido
- `referencia_id` apontando pro registro do app
- `valor` correto

**Como validar:** após criar o registro, rodar `SELECT * FROM lancamentos WHERE referencia_id = '<id>'` e verificar todos os campos.

---

## Teste 2 — Edição propaga em tempo real

**Cenário:** usuário edita o valor de um registro.
**Esperado:** a tabela `lancamentos` é atualizada automaticamente. O dashboard do Cérebro reflete a mudança em até 2 segundos.

**Como validar:** abrir o Cérebro em uma aba, editar o valor em outra aba do app, conferir que o total atualiza.

---

## Teste 3 — Exclusão limpa

**Cenário:** usuário deleta um registro.
**Esperado:** o registro em `lancamentos` correspondente também é removido (ou marcado como `status='cancelado'`). Nenhum "rastro fantasma" no fluxo de caixa.

**Como validar:** somar todos os lançamentos antes e depois — a diferença deve bater exatamente com o valor excluído.

---

## Teste 4 — IA responde corretamente

**Cenário:** produtor pergunta ao Cérebro: "quanto gastei com [categoria do app] esse mês?"
**Esperado:** a IA retorna um valor que bate com a soma manual dos lançamentos daquela categoria no período.

**Como validar:** perguntar 3 vezes em 3 formatos diferentes:
- "quanto gastei com ração esse mês?"
- "qual o total de saída de almoxarifado em abril?"
- "me mostra o custo de insumos até agora"

As três respostas devem ter o mesmo valor.

---

## Testes offline (extras para apps PWA)

### Teste 5 — Funciona sem internet
- Desconectar Wi-Fi
- Criar 3 registros
- Editar 1 registro
- Deletar 1 registro
- Reconectar
- Verificar que todos os 5 eventos sincronizaram corretamente na ordem certa

### Teste 6 — Conflito de sync
- Editar o mesmo registro em dois dispositivos offline
- Reconectar os dois
- Verificar que o sistema resolve o conflito de forma previsível (último a sincronizar ganha, mas avisa o usuário)

---

## Testes de importação

### Teste 7 — Excel bagunçado
- Pegar uma planilha real do produtor (com colunas desordenadas, células vazias, formatos mistos)
- Importar
- A IA deve mapear as colunas corretamente
- Preview deve deixar o usuário ajustar antes de confirmar
- Após confirmar, todos os registros entram corretamente

### Teste 8 — Foto de nota fiscal
- Tirar foto de cupom fiscal real
- Sistema deve extrair: fornecedor, data, itens, valor total
- Lançar automaticamente como SAIDA

---

## Checklist final antes de subir pra produção

- [ ] Todos os 8 testes passam
- [ ] RLS do Supabase testado (usuário A não vê dados do usuário B)
- [ ] PWA instalável no celular
- [ ] Funciona offline
- [ ] Performance: carrega em menos de 2s em 3G
- [ ] Acessibilidade: navegável por teclado e leitor de tela

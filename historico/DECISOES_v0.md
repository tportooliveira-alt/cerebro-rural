# Decisões — Cérebro Rural

> Log de decisões arquiteturais com data e motivo.
> Quando voltar atrás em alguma decisão, registrar aqui com a nova justificativa.

---

## D01 — Arquitetura de micro-apps separados

**Data:** abril 2026
**Decisão:** cada domínio vira um app independente (Almoxarifado, Pastagem, Obras, etc.) com sua própria URL, próprio deploy, próprio schema.

**Alternativa descartada:** um app monolítico com módulos.

**Por quê:**
- Evita o padrão de "conflito de IAs" que queimou o Thiago no FrigoGest
- Cada app pode evoluir no seu ritmo
- Falha em um não derruba os outros
- O peão usa um app, o dono usa outro — interfaces diferentes sem complexidade

---

## D02 — Conector universal via tabela única `lancamentos`

**Data:** abril 2026
**Decisão:** toda transação financeira de qualquer app vira um registro na tabela `lancamentos` com schema unificado.

**Alternativa descartada:** ETL entre bancos separados, ou eventos/filas.

**Por quê:**
- Simplicidade extrema — a IA lê uma tabela só
- Supabase compartilhado já resolve a integração
- Fácil de auditar
- Fácil de consultar no SQL direto

---

## D03 — Camada de Integridade obrigatória com 5 checkpoints

**Data:** abril 2026
**Decisão:** nenhum dado entra no banco sem passar por formato, duplicata, perguntas de IA, anomalia estatística e confirmação humana.

**Alternativa descartada:** gravação direta sem validações pesadas.

**Por quê:**
- Sem essa camada, o sistema vira lixo em 3 meses
- Duplicatas silenciosas corrompem relatórios
- Contador recebe dados confiáveis
- É o diferencial de qualidade do produto

---

## D04 — Cálculo de @ do boi = peso / 15

**Data:** abril 2026 (descoberto durante bug na Calculadora de Boi)
**Decisão:** 1 arroba = 15 kg, não 30 kg como estava no código original.

**Referência:** padrão brasileiro de mercado.

---

## D05 — Três modos na Calculadora de Boi

**Data:** abril 2026
**Decisão:** antes de sincronizar, a Calculadora pergunta se a pesagem é Compra, Venda ou Conferência interna.

**Por quê:**
- A mesma balança tem três propósitos completamente diferentes
- Cada modo gera lançamento diferente (ou nenhum) no Cérebro
- A lógica fica no app, não no Cérebro (o produtor sabe o contexto)

---

## D06 — Captura unificada em vez de integrar apps de notas

**Data:** abril 2026
**Decisão:** não tentar ler Apple Notes, Samsung Notes, Sticky Notes etc. Criar caixa de entrada única recebendo de WhatsApp, email, Share Sheet e Atalhos do iPhone.

**Alternativa descartada:** plugins para cada app de nota.

**Por quê:**
- Apple Notes não tem API pública (fim de papo)
- Manter plugins para cada app é custo eterno
- Caixa de entrada única é escalável

---

## D07 — Stack: React + TypeScript + Vite + Supabase + Vercel

**Data:** abril 2026
**Decisão:** stack padrão pra todos os micro-apps.

**Por quê:**
- É a stack que o Thiago já domina
- Supabase resolve banco, auth e realtime numa assinatura
- Vercel é rápido e gratuito pra PWAs
- TypeScript reduz bugs em runtime

**Exceção:** FrigoGest permanece na stack atual dele, não vai migrar.

---

## D08 — PWA em vez de React Native (v1)

**Data:** abril 2026
**Decisão:** todos os micro-apps são PWAs instaláveis, não apps nativos.

**Por quê:**
- Um código só pra iOS, Android e desktop
- Deploy instantâneo na Vercel sem review de loja
- Offline com Service Worker + IndexedDB
- Pode virar app nativo depois com Capacitor se necessário

---

## D09 — Custo médio ponderado no almoxarifado

**Data:** abril 2026
**Decisão:** custo de cada item é calculado por média ponderada a cada entrada, não FIFO ou LIFO.

**Fórmula:**
```
novo_custo = (saldo_atual * custo_atual + qtd_entrada * valor_entrada)
              / (saldo_atual + qtd_entrada)
```

**Por quê:**
- Mais simples de entender e auditar
- Aceito pela contabilidade brasileira
- Comum em sistemas de gestão rural

---

## D10 — Dois tokens do GitHub separados

**Data:** abril 2026
**Decisão:** FrigoGest e Cérebro Rural usam tokens de acesso pessoal diferentes.

**Por quê:**
- Se um token vazar, o outro projeto fica protegido
- Cada projeto tem sua própria identidade de segurança
- Thiago deixou explícito: nunca misturar os dois projetos

---

## Decisões pendentes (pra discutir)

- [ ] Nome comercial do produto (Cérebro Rural é codinome)
- [ ] Modelo de cobrança exato (valor do plano base, valor por módulo)
- [ ] Primeiro cliente (o próprio Thiago ou alguém externo)
- [ ] Se usar Edge Functions do Supabase ou API Routes da Vercel
- [ ] Biblioteca de gráficos no Cérebro (Recharts, Chart.js ou Visx)

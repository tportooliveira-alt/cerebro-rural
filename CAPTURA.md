# Captura Multi-Plataforma — Cérebro Rural

> Como capturar ideias e dados de qualquer lugar (Apple Notes, PC, celular, voz) sem depender de API fechada de terceiros.

---

## Princípio

Em vez de tentar ler cada app de nota existente (o que é impossível ou muito limitado), criar **uma caixa de entrada única** que recebe de qualquer canal aberto.

A IA triage a entrada e classifica em qual app ela vai parar.

---

## Canais de entrada suportados

### 1. WhatsApp Bot (principal para Brasil)

**Como funciona:**
- Número dedicado do Cérebro Rural no WhatsApp Business API
- Usuário envia texto, áudio, foto ou documento
- Bot responde confirmando recebimento
- IA processa e pergunta classificação

**Tecnologia:**
- WhatsApp Business API (Meta) ou Twilio
- Webhook recebe mensagens
- Salva em tabela `captura_inbox`

**Exemplos de uso:**
- Áudio: "comprei 20 sacos de sal no João por 600 reais" → vira entrada de almoxarifado pendente
- Foto de nota fiscal → OCR extrai dados → lançamento pendente
- Texto: "Obra do curral tá quase pronta" → vira observação no módulo Obras

---

### 2. Email de captura

**Como funciona:**
- Endereço dedicado: `captura@cerebrorural.com.br`
- Qualquer email enviado pra lá vira entrada
- Assunto é usado como título, corpo como conteúdo
- Anexos (PDF, foto, Excel) são processados automaticamente

**Tecnologia:**
- Serviço tipo Postmark, Mailgun ou SendGrid Inbound Parse
- Webhook recebe emails
- IA interpreta e classifica

**Vantagem:** funciona de qualquer lugar — Apple Notes tem botão "enviar por email", Gmail funciona de qualquer lugar, Outlook também.

**Exemplo de fluxo Apple Notes:**
1. Usuário escreve nota no Apple Notes
2. Toca "Enviar cópia" → Mail → envia pra `captura@cerebrorural.com.br`
3. Email cai no bot → IA processa → aparece na caixa de entrada do Cérebro

---

### 3. Share Sheet (PWA)

**Como funciona:**
- Quando o Cérebro Rural está instalado como PWA no iPhone/Android
- Ele aparece no menu "Compartilhar" do sistema operacional
- Usuário seleciona texto em qualquer app (Notes, navegador, etc.) → Compartilhar → Cérebro Rural
- O conteúdo cai direto na caixa de entrada

**Tecnologia:**
- Web Share Target API
- Configurado no `manifest.json` do PWA

**Exemplo:**
```json
"share_target": {
  "action": "/captura",
  "method": "POST",
  "params": {
    "title": "titulo",
    "text": "conteudo"
  }
}
```

---

### 4. Atalho do iPhone (iOS Shortcuts)

**Como funciona:**
- Thiago cria um Shortcut no iPhone chamado "Enviar pro Cérebro"
- O Shortcut recebe texto selecionado ou conteúdo da nota
- Faz POST pra API do Cérebro com token de autenticação
- Confirma recebimento

**Tecnologia:**
- Apple Shortcuts app (nativo, grátis)
- API REST do Cérebro Rural com endpoint `/api/captura`
- Token pessoal por usuário (armazenado no Shortcut)

**Vantagem:** um toque na tela da nota e o conteúdo já foi.

---

### 5. Captura nativa dentro do PWA

**Como funciona:**
- Dentro do próprio app Cérebro Rural tem botão flutuante global
- Três opções: gravar voz, tirar foto, digitar texto
- Funciona offline

**Tecnologia:**
- MediaRecorder API (áudio)
- getUserMedia (câmera)
- Web Speech API (transcrição de voz)
- IndexedDB (gravação offline)

---

### 6. Telegram Bot (alternativa)

Para quem prefere Telegram em vez de WhatsApp. Mesma lógica, canal diferente.

---

## Caixa de Entrada Única (Inbox)

Toda captura, de qualquer canal, cai na mesma tabela:

```sql
CREATE TABLE captura_inbox (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fazenda_id      uuid REFERENCES fazendas(id),
  usuario_id      uuid REFERENCES users(id),
  canal           text NOT NULL, -- 'whatsapp' | 'email' | 'share' | 'shortcut' | 'pwa' | 'telegram'
  tipo_conteudo   text NOT NULL, -- 'texto' | 'audio' | 'imagem' | 'pdf' | 'excel'
  conteudo_raw    text,           -- conteúdo bruto (texto ou URL do arquivo)
  transcricao     text,           -- se for áudio, transcrição
  extracao_ia     jsonb,          -- dados extraídos pela IA
  sugestao_app    text,           -- qual micro-app a IA sugeriu
  status          text DEFAULT 'pendente',
                  -- 'pendente' | 'processando' | 'classificado' | 'descartado' | 'duplicado'
  criado_em       timestamptz DEFAULT now(),
  processado_em   timestamptz
);
```

---

## Fluxo de processamento da inbox

```
[Entrada bruta]
      ↓
[Canal recebe e salva em captura_inbox]
      ↓
[IA de triagem (Claude Haiku)]
      ↓
[Pergunta 1 do Checkpoint 3 (INTEGRIDADE)]
      "Isso é uma compra, uma saída, uma obra ou um lembrete?"
      ↓
[Usuário responde com um toque]
      ↓
[Redireciona pro fluxo do app correto (Almoxarifado, Pastagem, etc.)]
      ↓
[Demais checkpoints da Camada de Integridade]
      ↓
[Registro final no app destino + lancamentos]
```

---

## Ambiguidade: a IA nunca assume

Se a IA não tem certeza absoluta pra qual app vai, **ela pergunta com opções em botão**:

```
Recebi essa nota:
"Paguei 500 reais pro João ontem"

Onde registrar?
[ Folha do funcionário João ]
[ Pagamento de fornecedor ]
[ Retirada pessoal ]
[ Outro — especificar ]
```

---

## Deduplicação entre canais

Se o mesmo evento chega por dois canais em pouco tempo:
- WhatsApp recebe: "comprei 20 sacos de sal"
- Email recebe foto da mesma nota fiscal 3 minutos depois

→ Checkpoint 2 da Camada de Integridade detecta e pergunta ao usuário se é o mesmo evento.

---

## O que foi descartado (não vale a pena)

| Opção                    | Por quê não                                       |
|--------------------------|---------------------------------------------------|
| Apple Notes direto       | Sem API pública, Apple não permite acesso         |
| Samsung Notes direto     | Sem API aberta                                    |
| Sticky Notes Windows     | Banco local, inviável de integrar                 |
| Ler clipboard do PC      | Fere privacidade, não escalável                   |
| Plugin próprio Office    | Complexidade alta, baixa adoção                   |

---

## Roadmap de implementação da captura

### Fase 1 — MVP de captura
- [ ] PWA com botão flutuante de captura (voz, foto, texto)
- [ ] Caixa de entrada funcional com triagem manual

### Fase 2 — Canal WhatsApp
- [ ] Integrar WhatsApp Business API
- [ ] Bot recebe e responde
- [ ] IA de triagem automática

### Fase 3 — Email
- [ ] Endereço dedicado de captura
- [ ] Processamento de anexos (PDF, Excel, foto)

### Fase 4 — Share Sheet e Shortcut
- [ ] Configurar Web Share Target
- [ ] Documentar como criar Shortcut no iPhone
- [ ] Template de Shortcut pronto pra baixar

### Fase 5 — Telegram (opcional)
- [ ] Bot alternativo pra quem não usa WhatsApp

# SportConnect — Arquitetura

## 1. Visão geral

```
┌──────────────────────┐        HTTPS/JSON           ┌──────────────────────────┐
│      App Móvel         │ ──────────────────────────▶ │        API REST           │
│   Flutter (Dart)        │ ◀────────────────────────── │   Node.js + TypeScript    │
│   Provider (estado)     │                             │   Express                  │
│   Secure Storage         │                            │   JWT auth middleware      │
└──────────────────────┘ ◀══════════════════════════▶ └─────────────┬────────────┘
                              Socket.io (tempo real:                 │ Sequelize (ORM)
                              chat de equipa e mensagens privadas)    ▼
                                                            ┌──────────────────────┐
                                                            │        MySQL 8         │
                                                            │  19 entidades:          │
                                                            │  users, teams, events,  │
                                                            │  attendance, posts,     │
                                                            │  achievements, polls,   │
                                                            │  chat_messages, ...     │
                                                            └──────────────────────┘

              CI: GitHub Actions (lint + 85 testes + build)
              Dev infra: Docker Compose (MySQL + Adminer)

              Trabalho futuro (fora de âmbito do Projeto II):
              Firebase Cloud Messaging — apenas para notificações push nativas
              (ver docs/firebase-notifications.md — o chat já funciona em
              tempo real via Socket.io, sem depender do Firebase)
```

> **Nota:** numa versão anterior deste documento (Projeto I), esta secção
> apontava o Firebase/Firestore como solução planeada para o chat em tempo
> real. Essa decisão foi revista durante o Projeto II — o tempo real foi
> implementado com **Socket.io** sobre o próprio servidor Express, sem
> depender de infraestrutura externa. O Firebase mantém-se relevante
> apenas para uma funcionalidade mais restrita e ainda não implementada:
> notificações push nativas (ver
> [`docs/firebase-notifications.md`](firebase-notifications.md)).

## 2. Justificação das escolhas

- **Flutter**: um único *codebase* para Android/iOS, adequado ao prazo do
  projeto académico.
- **Node.js + TypeScript + Express**: tipagem estática reduz erros,
  ecossistema maduro, fácil de testar (Jest/Supertest).
- **MySQL**: dados fortemente relacionais (utilizadores↔equipas↔eventos↔presenças),
  chaves estrangeiras e integridade referencial são naturais em SQL.
- **Sequelize (ORM)**: mapeia diretamente o schema relacional para
  modelos TypeScript, com associações declaradas em código.
- **JWT**: autenticação sem estado, simples de implementar no Flutter
  (guardar o token em *secure storage*) sem exigir armazenamento de
  sessão adicional no servidor.
- **Socket.io**: comunicação instantânea (chat de equipa e mensagens
  privadas) integrada diretamente sobre o servidor Express já existente
  — evita levantar um serviço de tempo real à parte só para isto.
- **Código de 6 dígitos para recuperação de password**: alternativa mais
  simples do que um *link* por email, que exigiria configurar *deep
  linking* na app; semelhante à verificação por SMS já familiar aos
  utilizadores.
- **Docker Compose**: ambiente de desenvolvimento reprodutível (MySQL +
  Adminer) sem instalação manual.
- **GitHub Actions**: lint + 85 testes automáticos + build em cada
  *push*/*PR*.
- **Firebase Cloud Messaging (trabalho futuro)**: reservado
  especificamente para o envio de notificações push nativas — não para o
  chat, que já está resolvido pelo Socket.io. Ver
  [`docs/firebase-notifications.md`](firebase-notifications.md) para o
  detalhe completo do que falta.

## 3. Camadas do servidor (`apps/server`)

```
src/
├─ config/       # ligação à BD, variáveis de ambiente
├─ models/       # 19 entidades Sequelize — User, Team, Event, Attendance,
│                # Post, PostLike, Achievement, DeviceToken, ChatMessage,
│                # Poll, PollOption, PollVote, GameStat, DirectMessage,
│                # SavedEvent, PasswordReset, CoachHistory,
│                # MembershipHistory, AuditLog
├─ middleware/   # autenticação JWT, verificação de role, tratamento de erros
├─ controllers/  # lógica de negócio de cada recurso
├─ routes/       # definição dos 46 endpoints REST, em 15 grupos
├─ realtime.ts   # configuração do Socket.io (chat + mensagens privadas)
└─ ...

tests/           # 14 suites, 85 testes (Jest + Supertest)
```

## 4. Segurança

- Passwords com `bcrypt`.
- JWT assinado com segredo em variável de ambiente (`JWT_SECRET`).
- Middleware `authenticate` valida o token em rotas protegidas;
  middleware `requireRole` restringe por papel (`athlete`/`coach`/`admin`).
- Autorização também verificada ao nível dos dados — por exemplo, um
  treinador não consegue atribuir pontos a um atleta de outra equipa,
  mesmo com um token válido (ver `docs/testing/README.md`).
- Recuperação de password: código de 6 dígitos com validade de 15
  minutos, guardado apenas como *hash* SHA-256; a resposta do pedido de
  recuperação é sempre a mesma mensagem, exista ou não conta associada ao
  email (evita enumeração de contas).
- Contactos de emergência de um atleta só visíveis a ele próprio e ao
  treinador da sua equipa.
- Validação de *input* nos *controllers* (campos obrigatórios, tipos,
  enums).
- Helmet + CORS configurados no Express.

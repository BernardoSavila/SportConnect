# SportConnect — Requisitos e User Stories

## 1. Visão geral
SportConnect é uma app mobile de gestão de equipas desportivas que permite a
treinadores organizar treinos/jogos, comunicar com atletas, e a atletas
consultarem calendário, confirmarem presença e acompanharem o seu desempenho
e conquistas.

## 2. MVP — funcionalidades mínimas (Projeto 1)

| # | Funcionalidade | Prioridade |
|---|---|---|
| 1 | Autenticação (registo/login com JWT) | MVP |
| 2 | Perfis (atleta / treinador / admin) | MVP |
| 3 | Agenda de treinos/jogos | MVP |
| 4 | Confirmação de presença | MVP |
| 5 | Feed de notícias/avisos | MVP |
| 6 | Posts com upload de media (placeholder de URL) | MVP — **evoluído**: upload real de imagens (multer) |
| 7 | Gamificação — pontos/medalhas (modelo de dados, sem lógica complexa) | MVP — **completo**: treinador atribui pontos pela app (`POST /achievements`), ranking atualiza automaticamente |
| 8 | Chat | Stub (placeholder — Projeto 2) |
| 9 | Notificações push (FCM) | Stub — apenas registo de device token |
| 10 | Chat em tempo real / Firebase | Nice-to-have (Projeto 2) |
| 11 | Estatísticas avançadas de desempenho | Nice-to-have (Projeto 2) |

## 3. User Stories

### Autenticação
**US01 — Registo**
> Como visitante, quero criar uma conta com email e password para aceder à app.

Critérios de aceitação:
- Email único e válido; password com mínimo 8 caracteres.
- Password é guardada com hash (bcrypt), nunca em texto simples.
- Retorna token JWT após registo bem-sucedido.

**US02 — Login**
> Como utilizador registado, quero fazer login com email/password para aceder às minhas funcionalidades.

Critérios de aceitação:
- Credenciais inválidas devolvem erro 401 sem detalhes sensíveis.
- Login bem-sucedido devolve JWT válido por 7 dias e dados básicos do utilizador.

### Agenda
**US03 — Ver calendário**
> Como atleta, quero fazer login para ver o calendário do meu clube.

Critérios de aceitação:
- Lista eventos (treinos/jogos) ordenados por data, filtráveis por equipa.
- Cada evento mostra título, tipo, data/hora, local.

**US04 — Criar evento**
> Como treinador, quero criar um treino com data/hora para notificar atletas.

Critérios de aceitação:
- Apenas utilizadores com role `coach`/`admin` podem criar eventos.
- Campos obrigatórios: título, tipo (training/match), data início/fim, equipa.
- Evento criado fica visível de imediato na agenda da equipa.

**US05 — Confirmar presença**
> Como atleta, quero confirmar presença num treino.

Critérios de aceitação:
- Estado inicial de presença é `pending`.
- Atleta pode alterar entre `present`/`absent` antes do evento decorrer.
- Treinador vê lista de confirmações por evento.

### Feed / Posts
**US06 — Ver feed**
> Como atleta, quero ver avisos e notícias publicadas pela equipa.

Critérios de aceitação:
- Feed ordenado por data decrescente, filtrável por equipa.

**US07 — Publicar aviso**
> Como treinador, quero publicar um aviso com texto e (opcionalmente) uma imagem.

Critérios de aceitação:
- Apenas coach/admin podem publicar.
- Suporta campo `media_url` (placeholder — upload real fica para Projeto 2).

### Perfis
**US08 — Ver perfil**
> Como atleta, quero ver o meu perfil e o de colegas de equipa.

Critérios de aceitação:
- Mostra nome, role, equipa, pontos/medalhas acumulados.

### Gamificação
**US09 — Ranking**
> Como atleta, quero ver o ranking da equipa por pontos.

Critérios de aceitação:
- Lista ordenada de utilizadores por soma de pontos em `achievements`.

### Chat (stub)
**US10 — Aceder ao chat**
> Como atleta, quero abrir a secção de chat para ver conversas da equipa.

Critérios de aceitação (Projeto 1):
- Interface e modelo de dados existem; mensagens são mockadas/estáticas.
- Documentado o plano de migração para Firebase Realtime/Firestore + WebSockets (Projeto 2).

### Notificações (stub)
**US11 — Registar dispositivo**
> Como utilizador, quero que a app registe o meu dispositivo para receber notificações no futuro.

Critérios de aceitação:
- Endpoint `POST /devices/register-token` guarda o token associado ao utilizador.
- Envio real de notificações via FCM fica para Projeto 2.

## 4. Fora de âmbito no Projeto 1
- Chat em tempo real funcional.
- Upload real de ficheiros de media (usa-se URL placeholder).
- Notificações push efetivamente enviadas.
- Estatísticas avançadas e analytics.

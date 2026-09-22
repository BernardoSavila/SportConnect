# SportConnect — Checklist de Entrega & Roteiro de Demo (Projeto 1)

## Checklist rápido para o dia da apresentação

- [x] Repositório com README claro ("how to run")
- [x] Wireframes + protótipo (SVG low-fi em `docs/wireframes/`)
- [x] Diagrama de arquitetura (`docs/architecture.md`)
- [x] SQL / ER (`docs/db/schema.sql`, `docs/db/er.svg`) + OpenAPI (`docs/openapi.yaml`)
- [x] App Flutter com navegação entre telas principais (mocks + API real)
- [x] API com endpoints mínimos a responder (mocked/seeded), testada (10 testes automatizados)
- [x] Demo script (o que mostrar em 5 minutos) — abaixo
- [ ] Slides com riscos e roadmap para o Projeto 2 — a preparar em PowerPoint/Canva

## Roteiro de demonstração (5 minutos)

1. **(30s) Contexto** — objetivo do SportConnect e público-alvo (equipas amadoras).
2. **(1 min) Arquitetura** — mostrar `docs/architecture.md` e o diagrama; justificar Flutter + Node/TS + MySQL.
3. **(1 min) Backend ao vivo**
   - `docker compose -f infra/docker-compose.yml up -d`
   - `cd apps/server && npm run dev`
   - Mostrar `GET /health` e um pedido autenticado (ex.: Postman/Insomnia usando `docs/openapi.yaml`).
4. **(1.5 min) App mobile**
   - Login com utilizador `atleta1@sportconnect.pt`.
   - Navegar: Feed → Calendário → Detalhes do evento → confirmar presença.
   - Trocar para conta `coach@sportconnect.pt` e mostrar o Painel do Treinador.
5. **(30s) Testes e CI** — mostrar `npm test` a passar e o workflow `.github/workflows/ci.yml`.
6. **(30s) Roadmap Projeto 2** — chat em tempo real (Firebase), notificações push (FCM), upload real de media.

## Riscos identificados

| Risco | Mitigação |
|---|---|
| Chat/tempo real fora de âmbito no Projeto 1 | Stub documentado + modelo de dados já preparado (`chat_messages`) |
| Sem upload real de ficheiros | Campo `media_url` aceita link externo; upload fica para Projeto 2 |
| Autenticação simples (JWT local) | Suficiente para o MVP; migração para Firebase Auth é opcional no Projeto 2 |
| Cobertura de testes limitada ao backend | Mobile usa fallback mock, reduzindo risco de falha de demo sem rede |

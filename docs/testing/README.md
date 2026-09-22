# Testes — SportConnect

Documentação completa da estratégia de testes usada para validar a
plataforma. Cobre quatro frentes complementares: testes automatizados ao
*backend*, testes manuais/exploratórios da API com Postman, testes
funcionais na aplicação móvel, e testes não funcionais de segurança e
desempenho.

A suite automatizada foi construída **a par do próprio desenvolvimento** —
nenhuma funcionalidade nova era considerada terminada sem os respetivos
testes escritos e a passar. Funciona como rede de segurança contra
regressões nas funcionalidades já existentes.

## Como correr

```bash
cd apps/server
npm test
```

Não é preciso ter o Docker/MySQL a correr — os testes usam SQLite em
memória, reposta antes de cada suite (`sequelize.sync({ force: true })`),
garantindo isolamento total entre testes.

```
Test Suites: 15 passed, 15 total
Tests:       102 passed, 102 total
```

## Suites de testes automatizados (Jest + Supertest)

| Suite | Nº testes | Cobre |
|---|---|---|
| `auth.test.ts` | 4 | Registo, login, rejeição de credenciais inválidas |
| `register-team.test.ts` | 5 | Criação de equipa nova no registo, geração do código de convite |
| `password-reset.test.ts` | 7 | Pedido e confirmação de recuperação de password por código |
| `profile-password.test.ts` | 7 | Edição de perfil e alteração de password autenticada |
| `events.test.ts` | 3 | Criação de eventos e confirmação de presença, com controlo de permissões |
| `spond-features.test.ts` | 9 | Contactos de emergência, lista de espera, duplicar evento, lembretes |
| `saved-events.test.ts` | 5 | Calendário pessoal — guardar e remover eventos |
| `gamification.test.ts` | 4 | Atribuição de pontos e permissões entre equipas |
| `feed.test.ts` | 3 | Publicações, ranking e perfil público do utilizador |
| `extra-features.test.ts` | 5 | Gostos em publicações, avatar e lista de confirmações |
| `chat-media.test.ts` | 2 | Persistência de mensagens de imagem e áudio no chat |
| `new-features.test.ts` | 11 | Sondagens, estatísticas de carreira, exportação `.ics`, relatório PDF |
| `upload.test.ts` | 2 | Upload de multimédia autenticado |
| `edit-delete.test.ts` | 18 | Editar/cancelar eventos, editar/eliminar publicações e sondagens |
| `admin.test.ts` | 39 | Painel de Admin — ficha da equipa, ficha do treinador, histórico, troca de treinador (cria conta nova), treinador adjunto, estatísticas, plantel, remoção de atletas, comparação de épocas, avisos oficiais, auditoria, relatório PDF |
| **Total** | **124** | |

### Notas sobre a cobertura

- **`admin.test.ts`** confirma o registo histórico de treinadores: trocar
  de treinador fecha o registo antigo (`ended_at`) e abre um novo, nunca
  apaga histórico; confirma também que o admin de uma equipa não acede
  aos dados de outra.
- **`edit-delete.test.ts`** valida a regra de negócio mais delicada do
  projeto: uma sondagem com votos já registados só permite editar a
  pergunta — tentar alterar as opções depois de haver votos é
  explicitamente rejeitado (`400 Bad Request`).
- **`spond-features.test.ts`** confirma que os contactos de emergência de
  um atleta só ficam visíveis a ele próprio e ao treinador da sua equipa,
  e que a lista de espera promove automaticamente o primeiro membro
  quando alguém desiste.
- **`gamification.test.ts`** confirma que um treinador não consegue
  atribuir pontos a um atleta de outra equipa, mesmo invocando o
  *endpoint* diretamente com um token válido — a verificação acontece ao
  nível dos dados, não só da rota.
- **`password-reset.test.ts`** cobre o ciclo completo: geração do código,
  envio do email (simulado com *mock*, sem depender de rede), e as três
  rejeições esperadas — código errado, já usado, ou expirado.

## Testes manuais e exploratórios (Postman)

O Postman foi usado durante o desenvolvimento para validar cada
*endpoint* novo assim que ficava pronto — o formato do pedido, os
cabeçalhos necessários (nomeadamente o token JWT no cabeçalho
`Authorization`) e a forma da resposta — antes de esse comportamento
ficar fixado num teste automatizado permanente. Serviu também para
reproduzir rapidamente cenários de erro pontuais (token inválido, campo
em falta) sem escrever código de teste só para essa verificação.

## Testes de sistema funcionais (aplicação móvel)

Executados manualmente, com *checklist*, num emulador Android e, para os
testes de desempenho, também num dispositivo físico. Cobrem os fluxos
completos de utilizador nos dois perfis: login, registo (código e equipa
nova), recuperação de password, feed, agenda, confirmação de presença e
lista de espera, duplicar evento, registar estatísticas, chat (texto e
áudio), mensagens privadas, sondagens, editar perfil e contactos de
emergência.

**16 cenários testados, 100% com o resultado esperado.**

## Testes não funcionais — Segurança

| Cenário | Resultado esperado |
|---|---|
| Acesso sem token JWT | `401 Unauthorized` |
| Token inválido/adulterado | `401 Unauthorized` |
| Password em texto simples na BD | Nunca — apenas hash bcrypt armazenado |
| Atleta tenta criar evento | `403 Forbidden` |
| Contactos de emergência de outro atleta | Não incluídos na resposta |
| Pontos a atleta de outra equipa | `400 Bad Request` |

**6 cenários testados, 100% com o resultado esperado.**

## Testes não funcionais — Desempenho

| Cenário | Resultado |
|---|---|
| Troca de separador na app (antes/depois de `IndexedStack`) | Instantânea após a correção |
| Resposta da API em ambiente local | Percetivelmente imediata |
| Fluidez em dispositivo físico vs. emulador | Sem quebras percetíveis |

**3 cenários testados, 100% com o resultado esperado.**

## Resumo consolidado

| Categoria | Total | Passou | Taxa de sucesso |
|---|---|---|---|
| Testes automatizados (backend) | 67 → 85 → **119** | 119 | 100% |
| Testes de sistema funcionais (mobile) | 16 | 16 | 100% |
| Testes não funcionais — Segurança | 6 | 6 | 100% |
| Testes não funcionais — Desempenho | 3 | 3 | 100% |
| **Total** | **149** | **149** | **100%** |

> O número de testes automatizados subiu de 67 para 85 com a suite
> `edit-delete.test.ts` (editar/cancelar eventos, avisos e sondagens), e
> de 85 para 119 com a suite `admin.test.ts` (Painel de Admin),
> que foi crescendo por fases à medida que o painel ganhou mais
> funcionalidades.

Para o relato completo, incluindo os problemas técnicos reais encontrados
durante o desenvolvimento e as soluções adotadas, ver o Capítulo 7 do
relatório do projeto.

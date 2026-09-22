# SportConnect — Casos de Uso

## 1. Fluxos principais

1. **Registo/Login** → utilizador cria conta ou autentica-se → recebe JWT.
2. **Ver calendário** → atleta autenticado consulta eventos da sua equipa.
3. **Confirmar presença** → atleta seleciona evento e define estado de presença.
4. **Ver feed** → atleta consulta posts/avisos da equipa.
5. **Ver perfil** → atleta consulta o seu perfil e estatísticas de gamificação.
6. **Coach cria evento** → treinador preenche formulário e publica treino/jogo.
7. **Coach publica aviso** → treinador cria post visível no feed da equipa.

## 2. Diagramas de sequência (descrição textual — ver `docs/wireframes/*.svg` para versão visual)

### 2.1 Login
```
Atleta -> App: insere email/password
App -> API: POST /auth/login
API -> DB: SELECT user WHERE email
DB -> API: user + password_hash
API -> API: bcrypt.compare(password, hash)
API -> App: 200 { token, user }
App -> SecureStorage: guarda token
App -> Atleta: navega para Home
```

### 2.2 Criar evento (Coach)
```
Coach -> App: preenche formulário de evento
App -> API: POST /events (Authorization: Bearer <token>)
API -> Middleware: valida JWT + role coach/admin
API -> DB: INSERT INTO events
DB -> API: evento criado (id)
API -> App: 201 { event }
App -> Coach: mostra confirmação + evento na agenda
```

### 2.3 Confirmar presença
```
Atleta -> App: abre detalhes do evento
App -> API: GET /events/:id
API -> App: dados do evento + estado atual attendance
Atleta -> App: seleciona "Presente"
App -> API: POST /events/:id/attendance { status: "present" }
API -> DB: UPSERT attendance
DB -> API: ok
API -> App: 200 { attendance }
App -> Atleta: atualiza UI (badge "Confirmado")
```

## 3. Casos de uso por ator

| Ator | Caso de uso |
|---|---|
| Visitante | Registar conta |
| Atleta | Login, ver calendário, confirmar presença, ver feed, ver perfil, ver ranking |
| Treinador | Tudo o que o atleta faz + criar evento, publicar aviso, ver confirmações da equipa |
| Admin | Tudo o que o treinador faz + gerir equipas e utilizadores |

## 4. Regras de negócio relevantes
- Um utilizador pertence no máximo a uma equipa (`users.team_id`), simplificação para o Projeto 1.
- Apenas coach/admin criam eventos e posts.
- Presença só pode ser alterada por o próprio atleta ou por admin.
- Pontos de gamificação (`achievements`) são atribuídos manualmente pelo treinador no MVP (sem lógica automática).

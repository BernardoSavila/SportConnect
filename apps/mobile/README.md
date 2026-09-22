# SportConnect — Mobile (Flutter)

App móvel completa do SportConnect, com os três perfis de utilizador
(Atleta, Treinador e Admin) a funcionar de ponta a ponta contra a
API real — autenticação, eventos com lista de espera, chat em tempo
real, feed, sondagens, gamificação, as ferramentas de gestão do
treinador (incluindo editar/cancelar eventos, avisos e sondagens) e o
painel de supervisão institucional do Admin.

## Ecrãs

| Ecrã | Ficheiro |
|---|---|
| Login | `login_screen.dart` |
| Registo (código, ou criar equipa como treinador/presidente) | `register_screen.dart` |
| Recuperar / definir nova password | `forgot_password_screen.dart`, `reset_password_screen.dart` |
| Feed de avisos | `feed_screen.dart` |
| Agenda / calendário | `calendar_screen.dart` |
| Detalhe do evento (presença, lista de espera, mapa) | `event_details_screen.dart` |
| Mapa do evento | `map_view_screen.dart` |
| Equipa (lista de membros) | `team_screen.dart` |
| Detalhe do atleta (vista do treinador) | `athlete_detail_screen.dart` |
| Chat de equipa | `chat_screen.dart` |
| Mensagens privadas (lista + conversa) | `conversations_screen.dart`, `dm_chat_screen.dart` |
| Sondagens | `polls_screen.dart` |
| Perfil (estatísticas, conquistas, contactos de emergência) | `profile_screen.dart` |
| Painel do Treinador | `coach_panel_screen.dart` |
| Painel de Admin (ficha da equipa, do treinador, estatísticas, plantel, relatório) | `admin_panel_screen.dart` |
| Histórico de treinadores | `coach_history_screen.dart` |
| Entradas e saídas de atletas | `membership_history_screen.dart` |
| Comparação entre épocas | `season_comparison_screen.dart` |
| Registo de auditoria | `audit_log_screen.dart` |
| Navegação principal | `home_shell.dart` |

Editar perfil, editar contactos de emergência, editar/cancelar evento e
editar/eliminar publicação ou sondagem aparecem como diálogos dentro dos
ecrãs acima, não como ficheiros à parte.

## Como correr

Pré-requisito: [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.22+).

```bash
cd apps/mobile
flutter pub get
flutter run
```

Por omissão, `ApiService` aponta para `http://10.0.2.2:3000` (alias do
`localhost` da máquina anfitriã, usado pelo emulador Android). Para
dispositivo físico ou simulador iOS, edita o `baseUrl` em
`lib/services/api_service.dart` para o IP da máquina que corre a API.

Se a API não estiver acessível, alguns métodos têm *fallback* automático
para dados mockados, para a app continuar navegável mesmo sem ligação —
mas com o servidor a correr (ver README principal), toda a aplicação
funciona contra dados reais.

## Estrutura

```
lib/
├─ screens/    # um ficheiro por ecrã
├─ widgets/    # componentes reutilizáveis entre ecrãs
├─ models/     # representação dos dados vindos da API
├─ services/   # ApiService (HTTP) e ChatService (Socket.io)
└─ theme/      # sistema de design — tema escuro "volt"
```

Gestão de estado com `provider`: a classe `AppState` mantém a sessão do
utilizador autenticado e expõe os serviços de dados ao resto da
aplicação.

### Tipografia (Google Fonts)

A app usa `google_fonts` (Manrope + Inter). Estas fontes são descarregadas
automaticamente na primeira vez que a app corre — é preciso ligação à
internet nesse momento (normal em *debug*; builds de produção devem
confirmar que a permissão `INTERNET` está no `AndroidManifest.xml`, o que
já acontece por omissão em builds de *debug*).

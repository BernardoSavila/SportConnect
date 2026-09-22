# Notificações push (Firebase Cloud Messaging)

Este documento esclarece exatamente o que já está feito e o que falta
para as notificações push funcionarem de verdade — e, mais importante,
esclarece o que **não** depende do Firebase.

## Importante: o tempo real da app não usa Firebase

O chat de equipa e as mensagens privadas **já funcionam em tempo real**,
através de **Socket.io**, integrado diretamente sobre o servidor Express
(`apps/server/src/realtime.ts`). Isto não depende do Firebase Firestore
nem de nenhum outro serviço externo — é a própria API que mantém a ligação
persistente com a app e entrega as mensagens instantaneamente.

O Firebase só entra numa área bem mais limitada: **notificações push
nativas** (o aviso que aparece mesmo com a app fechada ou em segundo
plano) — que é uma funcionalidade diferente de o chat funcionar em tempo
real com a app aberta.

## O que já está implementado

- Modelo `DeviceToken` (`apps/server/src/models/DeviceToken.ts`) — guarda
  o token de cada dispositivo, associado ao utilizador e à plataforma
  (`android`/`ios`).
- `POST /devices/register-token` — a app pode registar o seu token assim
  que o utilizador autentica.

```ts
// apps/server/src/controllers/deviceController.ts
// Stub: apenas guarda o token. O envio real de notificações via
// Firebase Cloud Messaging fica documentado aqui para o Projeto 2.
```

## O que falta para o envio real funcionar

O envio real de notificações via Firebase Cloud Messaging exige um
projeto Firebase próprio — não pode ser gerado neste repositório, porque
depende de uma conta e de credenciais que só quem for publicar a app tem:

1. Criar um projeto em [console.firebase.google.com](https://console.firebase.google.com)
2. Adicionar uma app Android/iOS e descarregar `google-services.json` /
   `GoogleService-Info.plist`
3. Instalar `firebase-admin` no servidor e `firebase_messaging` no Flutter
4. No servidor, substituir o *stub* em `deviceController.ts` por uma
   chamada real ao Firebase Admin SDK, disparada quando um evento, aviso
   ou sondagem relevante é criado
5. No Flutter, pedir permissão de notificações e subscrever o `FCM token`
   assim que a app arranca, chamando `POST /devices/register-token`

## Onde isto está no roadmap

Ver a secção **Roadmap** do [`README.md`](../README.md) principal —
as notificações push estão identificadas como trabalho futuro, tal como
consta no Capítulo 8 (Conclusões e Trabalho Futuro) do relatório do
projeto.

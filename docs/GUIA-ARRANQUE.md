# SportConnect — Guia de Arranque para Novos Colaboradores

Este guia parte do zero: um Mac sem nada instalado, até teres a app a
correr no teu computador. Segue os passos por ordem — cada um depende do
anterior.

---

## 1. Instalar as ferramentas necessárias

### Homebrew (gestor de pacotes do Mac — se ainda não tiveres)
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Docker Desktop
```bash
brew install --cask docker
```
Depois de instalado, **abre a app Docker uma vez** (Launchpad ou Spotlight) e espera até o ícone da baleia 🐳 na barra de menu ficar estável.

### Node.js
```bash
brew install node
```
Confirma:
```bash
node --version   # deve mostrar v20 ou mais recente
```

### Flutter
```bash
brew install --cask flutter
```
Confirma:
```bash
flutter --version
```

### Android Studio (para o emulador Android)
```bash
brew install --cask android-studio
```
Abre o Android Studio uma vez para completar a instalação inicial (aceitar termos, instalar componentes do SDK).

Depois, cria um emulador:
1. Android Studio → **More Actions → Virtual Device Manager**
2. **Create Virtual Device** → escolhe um telemóvel (ex: Pixel 7) → **Next**
3. Escolhe uma imagem do sistema (ex: API 34/35) → faz download se pedir → **Next → Finish**

### Confirma que está tudo bem instalado
```bash
flutter doctor
```
Não te preocupes se aparecerem avisos sobre Xcode/iOS — só precisas do Android para já. Se pedir para aceitar licenças Android:
```bash
flutter doctor --android-licenses
```
(escreve `y` a cada pergunta)

---

## 2. Obter o projeto

Descomprime o ficheiro `SportConnect.zip` que recebeste, por exemplo no Desktop:
```bash
cd ~/Desktop
unzip SportConnect.zip
cd SportConnect
```

Confirma que tens a estrutura esperada:
```bash
ls
```
Deve mostrar: `apps  docs  infra  README.md  .github  .gitignore`

---

## 3. Arrancar a base de dados

```bash
cd infra
docker compose up -d
```

A primeira vez demora um pouco (descarrega as imagens do MySQL e do Adminer). Confirma que arrancou bem:
```bash
docker compose ps
```
Ambos os containers devem mostrar `Up` (o `db` deve mostrar `healthy` ao fim de uns segundos).

**Se aparecer erro de porta ocupada** (`address already in use`), outra coisa no teu Mac já usa a porta 3306 ou 8080. A forma mais simples: edita `infra/docker-compose.yml`, muda `'3306:3306'` para `'3307:3306'` (e/ou `'8080:8080'` para `'8081:8080'`), e depois lembra-te de mudar `DB_PORT` no `.env` do servidor (passo seguinte) para bater certo.

---

## 4. Arrancar o servidor (API)

Num **novo terminal** (deixa o Docker a correr no anterior):

```bash
cd ~/Desktop/SportConnect/apps/server
cp .env.example .env
npm install
npm run seed
npm run dev
```

Deves ver:
```
Ligação à base de dados estabelecida.
SportConnect API a correr em http://localhost:3000
Chat em tempo real (Socket.io) ativo no mesmo endereço.
Verificação automática de lembretes agendada (de hora a hora).
```

**Deixa este terminal aberto e a correr** durante todo o desenvolvimento — se o fechares, a API desliga-se.

Confirma que está a responder (noutro terminal, sem fechar o anterior):
```bash
curl http://localhost:3000/health
```
Deve devolver `{"status":"ok"}`.

### Correr os testes automatizados (opcional, mas recomendado)
```bash
npm test
```
Deve mostrar todos os testes a passar (não precisa do Docker a correr — usa uma base de dados à parte, só para testes).

---

## 5. Arrancar a app mobile

Num **terceiro terminal**, com o emulador Android já aberto:

```bash
cd ~/Desktop/SportConnect/apps/mobile
flutter create .
flutter pub get
flutter run
```

O `flutter create .` só é preciso a primeira vez (gera as pastas `android/`, `ios/`, etc., que não vêm no zip). Se pedir para escolher um dispositivo, escolhe o emulador Android.

Para uma execução mais fluida (sem o peso do modo debug):
```bash
flutter run --release
```

---

## 6. Credenciais de teste

Já criadas pelo `npm run seed`:

| Email | Password | Papel |
|---|---|---|
| `coach@sportconnect.pt` | `Password123` | Treinador |
| `atleta1@sportconnect.pt` | `Password123` | Atleta |
| `atleta2@sportconnect.pt` | `Password123` | Atleta |

Código de convite da equipa (para testar o registo): `SPORT1`

**Nota:** o campo de email no ecrã de login vem pré-preenchido com `atleta1@sportconnect.pt` — se quiseres entrar como treinador, apaga esse valor e escreve `coach@sportconnect.pt`.

---

## 7. Ver a base de dados visualmente (opcional)

Abre **http://localhost:8080** (ou 8081, se mudaste a porta) — é o Adminer:
- Sistema: MySQL
- Servidor: `db`
- Utilizador: `root`
- Password: `root`
- Base de dados: `sportconnect`

---

## 8. Rotina do dia-a-dia (depois do primeiro arranque)

De cada vez que quiseres trabalhar no projeto, só precisas de 3 terminais:

```bash
# Terminal 1 — base de dados
cd ~/Desktop/SportConnect/infra && docker compose up -d

# Terminal 2 — servidor
cd ~/Desktop/SportConnect/apps/server && npm run dev

# Terminal 3 — app mobile
cd ~/Desktop/SportConnect/apps/mobile && flutter run
```

Não precisas de repetir `npm install`, `flutter pub get`, `flutter create .` nem `npm run seed` todos os dias — só na primeira vez, ou depois de receberes uma atualização do projeto com novas dependências.

---

## 9. Problemas comuns

**"No supported devices connected" / faltam pastas android/ios**
Corre `flutter create .` dentro de `apps/mobile` — o zip do projeto não inclui essas pastas.

**Erro `EADDRINUSE` ao correr `npm run dev`**
Já tens outro processo a usar a porta 3000. Descobre qual com `lsof -i :3000` e termina-o com `kill -9 <PID>`.

**A app mostra sempre "Bernardo Costa" ao fazer login, mesmo com outras credenciais**
Sinal de que a app não está a conseguir chegar à API (servidor não está a correr, ou está numa porta diferente da esperada). Confirma o Terminal 2 e faz `curl http://localhost:3000/health`.

**Mudaste alguma coisa no schema da base de dados e a app dá erros estranhos**
Reinicia a base de dados do zero:
```bash
cd infra
docker compose down -v
docker compose up -d
cd ../apps/server
npm run seed
```

**`git clone`/partilha via Git em vez de zip**
Se decidirem usar um repositório Git em vez de zips, o `.gitignore` já está preparado para excluir `node_modules/`, `.env`, `dist/` e as pastas geradas do Flutter — o colega só precisa de repetir os passos 3-5 deste guia depois do `git clone`.

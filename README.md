# ReceptApp

ReceptApp är hushållets egen receptsamling och matplanerare. Du sparar recept genom att
klistra in en länk, fotografera en kokbokssida, ladda upp en PDF eller peka på en video –
appen läser ut ingredienser, steg och näringsvärden och lägger recepten i ett bibliotek du
kan söka i. Veckoplaneraren fyller sedan veckan med mat familjen faktiskt tycker om: den
tar hänsyn till allergier och ogillanden, till betygen var och en satt, till vad ni redan
åt förra veckan och till hur många portioner varje person äter.

Inköpslistan slår samman veckans recept till en lista, drar av det som redan står i
skafferiet och sorterar varorna efter avdelning i butiken. Skafferiet fyller du på genom
att skanna streckkoder med telefonen. Matdagboken visar kalorier och makron mot varje
persons mål – och det du planerat att äta syns bredvid det du faktiskt åt. Enskilda recept
kan delas med en länk till någon utanför hushållet. Du loggar in med passkey (fingeravtryck
eller ansikte), appen installeras på hemskärmen som en vanlig app och **all data ligger på
din egen server** – ingen molntjänst, ingen prenumeration, ingenting som skickas vidare.

Handboken för den som ska använda appen finns i **[MANUAL.md](MANUAL.md)**. Det här
dokumentet handlar om att installera och driva den.

- [Kom igång](#kom-igång) · [Nå appen utanför hemmet](#nå-appen-utanför-hemmet) ·
  [Uppdatera](#uppdatera) · [Backup och återställning](#backup-och-återställning) ·
  [Avinstallera](#avinstallera) · [Säkerhet](#säkerhet) ·
  [Inställningar i `.env`](#inställningar-i-env) · [Om något går fel](#om-något-går-fel)

## Kom igång

### Förutsättningar

| | |
| --- | --- |
| En maskin som står på | Linux eller macOS med **Docker Engine och Compose v2** (`docker compose version` ska svara). En NAS eller en Raspberry Pi 5 går bra – imagen finns för både amd64 och arm64. Windows fungerar via WSL2. |
| Minne och disk | Cirka 1 GB ledigt RAM med inbyggd databas. Ett par GB disk; det är bilderna i receptsamlingen som växer. |
| Rättigheter | En användare som får prata med docker (`docker info` ska svara). Installationsskriptet vägrar köra som root. |
| Namn och HTTPS | Vill du använda kameran (streckkoder, foto-import), passkeys eller installera appen på hemskärmen krävs **HTTPS** – alltså ett värdnamn och ett certifikat. [Nå appen utanför hemmet](#nå-appen-utanför-hemmet) visar tre sätt att få det gratis, varav ett (Tailscale) inte kräver någon egen domän. |
| Nät | Utgående trafik för att hämta imagen och Livsmedelsverkets näringsdata. |

### Installera med skriptet

Kör det här på servern, som din vanliga användare (inte root):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/install.sh)"
```

Formen `sh -c "$(curl …)"` är viktig: `curl … | sh` kan inte ställa frågor, eftersom
skriptet då själv ligger i standard in. Vill du läsa skriptet först (klokt) hämtar du det
med `curl -fsSL …/install.sh -o install.sh`, läser, och kör `sh install.sh`.

Skriptet frågar fem saker:

| # | Fråga | Standard | Varför |
| --- | --- | --- | --- |
| 1 | Adress (`PUBLIC_URL`) | `http://<värdnamn>:8090` | Det hushållet skriver i webbläsaren. Styr CSRF-kontroll, säkra kakor och passkeys. |
| 2 | Port på värden | `8090` | Porten appen nås på. Inne i containern är det alltid 8080. |
| 3 | Databas | Inbyggd MariaDB | Inbyggd = en `mariadb:11`-container här, filerna i `./db`. Egen = en MariaDB (≥ 10.6) du redan har; då frågas värd, port, databas, användare och lösenord, och anslutningen provas innan installationen fortsätter. |
| 4 | Claude API-nyckel | ingen | Valfri. Utan den fungerar import från länk, men inte från foto, PDF, Word eller inklistrad text. Kan läggas in senare. |
| 5 | Tidszon | `/etc/timezone`, annars `Europe/Stockholm` | Loggar, nattliga jobb och dagbokens dygn. Data lagras alltid i UTC. |

Sedan skriver det filerna, hämtar imagen, startar och väntar tills appen svarar. Efteråt
finns det här i installationskatalogen (standard `~/receptapp`):

```
docker-compose.yml   appen (och databasen, om den är inbyggd)
.env                 alla inställningar, rättigheter 600 – här står lösenorden
data/                media, uppladdningar, backuper och loggar (ägs av uid 65532)
db/                  databasfilerna, bara med inbyggd MariaDB
update.sh            uppdateringsskriptet
```

Alla svar kan ges som flaggor, och `--yes` hoppar över frågorna. Flaggor efter
`sh -c "$(curl …)"` skickas med ett `--` först:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/install.sh)" -- \
  --yes --dir /srv/receptapp --url https://recept.example.se --port 8090 --db internal
```

`./install.sh --help` listar alla flaggor. Avslutskoder: `0` klart, `1` förutsättning
saknas eller ett svar går inte att använda, `2` hämtningen eller starten misslyckades,
`3` appen kom inte igång i tid.

### Manuell installation

Går skriptet inte att köra – eller vill du hellre se allt själv – är det fyra filer och
tre kommandon. Skapa en katalog (`mkdir -p ~/receptapp && cd ~/receptapp`) och lägg
följande i den.

**`docker-compose.yml` med inbyggd databas** (rekommenderas):

```yaml
services:
  receptapp:
    image: ghcr.io/linkztream/receptapp:1.13.0
    restart: unless-stopped
    env_file: .env
    ports:
      - "8090:8080"
    volumes:
      - ./data:/data
    depends_on:
      db:
        condition: service_healthy

  db:
    image: mariadb:11
    restart: unless-stopped
    command: --character-set-server=utf8mb4 --collation-server=utf8mb4_swedish_ci
    environment:
      MARIADB_ROOT_PASSWORD: ${DB_ROOT_PASSWORD}
      MARIADB_DATABASE: recept
      MARIADB_USER: recept
      MARIADB_PASSWORD: ${DB_PASSWORD}
      MARIADB_AUTO_UPGRADE: "1"
      TZ: ${TZ:-Europe/Stockholm}
    volumes:
      - ./db:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 30s
```

Ingen hälsokoll behövs för appen: den ligger i imagen (`/receptapp -healthcheck`).
Databasen har ingen publicerad port – bara appen når den.

**`docker-compose.yml` mot en egen MariaDB** (≥ 10.6). Skapa databasen först:

```sql
CREATE DATABASE recept CHARACTER SET utf8mb4 COLLATE utf8mb4_swedish_ci;
CREATE USER 'recept'@'%' IDENTIFIED BY 'byt-mig';
GRANT ALL ON recept.* TO 'recept'@'%';
```

```yaml
services:
  receptapp:
    image: ghcr.io/linkztream/receptapp:1.13.0
    restart: unless-stopped
    env_file: .env
    ports:
      - "8090:8080"
    volumes:
      - ./data:/data
    # Ligger databasen på samma maskin som Docker, men inte i en container, nås den inte
    # som "localhost" härifrån – containern har sitt eget nät. Använd maskinens
    # LAN-adress, eller raderna nedan plus host.docker.internal i DB_DSN.
    #extra_hosts:
    #  - "host.docker.internal:host-gateway"
```

**`.env`** – de två första raderna är de enda som måste stämma:

```sh
# Databas. Inbyggd databas: värden är "db". Egen: värdnamn eller ip, aldrig "localhost".
DB_DSN=recept:byt-mig@tcp(db:3306)/recept?parseTime=true&charset=utf8mb4&collation=utf8mb4_swedish_ci&loc=UTC&multiStatements=true
# Minst 16 tecken, slumpade: openssl rand -hex 32
SESSION_SECRET=byt-mig-till-32-slumpade-byte
# Lösenorden den inbyggda databasen startas med (behövs inte med en egen databas).
DB_ROOT_PASSWORD=byt-mig
DB_PASSWORD=byt-mig

# Appens adress utåt. Ändra när du satt HTTPS framför.
PUBLIC_URL=http://receptservern:8090
LISTEN_ADDR=:8080
DATA_DIR=/data
TZ=Europe/Stockholm
AUTO_BACKUP=1
DB_WAIT_SECONDS=60

# Valfritt: Claude-nyckel för import från foto, PDF, Word och text.
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-opus-5

# Zoner och proxy – se "Nå appen utanför hemmet".
TRUSTED_PROXIES=
LAN_CIDRS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7,127.0.0.0/8,::1/128
AUTH_ZONES=off

# Uppdateringskoll (en gång per dygn, skickar bara en User-Agent med versionen).
UPDATE_CHECK=1
UPDATE_CHECK_URL=https://raw.githubusercontent.com/linkztream/receptapp-install/main/latest.json

# Valfritt: inköpslistan till en todo-lista i Home Assistant (slås på i Admin).
HA_URL=
HA_TOKEN=
HA_TODO_ENTITY=todo.inkopslista

# Valfritt: butiks-id hos ICA Handla för produktdata. Tomt = av.
ICA_STORE_ID=

LOG_LEVEL=info
LOG_MAX_SIZE_MB=20
LOG_MAX_FILES=10
```

Slumpa hemligheten och sätt rättigheterna:

```sh
openssl rand -hex 32          # klistra in som SESSION_SECRET
chmod 600 .env
```

Katalogen för bilder, backuper och loggar måste vara skrivbar för **uid 65532** – imagen
är distroless och kör som `nonroot`:

```sh
mkdir -p data
sudo chown 65532:65532 data
```

Starta:

```sh
docker compose up -d
docker compose logs -f          # Ctrl+C när det står "listening"
```

Migrationer och referensdata (enheter, allergener, ingredienser med vikttabell) körs
automatiskt vid varje start. Kontrollera att appen mår bra:

```sh
curl -s localhost:8090/healthz     # {"status":"ok",…}
```

### Första start

Öppna adressen i webbläsaren. **Första besöket äger installationen**: sidan som möter dig
skapar administratörskontot (namn, e-post eller användarnamn, lösenord). Gör det direkt –
tills det är gjort kan vem som helst som når adressen bli admin.

Sedan, i den ordningen:

1. **Profiler.** En profil per person som äter: allergier (tre nivåer), ogillanden, kost,
   portionsfaktor och eventuella kalori- och makromål. Planeraren, inköpslistan och
   dagboken utgår från profilerna, så det är värt tio minuter här.
2. **Användare.** Var och en som ska logga in får ett eget konto. En användare kan äga
   flera profiler (barnen), och profilspärren styr vem som får ändra vad.
3. **Passkey.** Registrera en passkey på din telefon medan du står hemma. Det är det som
   gör det bekvämt – och det enda som släpps in utifrån om du senare stänger dörren med
   `AUTH_ZONES=enforce`.
4. **Admin → Server** (från version 1.13) samlar integrationerna: Claude-nyckeln för
   import från foto, PDF, Word och text, Home Assistant, ICA-butiken, uppdateringskollen och
   den automatiska backupen. Utan Claude-nyckel fungerar import från länk, men inte från
   foto, PDF, Word eller inklistrad text. Står värdet redan i `.env` (till exempel
   `ANTHROPIC_API_KEY`) låser sidan fältet och visar *styrs av `.env`* – filen vinner alltid.
   Adressen, databasen och zoninställningarna ändras bara i `.env`, med omstart.
5. Livsmedelsverkets databas hämtas i bakgrunden första gången (cirka sex minuter) och
   uppdateras sedan månadsvis. Näringsvärden kan vara ofullständiga tills den är klar.

Allt det praktiska – lägga in recept, planera veckan, handla, skanna, dagboken – står i
**[MANUAL.md](MANUAL.md)**.

## Nå appen utanför hemmet

Appen pratar HTTP på sin port. Det räcker hemma, men **kameran, passkeys och att installera
appen på hemskärmen kräver HTTPS** (bara `localhost` räknas som säkert utan certifikat).
Här är tre vägar dit. Välj en.

Efter varje ändring: sätt `PUBLIC_URL` i `.env` till den nya adressen och kör
`docker compose up -d`. Byter du värdnamn måste alla passkeys registreras om – namnet är
en del av nyckelns identitet.

### 1. Tailscale – enklast, inget eget domännamn

[Tailscale](https://tailscale.com) bygger ett privat nät mellan dina enheter. Gratis för
ett hushåll, ingen port behöver öppnas i brandväggen.

1. Installera Tailscale på servern (`curl -fsSL https://tailscale.com/install.sh | sh` och
   `sudo tailscale up`) och appen på telefonerna. Logga in med samma konto.
2. Slå på **MagicDNS** och **HTTPS Certificates** i Tailscales adminpanel.
3. Låt Tailscale ta hand om certifikatet:

   ```sh
   sudo tailscale serve --bg --https=443 http://127.0.0.1:8090
   tailscale serve status
   ```

   Appen svarar nu på `https://<maskinnamn>.<tailnet>.ts.net` med ett riktigt
   certifikat – kamera och passkeys fungerar.
4. Sätt `PUBLIC_URL=https://<maskinnamn>.<tailnet>.ts.net` i `.env` och kör
   `docker compose up -d`.

`tailscale serve` pratar med appen över loopback, så appen ser `127.0.0.1` som motpart –
alltså hemnätet. Vill du att appen ska se vilken enhet besökaren kommer från, sätt
`TRUSTED_PROXIES=127.0.0.1/32`; då läses `X-Forwarded-For` (kontrollera under
**Admin → Inloggningar** att adressen ser rätt ut).

Går du i stället direkt på `http://<maskinnamn>:8090` över tailnetet kommer trafiken från
Tailscales adressrymd **100.64.0.0/10**. Vill du att sådan trafik ska räknas som hemma –
så att lösenordsinloggning fungerar i mobilen borta – lägg till den i `LAN_CIDRS`:

```
LAN_CIDRS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,100.64.0.0/10,fc00::/7,127.0.0.0/8,::1/128
```

`tailscale funnel` lägger tjänsten öppet på internet. Gör inte det om du inte vill precis
det.

### 2. Cloudflare Tunnel – eget domännamn, ingen öppen port

Har du en domän hos Cloudflare kan en tunnel ge HTTPS utan att någon port öppnas.

1. I Cloudflare Zero Trust: **Networks → Tunnels → Create a tunnel** (typ *Cloudflared*).
   Kopiera tunnelns token.
2. Lägg till en tjänst i `docker-compose.yml`:

   ```yaml
     cloudflared:
       image: cloudflare/cloudflared:latest
       restart: unless-stopped
       command: tunnel --no-autoupdate run
       environment:
         TUNNEL_TOKEN: ${TUNNEL_TOKEN}
       depends_on:
         - receptapp
   ```

   och `TUNNEL_TOKEN=…` i `.env`. Nu behöver appen ingen publicerad port alls – ta bort
   `ports:` om bara tunneln ska nå den.
3. I tunnelns **Public hostname**: `recept.example.se` → service `http://receptapp:8080`
   (tjänstnamnet i compose-filen, porten inne i containern).
4. I `.env`:

   ```
   PUBLIC_URL=https://recept.example.se
   TRUSTED_PROXIES=172.16.0.0/12
   ```

   `cloudflared` ligger på compose-nätet, som normalt får en adress i `172.16.0.0/12`.
   **Utan `TRUSTED_PROXIES` ser appen alla besökare som tunnelcontainern** – en privat
   adress, alltså "hemma". Sätt raden, och kontrollera under **Admin → Inloggningar** att
   din riktiga adress syns. Cloudflare skickar besökarens adress i `CF-Connecting-IP` och
   i `X-Forwarded-For`; appen läser `X-Forwarded-For`.
5. Med `AUTH_ZONES=enforce` räknas allt som kommer genom tunneln som internet: bara
   passkeys släpps in utifrån, och lösenord fungerar hemma. Registrera en passkey först.

Cloudflare har en gräns för hur stora uppladdningar som släpps igenom (100 MB på
gratisplanen) – gott och väl för foton och PDF:er.

### 3. Egen reverse proxy

Har du redan en proxy, eller en router som kan vidarebefordra 443, gör den jobbet. Den
måste skicka klientens adress i `X-Forwarded-For`, annars ser appen alla som proxyn.

**Caddy** (fixar certifikat automatiskt och sätter `X-Forwarded-For` själv):

```caddyfile
recept.example.se {
	reverse_proxy 127.0.0.1:8090
}
```

**nginx:** `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;` i `location /`
(plus `client_max_body_size 32m;` för foto- och PDF-import).

**HAProxy:** `option forwardfor` i frontend eller backend.

Sätt sedan proxyns adress – inte appens – i `.env`:

```
PUBLIC_URL=https://recept.example.se
TRUSTED_PROXIES=192.168.1.1/32
```

### Zonmodellen: lösenord hemma, passkey utifrån

1. Appen delar in trafiken i **hemnät** och **internet**. `LAN_CIDRS` säger vad som är
   hemma (standard: alla privata adresser plus loopback).
2. Klientens adress tas ur `X-Forwarded-For` **bara** när den direkta motparten står i
   `TRUSTED_PROXIES`. Annars används motparten själv, och headern ignoreras.
3. En betrodd proxy som inte skickar `X-Forwarded-For` räknas som internet – fail-closed.
4. `AUTH_ZONES` styr vad zonen används till: `off` (standard) räknar bara ut den för
   loggen, `log` loggar vad som skulle ha blockerats, `enforce` tillåter lösenord,
   API-nycklar, admin och installation bara hemifrån – utifrån krävs passkey.
5. Kontrollera **Admin → Inloggningar** innan du sätter `enforce`: kortet "Din anslutning"
   ska visa din riktiga adress och rätt zon. Registrera dessutom minst en passkey, annars
   kommer ingen in utifrån. Delningslänkar (`/dela/…`) påverkas aldrig av zonpolicyn.

Detaljerna står i avsnitten **"Zoner och inloggning"** och **"Passkeys"** i appens egen
README (den privata), och passkeys från användarens sida i [MANUAL.md](MANUAL.md).

## Uppdatera

```sh
cd ~/receptapp
./update.sh
```

Skriptet tar en backup (`data/backups/pre-update-<tidsstämpel>.zip`), läser senaste
versionen ur `latest.json` här i repot, byter versionen på image-raden i
`docker-compose.yml`, hämtar imagen, startar om och väntar tills `/healthz` svarar. Det
skriver ut `gammal version → ny version` och migreringsnumret. Misslyckas hämtningen
läggs den gamla versionen tillbaka i `docker-compose.yml`.

Appen säger också till själv: en gång per dygn hämtas `latest.json`, och en ny version syns
som en notis under **Admin → Systemet**. Ingenting annat än en `User-Agent` med
versionsnumret skickas. `UPDATE_CHECK=0` i `.env` stänger av kollen.

En bestämd version, även bakåt:

```sh
TARGET=1.14.0 ./update.sh
TARGET=latest ./update.sh
```

**Databasmigrationer rullas inte tillbaka.** En äldre binär mot ett nyare schema kan bete
sig oväntat. Den säkra vägen tillbaka är backupen som togs före uppdateringen:
**Admin → Systemet → Importera backup** med `data/backups/pre-update-<tidsstämpel>.zip`.

Installerade du för hand uppdaterar du genom att byta versionen på image-raden och köra
`docker compose pull && docker compose up -d`. Ta en backup först (**Admin → Systemet →
Backup**).

## Backup och återställning

- `AUTO_BACKUP=1` (standard) lägger en zip i `data/backups` varje natt kl 03:30.
- **Admin → Systemet → Backup** hämtar en zip direkt, och **Importera backup** läser in
  en. Zipen innehåller databasen och alla bilder.
- `update.sh` tar alltid en backup före uppdateringen.
- Kopiera zipparna någon annanstans – en backup på samma disk som databasen är ingen
  backup. Hela katalogen (`.env`, `data/`, `db/`) går också att kopiera, men stoppa
  containrarna först: `docker compose down`.

## Avinstallera

```sh
cd ~/receptapp
docker compose down          # stoppar appen (och den inbyggda databasen)
```

Allt som är ditt ligger kvar i katalogen: `.env`, `data/` (bilder, backuper, loggar) och
`db/` (databasen). Ta en backup först om du vill ha kvar recepten, och radera sedan
katalogen. Images städas med `docker image rm ghcr.io/linkztream/receptapp:<version>`
eller `docker image prune`.

## Säkerhet

- **Ingenting är öppet utan inloggning** utom delningslänkar: `/dela/<token>` visar ett
  enskilt recept för den som har länken (32 slumpade byte), och länken kan återkallas.
  Sidorna är `noindex, nofollow` och hastighetsbegränsade. Resten av appen kräver
  inloggning.
- **Passkeys** (fingeravtryck, ansikte, PIN eller lösenordshanterare) kan användas i
  stället för lösenord och är det enda som släpps in utifrån när `AUTH_ZONES=enforce`.
  Kräver HTTPS, och `PUBLIC_URL`:s värdnamn är nyckelns identitet – byter du domän måste
  alla passkeys registreras om.
- **`.env` har rättigheter 600** och innehåller databaslösenord, `SESSION_SECRET` (slumpad
  per installation) och en eventuell Claude-nyckel. Lägg den inte i git.
- **Inget skickas någonstans** utan att du ber om det. Claude-nyckeln används bara när du
  importerar från foto, PDF, Word eller text; uppdateringskollen skickar bara en
  `User-Agent` med versionen. Ingen telemetri – all data ligger på din maskin.
- **Publicera inte porten rakt ut på internet utan HTTPS.** Använd Tailscale, en tunnel
  eller en egen proxy, och överväg `AUTH_ZONES=enforce`.
- Den inbyggda databasen har ingen publicerad port. Håll det så.

## Inställningar i `.env`

De vanligaste (appens egen README har hela listan):

| Variabel | Standard från installationen | Betydelse |
| --- | --- | --- |
| `DB_DSN` | ifylld | MariaDB-anslutning, `användare:lösen@tcp(värd:3306)/databas?parseTime=true&…`. |
| `SESSION_SECRET` | slumpad | Nyckeln sessionskakorna signeras med. Byter du den loggas alla ut. |
| `PUBLIC_URL` | ditt svar | Appens adress utåt. Ändra den när du satt HTTPS framför. |
| `DB_WAIT_SECONDS` | `60` | Hur länge appen väntar på databasen vid start. |
| `TZ` | ditt svar | Tidszon för loggar och nattliga jobb. |
| `ANTHROPIC_API_KEY` | tom eller ditt svar | Claude-nyckel för import från foto, PDF, Word och text. |
| `TRUSTED_PROXIES` | tom | Proxyer vars `X-Forwarded-For` får tros. Tomt = lita på ingen. |
| `LAN_CIDRS` | privata nät + loopback | Vad som räknas som hemnätet. |
| `AUTH_ZONES` | `off` | `off`, `log` eller `enforce`. Se zonmodellen ovan. |
| `AUTO_BACKUP` | `1` | Daglig backup-zip under `data/backups` kl 03:30. |
| `UPDATE_CHECK` / `UPDATE_CHECK_URL` | `1` / `latest.json` här | Daglig koll efter nyare version. |
| `HA_URL` / `HA_TOKEN` / `HA_TODO_ENTITY` | tomma | Skickar inköpslistan till en todo-lista i Home Assistant. Slås på under Admin → Systemet. |
| `ICA_STORE_ID` | tom (av) | Butiks-id hos ICA Handla för produktdata; pris och sortiment är butiksspecifika. |
| `LOG_LEVEL` | `info` | `debug`, `info`, `warn` eller `error`. |

Efter en ändring: `docker compose up -d`.

## Om något går fel

```sh
cd ~/receptapp
docker compose ps            # kör containrarna, och är de "healthy"?
docker compose logs --tail 100
curl -s localhost:8090/healthz
```

- **Appen blir aldrig frisk.** Nästan alltid databasen: kontrollera `DB_DSN` i `.env`.
  Loggen säger vad som gick fel. Samma rader finns under **Admin → Senaste loggrader** när
  appen kommit upp.
- **Porten är upptagen** (`address already in use`): välj en annan port i
  `docker-compose.yml` och i `PUBLIC_URL`, eller stoppa det som redan lyssnar.
- **Permission denied i loggen.** `data/` är inte skrivbar för uid 65532:
  `sudo chown -R 65532:65532 ~/receptapp/data`.
- **Kameran startar inte** och passkeys går inte att registrera: adressen är HTTP. Bara
  `localhost` räknas som säker utan certifikat – se [Nå appen utanför
  hemmet](#nå-appen-utanför-hemmet).
- **Import från foto eller PDF säger att nyckel saknas:** lägg in Claude-nyckeln under
  **Admin → Server** (från 1.13) eller som `ANTHROPIC_API_KEY` i `.env` följt av
  `docker compose up -d`.
- **Alla besökare ser ut att komma hemifrån** (eller alla utifrån): `TRUSTED_PROXIES`
  stämmer inte med din proxy. Se zonmodellen ovan och **Admin → Inloggningar**.

Första starten tar längre tid än man tror: migrationer, referensdata och (i bakgrunden)
Livsmedelsverkets databas. Installationsskriptet väntar upp till två minuter på
`/healthz`.

## Källkod och licens

Appens källkod är privat tills vidare; det här repot innehåller installationen och den
publika imagen `ghcr.io/linkztream/receptapp`. Licensen för installationsskripten är inte
bestämd än – ägaren lägger till en `LICENSE`-fil när den är det. Tills dess: fråga innan du
återanvänder något härifrån.

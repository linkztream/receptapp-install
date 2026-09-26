# ReceptApp – installera en egen instans

ReceptApp är en receptdatabas med veckoplanering, inköpslista, streckkodsskanning,
personprofiler (kalorier, makromål, allergier, ogillanden, kost) och receptimport från
länk, foto, PDF, Word och text, med näringsdata från Livsmedelsverket. Den körs som en
enda container mot MariaDB och fungerar som app (PWA) på både dator och mobil.

Det här repot innehåller bara installationen: ett skript, två compose-mallar och en
versionsfil. Appen hämtas som färdig image från GitHub Container Registry.

## Installera

Kör det här på servern, som din vanliga användare (inte root):

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/install.sh)"
```

Skriptet ställer fem frågor, skriver `docker-compose.yml` och `.env`, hämtar imagen,
startar appen och väntar tills den svarar. Sedan öppnar du adressen och skapar
admin-kontot – **första besöket äger installationen**, så gör det direkt.

Formen `sh -c "$(curl …)"` är viktig: `curl … | sh` kan inte ställa frågor, eftersom
skriptet då själv ligger i standard in.

Vill du läsa skriptet först (klokt):

```sh
curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/install.sh -o install.sh
less install.sh
sh install.sh
```

### Krav

| | |
| --- | --- |
| Operativsystem | Linux eller macOS. Windows fungerar via WSL2. |
| Docker | Docker Engine med Compose v2 – `docker compose version` ska svara. |
| Arkitektur | amd64 eller arm64 (Raspberry Pi 5 och ARM-servrar går bra). |
| Minne | 1 GB ledigt räcker med inbyggd databas. |
| Disk | Ett par GB. Bilderna i receptsamlingen är det som växer. |
| Rättigheter | En användare som får prata med docker (`docker info` ska svara). Skriptet vägrar köra som root. |
| Nät | Utgående trafik för att hämta images och Livsmedelsverkets data. |

### Utan frågor (automatiserat)

Alla svar kan ges som flaggor, och `--yes` hoppar över frågorna. Flaggor efter
`sh -c "$(curl …)"` skickas med ett `--` först:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/install.sh)" -- \
  --yes --dir /srv/receptapp --url https://recept.example.se --port 8090 --db internal
```

`./install.sh --help` listar alla flaggor: `--dir`, `--url`, `--port`, `--db`,
`--db-host`, `--db-port`, `--db-name`, `--db-user`, `--db-password`, `--anthropic-key`,
`--tz`, `--version`, `--yes`, `--reconfigure`, `--allow-root`, `--skip-start`.

Avslutskoder: `0` klart, `1` förutsättning saknas eller ett svar går inte att använda,
`2` hämtningen eller starten misslyckades, `3` appen kom inte igång i tid.

## Vad installationsprogrammet frågar

| # | Fråga | Standard | Varför |
| --- | --- | --- | --- |
| 1 | Adress (`PUBLIC_URL`) | `http://<värdnamn>:8090` | Det hushållet skriver i webbläsaren. Styr CSRF-kontroll, säkra kakor och passkeys. Kamera, passkeys och installation på hemskärmen kräver **HTTPS** – se *HTTPS och reverse proxy*. |
| 2 | Port på värden | `8090` | Porten appen nås på utifrån. Inne i containern är det alltid 8080. |
| 3 | Databas | Inbyggd MariaDB | Inbyggd = en `mariadb:11`-container här. Egen = en MariaDB (≥ 10.6) du redan har; då frågas värd, port, databas, användare och lösenord, och anslutningen provas innan installationen fortsätter. |
| 4 | Claude API-nyckel | ingen | Valfri. Utan den fungerar import från länk, men inte från foto, PDF, Word eller inklistrad text. Kan läggas in senare i `.env`. |
| 5 | Tidszon | `/etc/timezone`, annars `Europe/Stockholm` | Loggar, schemalagda jobb och måltidsloggens dygn. Data lagras alltid i UTC. |

Efteråt finns det här i installationskatalogen (standard `~/receptapp`):

```
docker-compose.yml   appen (och databasen, om den är inbyggd)
.env                 alla inställningar, rättigheter 600 – här står lösenorden
data/                media, uppladdningar, backuper och loggar (ägs av uid 65532)
db/                  databasfilerna, bara med inbyggd MariaDB
update.sh            uppdateringsskriptet
```

`data/` måste vara skrivbar för **uid 65532** – imagen är distroless och kör som
`nonroot`. Installationsskriptet sätter ägaren (`chown 65532:65532 data`, via `sudo` om
det behövs) och faller tillbaka på `chmod 777` med en varning om det inte går.

## Inbyggd eller egen MariaDB

**Inbyggd (rekommenderas).** Compose-filen startar `mariadb:11` vid sidan av appen, med
`utf8mb4_swedish_ci`, slumpade lösenord i `.env` och databasfilerna i `./db`. Databasen
har **ingen publicerad port** – bara appen kommer åt den, över det interna
compose-nätet. Appen startar först när databasens hälsokoll säger att den är uppe.

**Egen.** Har du redan en MariaDB (≥ 10.6) pekar du appen dit. Skapa databasen först:

```sql
CREATE DATABASE recept CHARACTER SET utf8mb4 COLLATE utf8mb4_swedish_ci;
CREATE USER 'recept'@'%' IDENTIFIED BY 'byt-mig';
GRANT ALL ON recept.* TO 'recept'@'%';
```

Installationsskriptet provar anslutningen med den officiella mariadb-klienten innan det
skriver något:

```sh
docker run --rm mariadb:11 mariadb --skip-ssl -h db.example.se -u recept recept -e 'SELECT 1'
```

Kör databasen på **samma maskin** som Docker, men inte i en container, går den inte att
nå som `localhost` – containern har sitt eget nät. Använd maskinens adress på LAN, eller
lägg till i `docker-compose.yml`:

```yaml
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

och skriv `host.docker.internal` i `DB_DSN`.

Migrationer och referensdata (enheter, allergener, ingredienser med vikttabell) körs
automatiskt varje gång appen startar, och Livsmedelsverkets databas hämtas i bakgrunden
första gången (cirka sex minuter).

## HTTPS och reverse proxy

Appen lyssnar på HTTP på den port du valde. Lägg en reverse proxy med certifikat framför
den – utan HTTPS fungerar inte kameran (streckkoder, foto-import), passkeys eller
installation på hemskärmen. Sätt `PUBLIC_URL` i `.env` till proxyns adress och kör
`docker compose up -d` efter ändringen.

Proxyn måste skicka klientens adress i `X-Forwarded-For`, och `TRUSTED_PROXIES` i `.env`
måste innehålla proxyns adress – annars ser appen alla besökare som proxyn, vilket bland
annat gör zonmodellen och hastighetsbegränsningarna verkningslösa.

**Caddy** (fixar certifikat själv):

```caddyfile
recept.example.se {
	reverse_proxy 127.0.0.1:8090
}
```

**nginx:**

```nginx
server {
	listen 443 ssl;
	server_name recept.example.se;
	ssl_certificate     /etc/letsencrypt/live/recept.example.se/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/recept.example.se/privkey.pem;
	client_max_body_size 32m;          # foto- och PDF-import

	location / {
		proxy_pass http://127.0.0.1:8090;
		proxy_set_header Host              $host;
		proxy_set_header X-Real-IP         $remote_addr;
		proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}
}
```

**HAProxy:**

```haproxy
frontend https
	bind :443 ssl crt /etc/ssl/recept.example.se.pem
	option forwardfor                  # skickar X-Forwarded-For
	default_backend receptapp

backend receptapp
	server app 192.168.1.10:8090 check
```

Sätt sedan i `.env` (proxyns adress, inte appens):

```
TRUSTED_PROXIES=192.168.1.1/32
```

Vill du att lösenordsinloggning bara ska fungera hemifrån och passkey krävas utifrån:
läs avsnitten **"Zoner och inloggning"** och **"Passkeys"** i appens egen README innan du
sätter `AUTH_ZONES=enforce`. Ordningen spelar roll – registrera minst en passkey och
kontrollera under **Admin → Inloggningar** att appen ser rätt klientadress först.

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

Appen själv säger också till: en gång per dygn hämtas `latest.json` och en ny version
syns som en notis under **Admin → Systemet**. Ingenting annat än en `User-Agent` med
versionsnumret skickas. `UPDATE_CHECK=0` i `.env` stänger av kollen.

En bestämd version, även bakåt:

```sh
TARGET=1.14.0 ./update.sh
TARGET=latest ./update.sh
```

**Databasmigrationer rullas inte tillbaka.** En äldre binär mot ett nyare schema kan bete
sig oväntat. Den säkra vägen tillbaka är backupen som togs före uppdateringen:
**Admin → Systemet → Importera backup** med `data/backups/pre-update-<tidsstämpel>.zip`.

## Backup och återställning

- `AUTO_BACKUP=1` (standard) lägger en zip i `data/backups` varje natt kl 03:30.
- **Admin → Systemet → Backup** hämtar en zip direkt, och **Importera backup** läser in
  en. Zipen innehåller databasen och alla bilder.
- `update.sh` tar alltid en backup före uppdateringen.
- Kopiera zipparna någon annanstans – en backup som ligger på samma disk som databasen är
  ingen backup. Hela katalogen (`.env`, `data/`, `db/`) kan också kopieras, men stoppa
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
  importerar ett recept från foto, PDF, Word eller text; uppdateringskollen skickar bara
  en `User-Agent` med versionen. Ingen telemetri, ingen molntjänst i övrigt – all data
  ligger på din maskin.
- **Publicera inte porten rakt ut på internet utan HTTPS.** Vill du åt appen hemifrån,
  sätt en reverse proxy med certifikat framför, och överväg `AUTH_ZONES=enforce`.
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
| `AUTH_ZONES` | `off` | `off`, `log` eller `enforce`. Se appens README. |
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
  Loggen säger vad som gick fel. Samma rader finns under **Admin → Senaste loggrader**
  när appen kommit upp.
- **Porten är upptagen** (`address already in use`): välj en annan port i
  `docker-compose.yml` och i `PUBLIC_URL`, eller stoppa det som redan lyssnar.
- **Permission denied i loggen.** `data/` är inte skrivbar för uid 65532:
  `sudo chown -R 65532:65532 ~/receptapp/data`.
- **Kameran startar inte** och passkeys går inte att registrera: adressen är HTTP. Bara
  `localhost` räknas som säker utan certifikat – allt annat kräver HTTPS.
- **Import från foto/PDF säger att nyckel saknas:** sätt `ANTHROPIC_API_KEY` i `.env` och
  kör `docker compose up -d`.

Första starten tar längre tid än man tror: migrationer, referensdata och (i bakgrunden)
Livsmedelsverkets databas. Installationsskriptet väntar upp till två minuter på
`/healthz`.

## Källkod och licens

Appens källkod är privat tills vidare; det här repot innehåller installationen och den
publika imagen `ghcr.io/linkztream/receptapp`. Licensen för installationsskripten är inte
bestämd än – ägaren lägger till en `LICENSE`-fil när den är det. Tills dess: fråga innan
du återanvänder något härifrån.

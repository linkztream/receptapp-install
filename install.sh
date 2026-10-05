#!/bin/sh
# ReceptApp – installera en egen instans på den här maskinen.
#
# Kör så här (då fungerar frågorna, till skillnad från "curl … | sh"):
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/install.sh)"
#
# eller, från en klon av installationsrepot: ./install.sh
#
# Skriptet frågar om adress, port, databas, Claude-nyckel och tidszon, skriver
# docker-compose.yml och .env, hämtar imagen från GitHub Container Registry och startar
# appen. Ingenting utanför installationskatalogen ändras (utöver att docker hämtar images).
#
# Flaggor – alla frågor kan besvaras i förväg:
#   --dir KATALOG          var appen ska installeras (standard ~/receptapp)
#   --project-name NAMN    compose-projektets namn (standard receptapp). Byt bara om namnet
#                          redan används av en annan installation på maskinen.
#   --url ADRESS           PUBLIC_URL, appens adress utåt
#   --port PORT            värdport (standard 8090)
#   --db internal|external inbyggd MariaDB eller en egen
#   --db-host VÄRD         \
#   --db-port PORT          |
#   --db-name NAMN          |  bara med --db external
#   --db-user ANVÄNDARE     |
#   --db-password LÖSEN    /
#   --anthropic-key NYCKEL Claude-nyckel för import från foto, PDF, Word och fritext
#   --tz ZON               tidszon (standard från /etc/timezone)
#   --version VERSION      imagetagg att låsa till (standard: senaste ur latest.json)
#   --yes                  fråga inget: använd flaggorna och standardvärdena
#   --reconfigure          skriv över en befintlig .env (den gamla sparas som .env.bak-…)
#   --allow-root           tillåt att skriptet körs som root
#   --skip-start           skriv filerna, men hämta och starta inte containrarna
#   -h, --help             den här hjälpen
#
# Avslutskoder: 0 klart, 1 förutsättning saknas eller ett svar går inte att använda,
# 2 hämtningen eller starten misslyckades, 3 appen kom inte igång i tid.

set -eu

# ---- konstanter -------------------------------------------------------------

REPO_RAW="https://raw.githubusercontent.com/linkztream/receptapp-install/main"
LATEST_JSON_URL="${LATEST_JSON_URL:-${REPO_RAW}/latest.json}"
# Används bara om latest.json inte går att hämta.
FALLBACK_VERSION=1.13.3
IMAGE="ghcr.io/linkztream/receptapp"
DEFAULT_PORT=8090
DEFAULT_PROJECT=receptapp
DEFAULT_DB_NAME=recept
DEFAULT_DB_USER=recept
# Samma standard som appen: alla privata nät + loopback räknas som hemnätet.
DEFAULT_LAN_CIDRS="10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,fc00::/7,127.0.0.0/8,::1/128"
MARIADB_IMAGE="mariadb:11"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"

# ---- svar och flaggor -------------------------------------------------------

DIR=""
PROJECT=""
PROJECT_OPT=""
PUBLIC_URL=""
PORT=""
DB_MODE=""
DB_HOST=""
DB_PORT=""
DB_NAME=""
DB_USER=""
DB_PASS=""
DB_ROOT_PASS=""
ANTHROPIC_KEY=""
TZ_ANSWER=""
VERSION=""
VERSION_OPT=""
ASSUME_YES=0
RECONFIGURE=0
ALLOW_ROOT=0
SKIP_START=0
SRC_DIR=""
WORKDIR=""

say() { printf '%s\n' "$*"; }
warn() { printf 'VARNING: %s\n' "$*" >&2; }
fail() { printf 'FEL: %s\n' "$*" >&2; }

# Restore terminal echo (a password may have been half typed) and remove the temp dir.
trap 'stty echo 2>/dev/null || true; [ -z "$WORKDIR" ] || rm -rf "$WORKDIR"' EXIT
trap 'printf "\nAvbrutet.\n" >&2; exit 1' INT

usage() {
	# Print the comment header (line 2 up to the first non-comment line).
	if [ -f "$0" ]; then
		awk 'NR > 1 { if ($0 !~ /^#/) exit; sub(/^# ?/, ""); print }' "$0"
	else
		say "Hjälpen finns i skriptets huvud: $REPO_RAW/install.sh"
	fi
}

need_value() {
	# need_value FLAGGA ANTAL_KVAR
	if [ "$2" -lt 2 ]; then
		fail "$1 behöver ett värde."
		exit 1
	fi
}

while [ $# -gt 0 ]; do
	case "$1" in
	--dir) need_value "$1" $#; DIR="$2"; shift 2 ;;
	--project-name) need_value "$1" $#; PROJECT_OPT="$2"; shift 2 ;;
	--url) need_value "$1" $#; PUBLIC_URL="$2"; shift 2 ;;
	--port) need_value "$1" $#; PORT="$2"; shift 2 ;;
	--db) need_value "$1" $#; DB_MODE="$2"; shift 2 ;;
	--db-host) need_value "$1" $#; DB_HOST="$2"; shift 2 ;;
	--db-port) need_value "$1" $#; DB_PORT="$2"; shift 2 ;;
	--db-name) need_value "$1" $#; DB_NAME="$2"; shift 2 ;;
	--db-user) need_value "$1" $#; DB_USER="$2"; shift 2 ;;
	--db-password) need_value "$1" $#; DB_PASS="$2"; shift 2 ;;
	--anthropic-key) need_value "$1" $#; ANTHROPIC_KEY="$2"; shift 2 ;;
	--tz) need_value "$1" $#; TZ_ANSWER="$2"; shift 2 ;;
	--version) need_value "$1" $#; VERSION_OPT="$2"; shift 2 ;;
	--yes | -y) ASSUME_YES=1; shift ;;
	--reconfigure) RECONFIGURE=1; shift ;;
	--allow-root) ALLOW_ROOT=1; shift ;;
	--skip-start) SKIP_START=1; shift ;;
	-h | --help) usage; exit 0 ;;
	*)
		fail "Okänd flagga: $1"
		say "'--help' visar vilka som finns."
		exit 1
		;;
	esac
done

# ---- hjälpare ---------------------------------------------------------------

ask() {
	# ask FRÅGA STANDARD -> svaret på stdout (frågan går till stderr)
	ask_default="$2"
	if [ "$ASSUME_YES" -eq 1 ]; then
		printf '%s\n' "$ask_default"
		return 0
	fi
	if [ -n "$ask_default" ]; then
		printf '%s [%s]: ' "$1" "$ask_default" >&2
	else
		printf '%s: ' "$1" >&2
	fi
	IFS= read -r ask_reply || ask_reply=""
	[ -n "$ask_reply" ] || ask_reply="$ask_default"
	printf '%s\n' "$ask_reply"
}

ask_secret() {
	# ask_secret FRÅGA -> svaret på stdout, utan att visas när det skrivs
	if [ "$ASSUME_YES" -eq 1 ]; then
		printf '\n'
		return 0
	fi
	printf '%s: ' "$1" >&2
	if stty -echo 2>/dev/null; then
		IFS= read -r secret_reply || secret_reply=""
		stty echo 2>/dev/null || true
		printf '\n' >&2
	else
		warn "kan inte stänga av ekot – det du skriver syns."
		IFS= read -r secret_reply || secret_reply=""
	fi
	printf '%s\n' "$secret_reply"
}

confirm() {
	# confirm FRÅGA -> 0 för ja (standard), 1 för nej
	if [ "$ASSUME_YES" -eq 1 ]; then
		return 0
	fi
	printf '%s [J/n]: ' "$1" >&2
	IFS= read -r confirm_reply || confirm_reply=""
	case "$confirm_reply" in
	[nN] | [nN][eE][jJ] | [nN][oO]) return 1 ;;
	*) return 0 ;;
	esac
}

rand_hex() {
	# rand_hex ANTAL_BYTE
	if command -v openssl >/dev/null 2>&1; then
		openssl rand -hex "$1"
	elif [ -r /dev/urandom ]; then
		od -An -tx1 -N "$1" /dev/urandom | tr -d ' \n'
		printf '\n'
	else
		return 1
	fi
}

is_number() {
	case "$1" in
	'' | *[!0-9]*) return 1 ;;
	*) return 0 ;;
	esac
}

is_port() {
	is_number "$1" || return 1
	[ "$1" -ge 1 ] && [ "$1" -le 65535 ]
}

# compose_project_config SKRIVER UT konfigurationsfilen som docker compose redan känner
# till för projektet $1, eller inget om projektet är okänt. "N/A" och relativa sökvägar
# skrivs ut som de är – anroparen får avgöra att de inte går att jämföra.
compose_project_config() {
	# docker compose ls -a listar även stoppade projekt. Varningar på stderr ignoreras.
	docker compose ls -a --format json 2>/dev/null |
		tr '}' '\n' |
		grep -E "\"Name\"[[:space:]]*:[[:space:]]*\"$1\"" |
		sed -n 's/.*"ConfigFiles"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
		head -n 1 |
		cut -d, -f1
}

# project_containers SKRIVER UT containrar som ser ut att tillhöra projektet $1, för det
# fall compose ls inte känner till projektet (containrar utan compose-etiketter).
project_containers() {
	{
		docker ps -a --filter "name=^/$1-" --format '{{.Names}}' 2>/dev/null || true
		docker ps -a --filter "label=com.docker.compose.project=$1" \
			--format '{{.Names}}' 2>/dev/null || true
	} | sort -u
}

# project_conflict SVARAR 0 när namnet $1 redan är taget av något annat än vår egen
# katalog. Förklaringen hamnar i CONFLICT_WHY.
CONFLICT_WHY=""
project_conflict() {
	CONFLICT_WHY=""
	conflict_cfg="$(compose_project_config "$1")"
	if [ -n "$conflict_cfg" ]; then
		case "$conflict_cfg" in
		"${DIR}/docker-compose.yml")
			# Det är vår egen installation.
			return 1
			;;
		/*)
			CONFLICT_WHY="projektet kör redan från $(dirname "$conflict_cfg")"
			return 0
			;;
		*)
			# "N/A" eller en relativ sökväg: går inte att jämföra, så vi vågar inte.
			CONFLICT_WHY="projektet finns redan (compose vet inte var: \"$conflict_cfg\")"
			return 0
			;;
		esac
	fi
	# Okänt för compose ls. Finns det ändå containrar med projektets namn tillhör de någon
	# annan – utom när vi redan äger katalogen (--reconfigure av en befintlig installation).
	conflict_ps="$(project_containers "$1")"
	if [ -n "$conflict_ps" ] && [ ! -f "${DIR}/docker-compose.yml" ]; then
		CONFLICT_WHY="containrar med det namnet finns redan: $(printf '%s' "$conflict_ps" | tr '\n' ' ')"
		return 0
	fi
	return 1
}

fetch() {
	# fetch RELATIV_SÖKVÄG -> filens innehåll på stdout. Tar den ur klonen om skriptet
	# kördes därifrån, annars från repot på GitHub.
	if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$1" ]; then
		cat "$SRC_DIR/$1"
	else
		curl -fsSL --max-time 30 "${REPO_RAW}/$1"
	fi
}

# ---- 1. förutsättningar -----------------------------------------------------

say "ReceptApp – installation"
say ""

if [ "$(id -u)" -eq 0 ] && [ "$ALLOW_ROOT" -eq 0 ]; then
	fail "Kör inte det här som root."
	say "Appen behöver inte root, och filerna i installationskatalogen ska ägas av dig."
	say "Kör som din vanliga användare (som är med i docker-gruppen), eller lägg till"
	say "--allow-root om du vet att du vill."
	exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
	fail "docker är inte installerat (eller ligger inte i PATH)."
	say "Installera Docker Engine med compose-pluginet: https://docs.docker.com/engine/install/"
	exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
	fail "'docker compose' saknas. Du har troligen bara gamla 'docker-compose'."
	say "Installera Docker Compose v2 (paketet docker-compose-plugin)."
	exit 1
fi
if ! docker info >/dev/null 2>&1; then
	fail "docker svarar inte. Är tjänsten igång, och får du prata med den?"
	say "Prova 'docker info'. Säger den 'permission denied' behöver din användare vara med"
	say "i docker-gruppen: sudo usermod -aG docker \"\$USER\" och logga in igen."
	exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
	fail "curl är inte installerat. Det behövs för att hämta mallar och läsa /healthz."
	exit 1
fi
if ! command -v openssl >/dev/null 2>&1 && [ ! -r /dev/urandom ]; then
	fail "Hittar ingen slumpkälla: varken openssl eller /dev/urandom."
	say "Installera openssl och kör igen – lösenord och SESSION_SECRET måste vara slumpade."
	exit 1
fi

WORKDIR="$(mktemp -d)"

# Ligger mallarna bredvid skriptet (en klon av installationsrepot) används de i stället
# för att hämtas. Vid "sh -c \"\$(curl …)\"" är $0 bara "sh", och då tittar vi i katalogen
# vi står i – råkar det vara en klon fungerar installationen utan nät.
case "$0" in
*/*) SRC_CANDIDATE="$(dirname "$0")" ;;
*) SRC_CANDIDATE="." ;;
esac
if [ -f "${SRC_CANDIDATE}/compose/internal-db.yml" ]; then
	# Absolut sökväg: fetch() används efter att vi bytt till installationskatalogen.
	SRC_DIR="$(cd "$SRC_CANDIDATE" && pwd)"
	say "Använder mallarna i ${SRC_DIR}."
fi

if [ "$ASSUME_YES" -eq 0 ] && [ ! -t 0 ]; then
	fail "Skriptet kan inte ställa frågor: standard in är inte en terminal."
	say "Kör det så här i stället (notera sh -c och parenteserna):"
	say "  sh -c \"\$(curl -fsSL ${REPO_RAW}/install.sh)\""
	say "Eller lägg till --yes och flaggorna för de svar du vill ge."
	exit 1
fi

# ---- 2. installationskatalog ------------------------------------------------

if [ -z "$DIR" ]; then
	DIR="$(ask "Installationskatalog" "${HOME:-.}/receptapp")"
fi
# En inskriven ~ expanderas inte av skalet när den kom ur ett svar, så gör det här.
TILDE='~'
case "$DIR" in
"$TILDE") DIR="${HOME:-.}" ;;
"$TILDE"/*) DIR="${HOME:-.}/${DIR#"$TILDE"/}" ;;
esac
if ! mkdir -p "$DIR" 2>/dev/null; then
	fail "Kan inte skapa katalogen $DIR (rättigheter?)."
	exit 1
fi
if ! cd "$DIR"; then
	fail "Kan inte gå in i $DIR."
	exit 1
fi
DIR="$(pwd)"

if [ -f .env ] && [ "$RECONFIGURE" -eq 0 ]; then
	fail "Det finns redan en .env i $DIR – appen ser ut att vara installerad."
	say "Vill du uppdatera appen: ./update.sh"
	say "Vill du svara på frågorna igen: lägg till --reconfigure (gamla .env sparas)."
	exit 1
fi

# ---- 2b. compose-projektets namn --------------------------------------------
#
# Projektnamnet skrivs in i docker-compose.yml (name:) så att det inte beror på vad
# katalogen heter. Annars skulle 'docker compose up -d' här kunna ta över containrarna för
# en annan installation som ligger i en katalog med samma namn.

if [ -n "$PROJECT_OPT" ]; then
	PROJECT="$PROJECT_OPT"
elif [ "$RECONFIGURE" -eq 1 ] && [ -f docker-compose.yml ]; then
	# Behåll namnet installationen redan har, annars blir de gamla containrarna orphans.
	PROJECT="$(sed -n 's/^name:[[:space:]]*\([^[:space:]#]*\).*/\1/p' docker-compose.yml |
		head -n 1)"
	[ -z "$PROJECT" ] || say "Behåller projektnamnet ${PROJECT} ur den befintliga docker-compose.yml."
fi
[ -n "$PROJECT" ] || PROJECT="$DEFAULT_PROJECT"
case "$PROJECT" in
'' | *[!a-z0-9_-]*)
	fail "Projektnamnet \"$PROJECT\" går inte att använda."
	say "Compose tillåter små bokstäver, siffror, bindestreck och understreck."
	exit 1
	;;
esac

while project_conflict "$PROJECT"; do
	fail "Compose-projektet \"$PROJECT\" är redan taget: ${CONFLICT_WHY}."
	say "Två installationer med samma projektnamn delar containrar – en start här skulle"
	say "stoppa och återskapa den andras. Välj ett annat namn."
	if [ "$ASSUME_YES" -eq 1 ]; then
		say "Kör om med ett eget namn, till exempel:"
		say "  --project-name ${PROJECT}-2"
		exit 1
	fi
	PROJECT="$(ask "Projektnamn" "${PROJECT}-2")"
	case "$PROJECT" in
	'' | *[!a-z0-9_-]*)
		fail "Bara små bokstäver, siffror, bindestreck och understreck."
		exit 1
		;;
	esac
done

# ---- 3. frågor --------------------------------------------------------------

HOSTNAME_GUESS="$(hostname 2>/dev/null || uname -n 2>/dev/null || echo localhost)"
[ -n "$HOSTNAME_GUESS" ] || HOSTNAME_GUESS=localhost

URL_WAS_DEFAULT=0
if [ -z "$PUBLIC_URL" ]; then
	say ""
	say "1) Adress – det hushållet skriver i webbläsaren."
	say "   Kameran (streckkoder och foto-import), passkeys och att installera appen på"
	say "   hemskärmen kräver HTTPS. Vägen dit är en reverse proxy (HAProxy, Caddy, nginx)"
	say "   med certifikat framför porten nedan; skriv då proxyns adress här."
	say "   Adressen styr CSRF-kontrollen, säkra kakor och passkeys – byter du den senare"
	say "   måste alla passkeys registreras om."
	DEFAULT_URL="http://${HOSTNAME_GUESS}:${PORT:-$DEFAULT_PORT}"
	PUBLIC_URL="$(ask "   Adress" "$DEFAULT_URL")"
	[ "$PUBLIC_URL" = "$DEFAULT_URL" ] && URL_WAS_DEFAULT=1
fi
case "$PUBLIC_URL" in
http://* | https://*) ;;
*)
	PUBLIC_URL="http://${PUBLIC_URL}"
	warn "adressen saknade protokoll – tolkar den som $PUBLIC_URL."
	;;
esac
# Ta bort avslutande snedstreck; appen gör samma sak, men .env blir tydligare.
while :; do
	case "$PUBLIC_URL" in
	*/) PUBLIC_URL="${PUBLIC_URL%/}" ;;
	*) break ;;
	esac
done

if [ -z "$PORT" ]; then
	say ""
	say "2) Port på den här maskinen som appen ska nås på (inne i containern är det alltid"
	say "   8080). Har du en reverse proxy framför är det den här porten den ska peka på."
	PORT="$(ask "   Port" "$DEFAULT_PORT")"
fi
if ! is_port "$PORT"; then
	fail "'$PORT' är ingen port (1–65535)."
	exit 1
fi
if [ "$URL_WAS_DEFAULT" -eq 1 ] && [ "$PORT" != "$DEFAULT_PORT" ]; then
	PUBLIC_URL="http://${HOSTNAME_GUESS}:${PORT}"
	say "   Adressen följer porten: $PUBLIC_URL"
fi

if [ -z "$DB_MODE" ]; then
	say ""
	say "3) Databas"
	say "   1) Inbyggd MariaDB (rekommenderas) – en mariadb:11-container här, filerna i ./db"
	say "   2) Egen MariaDB (≥ 10.6) – en databas du redan har och sköter själv"
	while :; do
		DB_CHOICE="$(ask "   Välj 1 eller 2" "1")"
		case "$DB_CHOICE" in
		1) DB_MODE=internal; break ;;
		2) DB_MODE=external; break ;;
		*) say "   Svara 1 eller 2." ;;
		esac
	done
fi
case "$DB_MODE" in
internal | external) ;;
*)
	fail "--db måste vara 'internal' eller 'external' (fick '$DB_MODE')."
	exit 1
	;;
esac

if [ "$DB_MODE" = external ]; then
	[ -n "$DB_HOST" ] || DB_HOST="$(ask "   Databasvärd (namn eller ip)" "")"
	if [ -z "$DB_HOST" ]; then
		fail "Databasvärden måste anges för en egen MariaDB."
		exit 1
	fi
	[ -n "$DB_PORT" ] || DB_PORT="$(ask "   Databasport" "3306")"
	is_port "$DB_PORT" || {
		fail "'$DB_PORT' är ingen port."
		exit 1
	}
	[ -n "$DB_NAME" ] || DB_NAME="$(ask "   Databasnamn" "$DEFAULT_DB_NAME")"
	[ -n "$DB_USER" ] || DB_USER="$(ask "   Databasanvändare" "$DEFAULT_DB_USER")"
	if [ -z "$DB_PASS" ]; then
		DB_PASS="$(ask_secret "   Lösenord för $DB_USER")"
	fi
	if [ -z "$DB_PASS" ]; then
		fail "Lösenordet får inte vara tomt."
		exit 1
	fi
	case "$DB_HOST" in
	localhost | 127.0.0.1 | ::1)
		warn "databasvärden är $DB_HOST. Containern har sitt eget nät, så 'localhost' där"
		warn "är containern själv – inte den här maskinen. Använd maskinens adress på LAN,"
		warn "eller host.docker.internal plus extra_hosts i docker-compose.yml (se README)."
		;;
	esac
	case "$DB_PASS" in
	*/* | *@* | *'$'* | *'#'*)
		warn "lösenordet innehåller ett tecken (/ @ \$ #) som kan behöva skrivas om för"
		warn "hand i DB_DSN eller .env. Fungerar inte anslutningen: byt lösenord till"
		warn "något med bara bokstäver och siffror."
		;;
	esac

	say "   Provar anslutningen med ${MARIADB_IMAGE} …"
	DB_ERR="${WORKDIR}/dbtest.err"
	if MYSQL_PWD="$DB_PASS" docker run --rm -e MYSQL_PWD "$MARIADB_IMAGE" \
		mariadb --skip-ssl -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$DB_NAME" \
		-e 'SELECT 1' >/dev/null 2>"$DB_ERR"; then
		say "   Anslutningen fungerar."
	else
		fail "Kunde inte ansluta till ${DB_HOST}:${DB_PORT}/${DB_NAME} som ${DB_USER}."
		sed 's/^/   /' "$DB_ERR" >&2 || true
		say ""
		say "Kontrollera att databasen finns och att användaren får ansluta utifrån:"
		say "  CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_swedish_ci;"
		say "  CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '…';"
		say "  GRANT ALL ON ${DB_NAME}.* TO '${DB_USER}'@'%';"
		say "Och att brandväggen släpper fram port ${DB_PORT}."
		if [ "$ASSUME_YES" -eq 1 ]; then
			say "Ingen kan svara på frågor i --yes-läge, så installationen avbryts här."
			say "Rätta --db-host/--db-port/--db-name/--db-user/--db-password och kör igen."
			exit 1
		fi
		if ! confirm "Fortsätta ändå (appen startar inte förrän databasen svarar)?"; then
			exit 1
		fi
		warn "fortsätter utan en fungerande databasanslutning."
	fi
else
	DB_HOST=db
	DB_PORT=3306
	DB_NAME="$DEFAULT_DB_NAME"
	DB_USER="$DEFAULT_DB_USER"
	if [ -z "$DB_PASS" ]; then
		DB_PASS="$(rand_hex 24)" || {
			fail "Kunde inte slumpa databaslösenordet."
			exit 1
		}
	fi
	DB_ROOT_PASS="$(rand_hex 24)" || {
		fail "Kunde inte slumpa root-lösenordet."
		exit 1
	}
fi

if [ -z "$ANTHROPIC_KEY" ] && [ "$ASSUME_YES" -eq 0 ]; then
	say ""
	say "4) Claude API-nyckel (valfritt). Utan den fungerar import från länk, men inte från"
	say "   foto, PDF, Word eller inklistrad text. Nyckeln kan läggas in senare: skriv den"
	say "   som ANTHROPIC_API_KEY i .env och kör 'docker compose up -d'."
	say "   Nyckeln hämtas på https://console.anthropic.com/ (börjar med sk-ant-)."
	ANTHROPIC_KEY="$(ask_secret "   Nyckel (Enter för att hoppa över)")"
fi
if [ -n "$ANTHROPIC_KEY" ]; then
	case "$ANTHROPIC_KEY" in
	sk-ant-*) say "   Nyckel angiven." ;;
	*) warn "nyckeln börjar inte med sk-ant- – kontrollera att du klistrade in rätt sak." ;;
	esac
fi

if [ -z "$TZ_ANSWER" ]; then
	TZ_DEFAULT=""
	if [ -r /etc/timezone ]; then
		TZ_DEFAULT="$(tr -d ' \t\n' </etc/timezone 2>/dev/null || true)"
	fi
	[ -n "$TZ_DEFAULT" ] || TZ_DEFAULT="${TZ:-Europe/Stockholm}"
	say ""
	say "5) Tidszon – används för loggar, schemalagda jobb och måltidsloggens dygn."
	say "   (All data lagras i UTC; det här styr bara hur den visas och när jobb körs.)"
	TZ_ANSWER="$(ask "   Tidszon" "$TZ_DEFAULT")"
fi

# ---- 4. version -------------------------------------------------------------

if [ -n "$VERSION_OPT" ]; then
	VERSION="$VERSION_OPT"
else
	if fetch latest.json >"${WORKDIR}/latest.json" 2>/dev/null; then
		VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
			"${WORKDIR}/latest.json" | head -n 1)"
	fi
	if [ -z "$VERSION" ]; then
		VERSION="$FALLBACK_VERSION"
		warn "kunde inte läsa senaste versionen från ${LATEST_JSON_URL} – använder ${VERSION}."
	fi
fi
[ "$VERSION" = latest ] || VERSION="${VERSION#v}"

# ---- 5. sammanfattning ------------------------------------------------------

say ""
say "Så här blir det:"
say "  katalog:   $DIR"
say "  projekt:   $PROJECT (compose-projektets namn)"
say "  adress:    $PUBLIC_URL"
say "  port:      ${PORT} → 8080 i containern"
if [ "$DB_MODE" = internal ]; then
	say "  databas:   inbyggd MariaDB (mariadb:11), filerna i ${DIR}/db"
else
	say "  databas:   ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
fi
say "  image:     ${IMAGE}:${VERSION}"
say "  tidszon:   $TZ_ANSWER"
if [ -n "$ANTHROPIC_KEY" ]; then
	say "  Claude:    nyckel angiven (import från foto, PDF, Word och text fungerar)"
else
	say "  Claude:    ingen nyckel (bara import från länk)"
fi
say ""
if ! confirm "Skriva filerna och starta?"; then
	say "Avbrutet – ingenting skrevs."
	exit 0
fi
say ""

# ---- 6. kataloger -----------------------------------------------------------

mkdir -p data
if [ "$DB_MODE" = internal ]; then
	mkdir -p db
fi

# Containern kör som uid 65532 (distroless nonroot) och måste kunna skriva i data/.
# Under Docker Desktop (macOS, Windows) sköter VM:en det åt oss, så ett misslyckat chown
# är inte nödvändigtvis ett problem.
sudo_chown_data() {
	command -v sudo >/dev/null 2>&1 || return 1
	if [ "$ASSUME_YES" -eq 1 ]; then
		# Ingen som kan skriva ett lösenord: bara om sudo går utan att fråga.
		sudo -n chown -R 65532:65532 data 2>/dev/null
	else
		say "data/ måste ägas av uid 65532 (containerns användare). Kör sudo chown:"
		sudo chown -R 65532:65532 data
	fi
}

if chown 65532:65532 data 2>/dev/null; then
	say "data/ ägs nu av uid 65532 (containerns användare)."
elif sudo_chown_data; then
	say "data/ ägs nu av uid 65532."
else
	chmod 777 data 2>/dev/null || true
	warn "kunde inte sätta ägaren på data/ till uid 65532, satte 777 i stället."
	warn "Snyggare: sudo chown -R 65532:65532 \"${DIR}/data\" och sedan chmod 755 på den."
fi

# ---- 7. .env ----------------------------------------------------------------

if [ -f .env ]; then
	ENV_BAK=".env.bak-$(date -u +%Y%m%d-%H%M%S)"
	cp .env "$ENV_BAK"
	chmod 600 "$ENV_BAK" 2>/dev/null || true
	say "Gamla inställningarna sparade som ${ENV_BAK}."
fi

SESSION_SECRET="$(rand_hex 32)" || {
	fail "Kunde inte slumpa SESSION_SECRET."
	exit 1
}
DB_DSN="${DB_USER}:${DB_PASS}@tcp(${DB_HOST}:${DB_PORT})/${DB_NAME}?parseTime=true&charset=utf8mb4&collation=utf8mb4_swedish_ci&loc=UTC&multiStatements=true"

umask 077
{
	printf '%s\n' "# ReceptApp – inställningar för den här instansen."
	printf '%s\n' "# Skriven av install.sh $(date -u '+%Y-%m-%d %H:%M UTC'). Filen läses både av appen"
	printf '%s\n' "# (env_file i docker-compose.yml) och av docker compose självt. Rättigheter 600:"
	printf '%s\n' "# här står lösenord. Efter en ändring: docker compose up -d"
	printf '%s\n' ""
	printf '%s\n' "# ---- databas ----"
	printf '%s\n' "DB_DSN=${DB_DSN}"
	if [ "$DB_MODE" = internal ]; then
		printf '%s\n' "# Den inbyggda MariaDB:n startas med de här lösenorden (docker-compose.yml läser"
		printf '%s\n' "# dem härifrån). Byter du dem måste ./db raderas eller lösenorden ändras i"
		printf '%s\n' "# databasen – annars kommer appen inte in."
		printf '%s\n' "DB_ROOT_PASSWORD=${DB_ROOT_PASS}"
		printf '%s\n' "DB_PASSWORD=${DB_PASS}"
	fi
	printf '%s\n' "# Sekunder appen väntar på att databasen svarar innan den ger upp vid start."
	printf '%s\n' "DB_WAIT_SECONDS=60"
	printf '%s\n' ""
	printf '%s\n' "# ---- appen ----"
	printf '%s\n' "# Adressen utåt. Styr CSRF-kontroll, säkra kakor, passkeys och 'url' i /api/version."
	printf '%s\n' "PUBLIC_URL=${PUBLIC_URL}"
	printf '%s\n' "LISTEN_ADDR=:8080"
	printf '%s\n' "DATA_DIR=/data"
	printf '%s\n' "# Nyckeln sessionskakorna signeras med. Byter du den loggas alla ut."
	printf '%s\n' "SESSION_SECRET=${SESSION_SECRET}"
	printf '%s\n' "TZ=${TZ_ANSWER}"
	printf '%s\n' "# Daglig backup-zip under /data/backups kl 03:30."
	printf '%s\n' "AUTO_BACKUP=1"
	printf '%s\n' ""
	printf '%s\n' "# ---- import via Claude (valfritt) ----"
	printf '%s\n' "# Utan nyckel fungerar import från länk, men inte foto, PDF, Word eller fritext."
	printf '%s\n' "ANTHROPIC_API_KEY=${ANTHROPIC_KEY}"
	printf '%s\n' "ANTHROPIC_MODEL=claude-opus-5"
	printf '%s\n' ""
	printf '%s\n' "# ---- zoner, proxy och inloggning ----"
	printf '%s\n' "# Proxyer vars X-Forwarded-For får tros, t.ex. 192.168.1.1/32. Tomt = lita på ingen"
	printf '%s\n' "# (och då är proxyn själv 'klienten'). Sätt den INNAN AUTH_ZONES=enforce."
	printf '%s\n' "TRUSTED_PROXIES="
	printf '%s\n' "# Vad som räknas som hemnätet."
	printf '%s\n' "LAN_CIDRS=${DEFAULT_LAN_CIDRS}"
	printf '%s\n' "# off = zonen räknas bara ut för loggen, log = loggar det som skulle blockeras,"
	printf '%s\n' "# enforce = lösenord, admin och installation bara hemifrån (passkey krävs utifrån)."
	printf '%s\n' "AUTH_ZONES=off"
	printf '%s\n' ""
	printf '%s\n' "# ---- uppdateringskoll ----"
	printf '%s\n' "# En gång per dygn hämtas dokumentet nedan och versionen jämförs. Inget annat än"
	printf '%s\n' "# en User-Agent med versionen skickas. UPDATE_CHECK=0 stänger av kollen."
	printf '%s\n' "UPDATE_CHECK=1"
	printf '%s\n' "UPDATE_CHECK_URL=${LATEST_JSON_URL}"
	printf '%s\n' ""
	printf '%s\n' "# ---- Home Assistant (valfritt) ----"
	printf '%s\n' "# Inköpslistan kan skickas till en todo-lista i HA. Sänkan slås på under"
	printf '%s\n' "# Admin → Systemet när de tre raderna är ifyllda."
	printf '%s\n' "HA_URL="
	printf '%s\n' "HA_TOKEN="
	printf '%s\n' "HA_TODO_ENTITY=todo.inkopslista"
	printf '%s\n' ""
	printf '%s\n' "# ---- ICA-produktdata (valfritt) ----"
	printf '%s\n' "# Tomt = av. Ett butiks-id hos ICA Handla slår på hämtning av pris och sortiment"
	printf '%s\n' "# för den butiken."
	printf '%s\n' "ICA_STORE_ID="
	printf '%s\n' ""
	printf '%s\n' "# ---- loggar ----"
	printf '%s\n' "# debug, info, warn eller error. Loggen går till stdout och till"
	printf '%s\n' "# /data/logs/receptapp.log (roterande). LOG_FILE= (tomt) = bara stdout."
	printf '%s\n' "LOG_LEVEL=info"
	printf '%s\n' "LOG_MAX_SIZE_MB=20"
	printf '%s\n' "LOG_MAX_FILES=10"
} >.env
umask 022
chmod 600 .env
say "Skrev .env (rättigheter 600)."

# ---- 8. docker-compose.yml och update.sh ------------------------------------

if [ "$DB_MODE" = internal ]; then
	TEMPLATE="compose/internal-db.yml"
else
	TEMPLATE="compose/external-db.yml"
fi
if ! fetch "$TEMPLATE" >"${WORKDIR}/compose.yml"; then
	fail "Kunde inte hämta mallen ${TEMPLATE} från ${REPO_RAW}."
	say "Har maskinen nät? Annars: klona receptapp-install och kör ./install.sh därifrån."
	exit 2
fi
if [ -f docker-compose.yml ]; then
	cp docker-compose.yml "docker-compose.yml.bak-$(date -u +%Y%m%d-%H%M%S)"
fi
sed -e "s|__VERSION__|${VERSION}|g" -e "s|__PORT__|${PORT}|g" \
	-e "s|__PROJECT__|${PROJECT}|g" \
	"${WORKDIR}/compose.yml" >docker-compose.yml
if ! grep -q "^name:[[:space:]]*${PROJECT}\$" docker-compose.yml; then
	fail "Mallen saknar raden 'name: ${PROJECT}' – utan den skulle projektnamnet komma från"
	fail "katalognamnet, och en annan installation kunna tas över."
	exit 2
fi
if grep -q '__VERSION__\|__PORT__\|__PROJECT__' docker-compose.yml; then
	fail "Mallen innehöll platshållare som inte gick att ersätta."
	exit 2
fi
say "Skrev docker-compose.yml (${IMAGE}:${VERSION}, port ${PORT}, projekt ${PROJECT})."

if fetch update.sh >"${WORKDIR}/update.sh"; then
	# En tom eller trasig hämtning får inte skriva över ett fungerande update.sh.
	if head -n 1 "${WORKDIR}/update.sh" | grep -q '^#!/bin/sh'; then
		cp "${WORKDIR}/update.sh" update.sh
		chmod +x update.sh
		say "Skrev update.sh (uppdatera senare med ./update.sh)."
	else
		warn "update.sh såg inte ut som ett skript – hoppade över den."
	fi
else
	warn "kunde inte hämta update.sh. Hämta den senare från ${REPO_RAW}/update.sh."
fi

if [ "$SKIP_START" -eq 1 ]; then
	say ""
	say "--skip-start: filerna är skrivna, men ingenting startades."
	say "Starta själv med:  cd \"$DIR\" && docker compose up -d"
	exit 0
fi

# ---- 9. hämta och starta ----------------------------------------------------

# dc kör docker compose mot filen och projektet vi just skrev – aldrig via katalognamnet
# eller ett COMPOSE_PROJECT_NAME som råkar ligga i skalet.
dc() {
	docker compose -f docker-compose.yml -p "$PROJECT" "$@"
}

say ""
say "Hämtar imagen (${IMAGE}:${VERSION}) …"
if ! dc pull; then
	fail "Kunde inte hämta imagen."
	say "Vanliga orsaker: ingen nätåtkomst, eller att versionen ${VERSION} inte finns."
	say "Vilka versioner som finns står på ${LATEST_JSON_URL}."
	say "Filerna ligger kvar i $DIR – rätta docker-compose.yml och kör 'docker compose up -d'."
	exit 2
fi

say ""
say "Startar …"
if ! dc up -d; then
	fail "Starten misslyckades. De sista raderna ur loggen:"
	dc logs --tail 40 >&2 || true
	exit 2
fi

printf '\nVäntar på att appen ska svara (första starten kör migrationer och referensdata, '
printf 'det tar en stund) '
WAITED=0
HEALTHY=0
while [ "$WAITED" -lt "$HEALTH_TIMEOUT" ]; do
	if curl -fsS --max-time 3 "http://127.0.0.1:${PORT}/healthz" 2>/dev/null |
		grep -q '"status":"ok"'; then
		HEALTHY=1
		break
	fi
	printf '.'
	sleep 2
	WAITED=$((WAITED + 2))
done
printf '\n'

if [ "$HEALTHY" -ne 1 ]; then
	fail "Appen svarade inte inom ${HEALTH_TIMEOUT} sekunder. De sista raderna ur loggen:"
	dc logs --tail 40 >&2 || true
	say ""
	say "Filerna ligger kvar i $DIR. Kontrollera DB_DSN i .env och följ loggen:"
	say "  cd \"$DIR\" && docker compose logs -f"
	exit 3
fi

RUNNING_VERSION="$(curl -fsS --max-time 5 "http://127.0.0.1:${PORT}/api/version" 2>/dev/null |
	sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
[ -n "$RUNNING_VERSION" ] || RUNNING_VERSION="$VERSION"

say ""
say "Klart. ReceptApp ${RUNNING_VERSION} kör."
say ""
say "  Adress:        ${PUBLIC_URL}"
say "  Lokalt:        http://127.0.0.1:${PORT}"
say "  Katalog:       ${DIR}"
say "  Compose:       projekt ${PROJECT} (står som name: i docker-compose.yml)"
say "  Inställningar: ${DIR}/.env  (rättigheter 600 – här står lösenorden)"
say "  Data:          ${DIR}/data  (media, uppladdningar, backuper, loggar)"
if [ "$DB_MODE" = internal ]; then
	say "  Databas:       ${DIR}/db  (inbyggd MariaDB, ingen publicerad port)"
else
	say "  Databas:       ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
fi
say ""
say "Nästa steg"
say "  1. Öppna adressen och skapa admin-kontot – första besöket äger installationen."
say "     Livsmedelsverkets databas hämtas i bakgrunden (cirka sex minuter första gången)."
say "  2. Uppdatera senare med:   cd \"${DIR}\" && ./update.sh"
say "  3. Se loggen med:          cd \"${DIR}\" && docker compose logs --tail 100"
say "  4. HTTPS: sätt en reverse proxy med certifikat framför port ${PORT} och ändra"
say "     PUBLIC_URL i .env. Kamera, passkeys och installation på hemskärmen kräver det."
say "     README här har exempel för HAProxy, Caddy och nginx."
say "  5. Vill du stänga ute inloggning med lösenord utifrån: läs avsnitten"
say "     \"Zoner och inloggning\" och \"Passkeys\" i appens README, sätt TRUSTED_PROXIES"
say "     och registrera en passkey innan du sätter AUTH_ZONES=enforce."
exit 0

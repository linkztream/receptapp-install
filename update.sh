#!/bin/sh
# ReceptApp – uppdatera den här instansen. Det enda ett hushåll behöver köra.
#
#   ./update.sh                    hämta senaste versionen och starta om
#   TARGET=1.14.0 ./update.sh      gå till en bestämd version (även bakåt)
#   TARGET=latest ./update.sh      följ :latest-taggen
#
# Skriptet tar en backup innan något rörs, byter versionen på image-raden i
# docker-compose.yml, hämtar imagen, startar om och väntar tills appen svarar igen.
# Det är idempotent: att köra det två gånger gör ingen skada.
#
# Tillbaka till en äldre version: TARGET=<gammal version> ./update.sh. Observera att
# databasmigrationer INTE rullas tillbaka – en äldre binär mot ett nyare schema kan bete
# sig oväntat. Den säkra vägen tillbaka är backupen som togs före uppdateringen:
# Admin → Systemet → Importera backup, med filen data/backups/pre-update-<tidsstämpel>.zip.
#
# Avslutskoder: 0 klart, 1 förutsättning saknas, 2 hämtningen eller starten misslyckades,
# 3 appen kom inte igång i tid.

set -eu

cd "$(dirname "$0")"

IMAGE="ghcr.io/linkztream/receptapp"
LATEST_URL="${LATEST_URL:-https://raw.githubusercontent.com/linkztream/receptapp-install/main/latest.json}"
SERVICE=receptapp
PORT="${PORT:-}"
TARGET="${TARGET:-}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-120}"
BACKUP=""
RESTORE_FROM=""

say() { printf '%s\n' "$*"; }
warn() { printf 'VARNING: %s\n' "$*" >&2; }
fail() { printf 'FEL: %s\n' "$*" >&2; }

trap '[ -z "$RESTORE_FROM" ] || rm -rf "$RESTORE_FROM"' EXIT

# ---- 1. förutsättningar -----------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
	fail "docker är inte installerat (eller ligger inte i PATH)."
	exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
	fail "'docker compose' saknas. Installera Docker Compose v2 (docker-compose-plugin)."
	exit 1
fi
if ! docker info >/dev/null 2>&1; then
	fail "docker svarar inte. Är tjänsten igång, och har du rättigheter att prata med den?"
	exit 1
fi
if [ ! -f .env ]; then
	fail "Ingen .env i $(pwd). Är det här rätt katalog? install.sh skapade både .env och"
	fail "docker-compose.yml i installationskatalogen."
	exit 1
fi
# Compose-filen: den som finns. install.sh skriver docker-compose.yml, men compose läser
# gärna compose.yaml också.
COMPOSE=""
for f in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
	if [ -f "$f" ]; then
		COMPOSE="$f"
		break
	fi
done
if [ -z "$COMPOSE" ]; then
	fail "Ingen docker-compose.yml i $(pwd). Är det här rätt katalog?"
	exit 1
fi
if grep -qE '^[[:space:]]*build:' "$COMPOSE"; then
	fail "$COMPOSE bygger appen ur källkoden (build:), och det här skriptet uppdaterar"
	fail "en färdig image."
	say ""
	say "Kör update.sh i app-repots klon i stället – den sköter bygget. Vill du byta till"
	say "den färdiga imagen: ta bort build:-raderna och sätt"
	say "  image: ${IMAGE}:latest"
	say "i $COMPOSE, och kör det här skriptet igen."
	exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
	warn "curl saknas – kan inte läsa versioner eller /healthz. Hälsokollen i containern"
	warn "får räcka."
fi

# Värdporten står i docker-compose.yml, som en rad i ports: ("8090:8080" eller
# "127.0.0.1:8090:8080"). Bara listrader räknas, så kommentarer kan inte lura sed.
if [ -z "$PORT" ]; then
	PORT="$(sed -n 's/^[[:space:]]*-[[:space:]]*"\{0,1\}\(.*\):8080"\{0,1\}[[:space:]]*$/\1/p' \
		"$COMPOSE" | head -n 1 | sed 's/.*://')"
	case "$PORT" in
	'' | *[!0-9]*) PORT="" ;;
	esac
fi
[ -n "$PORT" ] || PORT=8090
BASE="http://127.0.0.1:${PORT}"

# api_field hämtar ett fält ur GET /api/version. Tyst; tom utdata betyder "vet inte".
api_field() {
	command -v curl >/dev/null 2>&1 || return 0
	curl -fsS --max-time 5 "${BASE}/api/version" 2>/dev/null |
		sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p" |
		head -n 1
}

CURRENT_TAG="$(sed -n "s|.*image:[[:space:]]*${IMAGE}:\([^[:space:]\"']*\).*|\1|p" \
	"$COMPOSE" | head -n 1)"
if [ -z "$CURRENT_TAG" ]; then
	fail "Hittar ingen rad 'image: ${IMAGE}:<version>' i $COMPOSE."
	say "Pekar instansen på en annan image? Ändra versionen för hand och kör"
	say "'docker compose up -d'."
	exit 1
fi

BEFORE="$(api_field version || true)"
[ -n "$BEFORE" ] || BEFORE="okänd"

say "ReceptApp uppdatering"
say "  katalog:           $(pwd)"
say "  nuvarande version: ${BEFORE}"
say "  låst till:         ${IMAGE}:${CURRENT_TAG}"
say "  adress:            ${BASE}"
say ""

# ---- 2. vilken version ska vi till? -----------------------------------------

if [ -z "$TARGET" ]; then
	if command -v curl >/dev/null 2>&1; then
		TARGET="$(curl -fsSL --max-time 10 "$LATEST_URL" 2>/dev/null |
			sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
	fi
	if [ -z "$TARGET" ]; then
		fail "Kunde inte läsa senaste versionen från ${LATEST_URL}."
		say "Har maskinen nät? Annars: TARGET=<version> ./update.sh"
		exit 1
	fi
fi
[ "$TARGET" = latest ] || TARGET="${TARGET#v}"

if [ "$TARGET" = "$CURRENT_TAG" ]; then
	say "Redan låst till ${TARGET}. Hämtar ändå – en rörlig tagg (latest, 1.13) kan peka"
	say "på något nyare."
else
	say "Uppdaterar ${CURRENT_TAG} → ${TARGET}."
fi
say ""

# ---- 3. backup före allt annat ----------------------------------------------

STAMP="$(date -u +%Y%m%d-%H%M%S)"
BACKUP="pre-update-${STAMP}.zip"
if docker compose ps --status running "$SERVICE" 2>/dev/null | grep -q "$SERVICE"; then
	say "Tar backup före uppdateringen …"
	if docker compose exec -T "$SERVICE" /receptapp -export "/data/backups/${BACKUP}" \
		>/dev/null 2>&1; then
		say "  backup: data/backups/${BACKUP}"
	else
		warn "backupen misslyckades. Fortsätter ändå – men du har ingen färsk kopia."
		warn "Du kan hämta en manuellt under Admin → Systemet → Backup."
		BACKUP=""
	fi
else
	warn "containern kör inte, så ingen backup togs."
	BACKUP=""
fi
say ""

# ---- 4. byt version i docker-compose.yml ------------------------------------

RESTORE_FROM="$(mktemp -d)"
cp "$COMPOSE" "${RESTORE_FROM}/compose-backup"
sed "s|\(image:[[:space:]]*${IMAGE}\):[^[:space:]\"']*|\1:${TARGET}|" \
	"${RESTORE_FROM}/compose-backup" >"${COMPOSE}.new"
if ! grep -q "${IMAGE}:${TARGET}" "${COMPOSE}.new"; then
	rm -f "${COMPOSE}.new"
	fail "Kunde inte skriva om image-raden i $COMPOSE."
	say "Ändra den för hand till '${IMAGE}:${TARGET}' och kör 'docker compose up -d'."
	exit 1
fi
mv "${COMPOSE}.new" "$COMPOSE"

restore_compose() {
	cp "${RESTORE_FROM}/compose-backup" "$COMPOSE"
	say "$COMPOSE är återställd till ${CURRENT_TAG}."
}

# ---- 5. hämta och starta ----------------------------------------------------

say "Hämtar ${IMAGE}:${TARGET} …"
if ! docker compose pull; then
	fail "Kunde inte hämta imagen. Finns versionen ${TARGET}?"
	say "Vilka versioner som finns står på ${LATEST_URL}."
	restore_compose
	exit 2
fi
say ""

say "Startar om …"
if ! docker compose up -d; then
	fail "Starten misslyckades. De sista raderna ur loggen:"
	docker compose logs --tail 40 >&2 || true
	say ""
	say "Den gamla containern kan ha stoppats. 'docker compose up -d' startar den igen."
	exit 2
fi
say ""

# ---- 6. vänta på att appen svarar -------------------------------------------

printf 'Väntar på att appen ska svara '
WAITED=0
HEALTHY=0
while [ "$WAITED" -lt "$HEALTH_TIMEOUT" ]; do
	if command -v curl >/dev/null 2>&1; then
		if curl -fsS --max-time 3 "${BASE}/healthz" 2>/dev/null | grep -q '"status":"ok"'; then
			HEALTHY=1
			break
		fi
	else
		# Utan curl får hälsokollen i containern räcka.
		if docker compose exec -T "$SERVICE" /receptapp -healthcheck >/dev/null 2>&1; then
			HEALTHY=1
			break
		fi
	fi
	printf '.'
	sleep 2
	WAITED=$((WAITED + 2))
done
printf '\n'

if [ "$HEALTHY" -ne 1 ]; then
	fail "Appen svarade inte inom ${HEALTH_TIMEOUT} sekunder. De sista raderna ur loggen:"
	docker compose logs --tail 40 >&2 || true
	say ""
	say "Containern är startad men osund. Kolla DB_DSN i .env och kör:"
	say "  docker compose logs --tail 100"
	if [ -n "$BACKUP" ]; then
		say "Backupen före uppdateringen ligger kvar: data/backups/${BACKUP}"
	fi
	say "Tillbaka till den gamla versionen: TARGET=${CURRENT_TAG} ./update.sh"
	exit 3
fi

AFTER="$(api_field version || true)"
[ -n "$AFTER" ] || AFTER="okänd"
MIGRATION="$(api_field db_migration || true)"
[ -n "$MIGRATION" ] || MIGRATION="okänd"

say ""
say "Klart."
say "  version:    ${BEFORE} → ${AFTER}"
say "  image:      ${IMAGE}:${TARGET}"
say "  migrering:  ${MIGRATION}"
if [ -n "$BACKUP" ]; then
	say "  backup:     data/backups/${BACKUP}"
fi
say ""
say "Kontrollera under Admin → Systemet att allt ser rätt ut."
say "Blev något fel: TARGET=${CURRENT_TAG} ./update.sh går tillbaka till den gamla imagen."
say "Databasmigrationer rullas inte tillbaka – behöver du också gammal data, importera"
if [ -n "$BACKUP" ]; then
	say "backupen under Admin → Systemet → Importera backup (data/backups/${BACKUP})."
else
	say "en backup under Admin → Systemet → Importera backup."
fi
exit 0

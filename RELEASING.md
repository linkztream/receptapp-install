# Släppa en version (för ägaren)

Hushållens `update.sh` och appens dygnsvisa uppdateringskoll läser **`latest.json` på
`main` i det här repot**. Ett släpp är därför inte klart förrän filen är bumpad och
pushad – imagen kan finnas i GHCR i en vecka utan att någon får veta det.

Ordningen är: tagga appen → CI bygger imagen → bumpa `latest.json` här.

## 1. Appen (privata repot)

```sh
task release VERSION=1.13.0      # bumpar VERSION, committar "Release v1.13.0", taggar v1.13.0
git push --follow-tags           # v-taggen startar release.yml
```

`release.yml` bygger imagen för amd64 och arm64 och pushar
`ghcr.io/linkztream/receptapp:1.13.0`, `:1.13` och `:latest`.

Kontrollera att imagen finns innan nästa steg – hushållen hämtar den direkt:

```sh
docker manifest inspect ghcr.io/linkztream/receptapp:1.13.0 >/dev/null && echo finns
```

## 2. Installationsrepot (det här)

```sh
V=1.13.0
sed -i -e "s/\"version\": \"[^\"]*\"/\"version\": \"$V\"/" \
       -e "s|receptapp:[^\"]*|receptapp:$V|" latest.json
# skriv om "notes" till en rad om vad som är nytt
git commit -am "latest.json: $V" && git push
```

Kontrollera resultatet (och att JSON:en håller):

```sh
python3 -m json.tool latest.json
curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/latest.json
```

Formatet måste behålla `version` och `url`; appens uppdateringskoll läser exakt de två
fälten (`image` och `notes` är extra och ignoreras). `version` skrivs utan `v`, precis som
imagetaggen.

`install.sh` har dessutom ett `FALLBACK_VERSION` som bara används när `latest.json` inte
går att hämta (ingen nät, GitHub nere). Bumpa det när du ändå är inne i filen – annars kan
en nyinstallation utan nät hamna flera versioner bak:

```sh
grep -n FALLBACK_VERSION install.sh
```

Vill du ha releasenoter att peka på: skapa en release här (`gh release create v1.13.0
--notes-file …`) – `url` i `latest.json` går till repots release-sida.

## 3. Kontrollera från utsidan

```sh
cd /tmp && sh -c "$(curl -fsSL https://raw.githubusercontent.com/linkztream/receptapp-install/main/install.sh)" \
  -- --yes --dir /tmp/receptapp-test --db internal --port 8099
```

Och på en befintlig instans: `./update.sh` ska säga `gammal → 1.13.0`.

## Om ett släpp är trasigt

1. Sätt `latest.json` tillbaka till den förra versionen och pusha – då slutar nya
   installationer och uppdateringar att välja den trasiga.
2. Hushåll som redan uppdaterat går tillbaka med `TARGET=<förra versionen> ./update.sh`.
   Databasmigrationer rullas **inte** tillbaka; behövs gammal data också importeras
   backupen som `update.sh` tog före uppdateringen.
3. Ta aldrig bort en taggad image ur GHCR – `TARGET=<version>` måste fortsätta fungera.

## Checklista

- [ ] `task release VERSION=x.y.z` och `git push --follow-tags` i app-repot
- [ ] release.yml grön, `docker manifest inspect …:x.y.z` svarar
- [ ] `latest.json` bumpad (`version`, `image`, `notes`) och pushad hit
- [ ] `FALLBACK_VERSION` i `install.sh` bumpad
- [ ] `./update.sh` provad på en riktig instans
- [ ] `install.sh` provad från noll (gärna på en annan maskin eller i en VM)

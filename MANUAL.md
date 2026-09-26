# ReceptApp – handbok

Den här handboken är för dig som ska *använda* ReceptApp. Den går att läsa rakt igenom på
en kvart. Ska du installera eller driva appen: se [README.md](README.md).

Knappar och rubriker skrivs **så här** och är exakt vad som står i appen.

**Innehåll**

1. [Komma igång](#1-komma-igång)
2. [Recept](#2-recept)
3. [Importera recept](#3-importera-recept)
4. [Veckoplan](#4-veckoplan)
5. [Inköpslista](#5-inköpslista)
6. [Skafferi och skanning](#6-skafferi-och-skanning)
7. [Dagbok](#7-dagbok)
8. [Dela recept](#8-dela-recept)
9. [Admin](#9-admin)
10. [Vanliga frågor](#10-vanliga-frågor)

---

## 1. Komma igång

### Logga in

Första personen som öppnar appen skapar administratörskontot. Därefter loggar var och en in
med användarnamn och lösenord, eller med **Logga in med passkey**.

Lägg till appen på hemskärmen (i Safari: *Dela → Lägg till på hemskärmen*; i Chrome:
*Installera appen*). Då får du helskärm, egen ikon och den fungerar även när nätet
strular. Det kräver att adressen är `https://`.

### Profiler – en per person som äter

**Inställningar → Profiler**. Profilerna är hjärtat i appen: de styr vad som planeras, hur
mycket som handlas och vad dagboken jämför mot.

- **Namn** och **Portionsfaktor** – hur stor portion personen äter jämfört med en
  standardportion. Snabbval finns: **Barn 0,6**, **Vuxen 1,0**, **Stor 1,3**.
- **Kosthållning**: **Allätare**, **Vegetarian**, **Vegan** eller **Pescetarian**.
- **Kalorimål per dag (kcal)** och **Makromål per dag**: **Protein minst (g)**,
  **Kolhydrater högst (g)**, **Fett minst (g)** och **Fett högst (g)**. Allt är valfritt.
  Tabellen **Så använder planeraren målen** på samma sida visar exakt hur de används:
  kalorierna fördelas per måltid (frukost 20 %, lunch 30 %, middag 35 %, mellanmål 15 %),
  protein är ett minimum som kontrolleras vid dagens sista huvudmål, kolhydrater ett tak
  för dagen och fett både tak och minimum.
- **Aktiv** / **Inaktiv** – inaktiva profiler föreslås inte som deltagare i veckoplanen.

### Allergier: tre nivåer

Under **Allergier och intoleranser** finns **EU-allergener** och **Övriga (frukt,
grönsaker m.m.)** – vitlök ligger bland de övriga. För varje allergen väljer du
**Allvarlighet**:

| Nivå | Vad som väljs bort |
| --- | --- |
| **Undvik** | Recept som **innehåller** allergenet. |
| **Intolerans** | Dessutom recept där allergenet är **troligt** – till exempel kryddblandningar. |
| **Allvarlig** | Dessutom recept som **kan innehålla spår** av det. |

*Recept som innehåller allergenet filtreras alltid bort. Välj allvarlighet för att också
blockera "kan innehålla" och "troligen".* Vill du finjustera finns **Avancerat** med de två
kryssen **Blockera "kan innehålla"** och **Blockera "troligen" (t.ex. kryddblandningar)** –
de går att slå på eller av oavsett nivå. På receptsidan står allergenerna under
**Allergener**, uppdelade i **Innehåller**, **Troligen** och **Kan innehålla spår av**.

**Ogillar** är för det som inte är allergi: recept med de ingredienserna undviks, men bara
om ingrediensen inte är markerad som valfri.

Planeraren kan också byta ut en enskild ingrediens i stället för att kasta hela receptet.
Ser du raden **Planeraren byter automatiskt till … när … äter** kan du trycka **Gör till
fast regel**, och då står det **Byter alltid … mot …** i fortsättningen. **Sluta byta**
tar bort regeln.

### Användare och profiler är inte samma sak

En **profil** är en person som äter. Ett **konto** (användare) är någon som kan logga in.
Barn behöver profiler men sällan konton. En profil kan kopplas till ett konto under
**Kopplat användarkonto**.

Kopplingen styr vem som får ändra vad – *profilspärren*: **Bara admin eller profilens
ägare kan ändra den här profilen. Du kan se den för planeringen.** Samma regel gäller
betyg, serveringsval och favorittillbehör; då står det **Bara … själv eller en
administratör kan …**. Profiler du får se men inte ändra är märkta **skrivskyddad**.

Eget lösenord byter du under **Inställningar → Byt lösenord**: **Nuvarande lösenord**,
**Nytt lösenord**, **Upprepa nytt lösenord**. Minst 8 tecken, och det får inte innehålla
ditt namn, användarnamn eller namn på någon i hushållet.

### Passkeys

En passkey ligger i telefonen, datorn eller lösenordshanteraren och låses upp med
fingeravtryck, ansikte eller PIN. Den är både bekvämare och säkrare än ett lösenord – och
om hushållet har slagit på zonpolicyn är den **det enda sättet att logga in utanför
hemnätet**.

- **Registrera hemma:** **Inställningar → Passkeys → Lägg till passkey**, lås upp med
  finger eller ansikte och ge nyckeln ett namn ("Min iPhone"). Registrering sker bara
  hemifrån. Gör det *innan* någon reser bort.
- **Logga in:** tryck **Logga in med passkey** på inloggningssidan. Inget användarnamn
  behövs – nyckeln vet vilket konto den hör till.
- Står det **synkad** säkerhetskopieras nyckeln av din lösenordshanterare och finns även på
  dina andra enheter.
- **Tappad telefon:** ta bort dess passkey under **Inställningar → Passkeys → Ta bort**
  (eller låt en admin göra det under **Admin → Användare**). Enheten loggas ut direkt och
  kan inte logga in igen.
- Ingen e-poståterställning finns. Har du tappat allt: logga in hemma med lösenord och
  registrera en ny passkey.

---

## 2. Recept

### Bläddra, söka och filtrera

**Recept** visar biblioteket. Sök med **Sök recept eller ingrediens…** och öppna **Filter**
för **Måltid**, **Taggar**, **Metod**, **Max tid**, **Favoriter** och **Allergifritt för**
(välj en profil). **Sortera** kan stå på **Relevans**, **Nyast**, **Titel A–Ö**, **Betyg**,
**Kortast tid** eller **Senast lagad**. **Rensa filter** nollar allt.

Två filter är värda att kunna:

- **Hemma** (skafferiet) med läge **Av**, **Helst** eller **Bara**. Korten visar då
  **allt hemma**, **{n} % hemma** eller **saknar**.
- **Passar i dag** rangordnar efter vad som är kvar av dagen: *ditt mål minus dagboken
  minus dagens övriga måltider*. Välj **Profil** och **Måltid**, och appen skriver ut
  **Kvar i dag för …** med kalorier och makron. Har profilen inga mål visas listan som
  vanligt.

Kort med flera varianter visar **{n} varianter** – kortet visar den högst betygsatta.

### Receptsidan

Överst finns **portioner** med **Färre portioner** / **Fler portioner**. Skalningen räknar
om alla mängder. Recept som alltid görs i sin helhet (en form, en plåt) visar i stället
**Ger …**.

- **Visa**: **Som i receptet**, **Vikt** eller **Volym**. Praktiskt när receptet anger
  dl men du vill väga.
- **Ingredienser** kan vara grupperade under egna rubriker, och rader kan vara märkta
  **valfritt** eller **cirka**.
- **Tillbehör** är det som brukar följa med rätten. Tillbehören läggs till automatiskt när
  måltiden planeras – var och en till sina portioner. Du kan sätta **Mitt
  favorittillbehör** eller **Förslag till alla**.
- **Servera med** är det som ställs fram på bordet: sylt, grädde, en banan. Kryssa för vad
  var och en vill ha – **inköpslistan köper bara det någon valt, och näringen räknas på
  din egen tallrik**. Appen visar **Med dina val: +{kcal} kcal**.
- **Betyg**: sätt **Ditt betyg** och gärna en **Kommentar**. Under **Betyg per profil**
  sätter du betyg för barn utan konto. **Låga betyg gör att receptet väljs bort i
  veckoplanen.**
- **Näring per portion** räknas från de länkade ingredienserna (tillagningsförlust
  ignoreras). Står det **Ofullständig ({n} %)** saknas data för några rader; under 50 %
  täckning visas inga makron.
- **Laga** öppnar kokläget. **Lagat idag** noterar att rätten lagats – det påverkar
  variationen i kommande veckoplaner. **Planera** lägger den i veckan.

**Varianter:** **Gör till variant av …** lägger receptet i samma grupp som ett annat
(båda behåller sina egna ingredienser, steg och betyg). **Bryt ut ur gruppen** ångrar det.

**Arkivera** tar bort receptet ur listor och planering men sparar det: *Receptet försvinner
ur listor och planering men kan återställas av admin.* En admin kan **Återställ** eller
**Radera permanent** (då måste ordet **RADERA** skrivas in – allt försvinner och det går
inte att ångra).

### Redigeraren

**Nytt recept** eller **Redigera**.

- **Titel**, **Beskrivning** (Markdown), **Käll-URL**, **Huvudingrediens** (används för
  variation i veckoplanen), **Förberedelse (min)**, **Tillagning (min)**, **Håller
  (dagar)**.
- **Portioner**, **Portionstext** ("12 bullar") och **Portionssteg**. Kryssa **Skala inte –
  fast form/utbyte** för sånt som alltid görs i en hel form; appen föreslår det själv när
  det ser ut så: **Det här ser ut som ett recept med fast utbyte – skala inte?**
- **Ingredienser** fylls snabbast via **Snabbinmatning**: skriv "2 dl vetemjöl, siktat"
  och tryck Enter, eller klistra in många rader på en gång. Varje rad kan ha **Mängd**,
  **till** (intervall), **Enhet**, **Ingrediens**, **Notering** och kryssen **Valfri** och
  **Cirka**.
- **Grupper:** **Lägg till grupprubrik** ("Sås", "Degen"). Importerade rubriker blir
  grupper automatiskt. Markera rader med **Välj rader** och använd **Flytta till…** för att
  flytta flera på en gång, **Byt namn på gruppen** eller **Ta bort gruppen**.
- **Servera med…** skapar gruppen **Till servering** – *valfritt vid bordet, räknas inte i
  näringsvärdet*.
- **Taggar** är fria. En är särskild: **högtid = planeras bara manuellt**. Sådana recept
  läggs aldrig in automatiskt; på receptsidan står **Planeras bara manuellt – läggs in i
  veckan för hand.**
- **Komplettera från foto, länk eller text** läser in mer av receptet – till exempel
  glasyren på kortets baksida – och lägger till det som saknas. **Inget tas bort.**
- Ingredienser kopplas till registret (**Kopplad till …**, **Matchning: säker / osäker /
  gissning**). Kopplingen ger näringsvärden, allergener och enhetsomvandlingar, så det är
  värt att rätta osäkra rader.
- Redskap hör inte hit: **Redskap (t.ex. bakplåtspapper) hör inte hemma bland
  ingredienserna – ta bort raden eller flytta den till anteckningarna.**
- **Spara recept**. Lämnar du sidan med osparat kommer frågan **Du har osparade ändringar.
  Vill du lämna sidan?**

---

## 3. Importera recept

**Importera** har fyra flikar: **Länk**, **Fil**, **Foto** och **Text**. Allt utom **Länk**
kräver att hushållet har lagt in en Claude-nyckel (se [Admin](#9-admin)).

- **Länk:** klistra in adressen. Sidor med standarddata (schema.org) läses direkt och
  gratis. Engelska recept översätts till svenska, och amerikanska cup-mått räknas om till
  dl och gram.
- **Text:** klistra in **Ingredienser och tillvägagångssätt…** – ren text eller Markdown.
- **Foto:** **Ta foto** eller **Välj från bilder**. *Fotografera receptet eller välj
  sparade bilder – flera bilder blir ett recept i ordning.* Har du glömt baksidan: använd
  **Lägg till fler bilder** och kör om, eller **Komplettera** senare från receptsidan.
- **Fil:** txt, md, **pdf** eller docx, max 40 MB. För långa PDF:er finns **Sidintervall
  (valfritt)** – skriv "3-5". Skannade PDF:er tar längre tid.
- **Video:** klistra in en länk från YouTube, TikTok eller Instagram under **Länk**. Appen
  läser beskrivningen och undertexterna.
- **Från telefonen:** dela en länk, en text eller bilder till ReceptApp i mobilens
  delningsmeny – importsidan öppnas med rätt flik ifylld. (Kräver Android och installerad
  app; iOS saknar stöd för delningsmål.)

Medan det arbetar står **Claude läser receptet… Det kan ta upp till en minut.** Du kan
lämna sidan – importen fortsätter på servern och hamnar i listan **Senaste importer** med
status **Köad**, **Bearbetar**, **Att granska**, **Klar** eller **Misslyckades**.

### Granska

När importen är klar öppnar du den under **Granska**. **Gulmarkerade fält är osäkra –
kontrollera dem.** Du ser även **Källa** och **Extraherad text**, och kan välja vilka
**Bilder** som sparas och vilken som är **Omslag**. Redskap som låg bland ingredienserna
lyfts till anteckningarna, och appen berättar vilka.

- **Spara recept** lägger in det. **Spara utkast** sparar utan att publicera.
- **Kör om med Claude** gör ett nytt försök, **Kassera** slänger importen.
- Ser appen ett liknande recept varnar den: **Liknande recept finns: … ({score} %)**. Då
  kan du **Öppna** det gamla, **Ersätt** det, **Spara ändå** eller – oftast bäst –
  **Spara som variant av …**: *Båda behåller sina egna ingredienser, steg och betyg.*

---

## 4. Veckoplan

**Veckoplan** visar en vecka i taget (**Föregående vecka**, **Nästa vecka**, **Idag**) med
**Frukost**, **Lunch**, **Middag** och **Mellanmål**.

### Vem äter?

**Deltagare** per måltid: *Bocka i vilka som äter varje måltid. Används för portioner,
näring och allergifilter.* Det är deltagarna som avgör hur många portioner som lagas, vad
som handlas och vilka allergier som gäller just den måltiden.

### Generera

**Generera vecka** öppnar **Generera veckoplan**:

- **Behåll befintliga rätter (fyll bara tomma)** rör inte det du redan valt.
- **Planera från och med** planerar resten av veckan. **Passerade måltider lämnas orörda.**

*Planeraren väljer recept utifrån deltagarnas allergier, kost, ogillanden, kalori- och
proteinmål och undviker upprepningar.* Mer i detalj:

- Allergier och kost filtrerar bort recept helt (eller byter en ingrediens, se
  [Allergier](#allergier-tre-nivåer)). **Ogillar** undviks.
- Betyg styr: recept som någon av de som äter gett för få stjärnor väljs aldrig
  automatiskt (**Lägsta betyg i veckoplanen** i admin-inställningarna).
- Variation: nyligen lagade rätter får minuspoäng, störst samma dag och avtagande över
  ungefär **Variation: dagar mellan upprepningar**. Recept som legat i en plan utan att
  bockas som lagade räknas till hälften. **Huvudingrediens** och metodtaggar sprids så att
  det inte blir kyckling i ugn tre dagar i rad.
- Mål: kalorierna fördelas per måltid och rätter som spräcker kolhydrattaket får
  minuspoäng. Har du redan ätit i dag räknar planeraren på vad som är **kvar** av dagen.
- Recept med taggen **högtid** läggs aldrig in automatiskt.
- **Tillbehör** som någon gjort till favorit läggs till automatiskt, var och en till sina
  portioner.

Finns det för få recept säger appen **Importera fler recept**, och utan profiler **Skapa
minst en profil innan du planerar.**

**Rensa vecka** tar bort veckans måltider, med valen **Behåll låsta och egna rätter** och
**Bara från och med idag**.

### En måltid i planen

Tryck på ett kort för **Åtgärder**:

- **Byt ut** slumpar en ny rätt i samma lucka. **Lås** skyddar kortet mot **Byt ut** och
  nya körningar (**Låst**).
- **Byt deltagare**, **Ändra portioner** (**Portioner att laga**), **Flytta** eller **Byt
  plats** med en annan dag, **Ta bort**.
- **Lagat** markerar att rätten faktiskt lagades. **Laga** öppnar kokläget.
- Lägg till **Tillbehör** för hand. Automatiska tillbehör är märkta **auto**, receptets
  egna förslag **föreslaget** – tryck **byt** för ett annat. **Ta bort – kommer inte
  tillbaka** stänger av ett automatiskt tillbehör för just den måltiden.
- En tom lucka säger **Tryck för att välja recept**. I väljaren finns **Sugen på**
  (**Kyckling**, **Kött**, **Fisk**, **Vegetariskt**), **Tillbehör och såser**, samt
  **Passar luckan** / **Vanlig ordning**. **Fritext** är för sånt som inte är ett recept:
  "Restaurang", "Ute hos mormor".
- Kort kan dras till en annan dag (**Dra receptet till en annan dag**).

Lagar du dubbelt blir resten en egen måltid: kort märkta **Rester av …**. Recept med fast
utbyte skalas inte – hela formen lagas, och portionerna räcker till det de räcker till.

### Näringsstaplarna

**Näring per dag** visar en stapel per dag och profil:

- **Stapelns färger = kolhydrater, protein, fett. Fylld = ätit, kontur = planerat.
  Strecket = målet. Punkt = dagen är inte loggad.**
- **Stapel = kcal mot dagsmål. Färgen på överkanten: grön inom ±10 %, gul under, röd över.
  ▲ = över kolhydratmax.**

Kortet **Planerat men inte loggat** har knappen **Åt detta** som loggar måltiden i
dagboken med ett tryck. **Skapa inköpslista** gör listan för veckan.

---

## 5. Inköpslista

**Inköpslista** byggs ur veckoplanen. Finns ingen ännu: **Skapa inköpslista**.

- **Handla för resten av veckan** bygger om listan från planen. *Manuella rader och
  avbockningar behålls.* **Från och med** styr varifrån, och *passerade och redan lagade
  måltider hamnar inte på listan*.
- Allt slås samman: 2 dl mjölk i ett recept och 3 dl i ett annat blir en rad. Små mängder
  avrundas till något man kan handla.
- **Finns hemma** och **avdraget från skafferiet** visas på rader som skafferiet täcker
  helt eller delvis.
- **varför?** på en rad visar **Behövs till** – vilka recept som kräver den.
- Kryddor och sånt som "salt efter smak" får ingen inköpsmängd; står det redan en mätt
  mängd på raden läggs bara **+ efter smak** till. Basvaror (salt, peppar, olja) kan
  hoppas över helt med **Hoppa över basvaror (salt, peppar, olja…) i inköpslistan**.
- Valfria ingredienser hamnar i gruppen **Valfritt** sist, eller som **+ valfritt {qty}**
  på en vanlig rad. Inställningen **Ta med valfria ingredienser på inköpslistan** styr om
  de tas med.
- **Lägg till vara** för sånt som inte kommer från ett recept (märks **manuell**). Raderna
  grupperas efter avdelning i butiken; ordningen sätter du själv under **Inställningar →
  Kategoriordning i inköpslistan** (*Ordna kategorierna som du går i butiken*).
- I butiken bockar du av raderna. Avbockade hamnar under **Avbockade**, och överst står
  hur mycket som är **kvar att handla** – till slut **Allt är handlat!**

**Offline:** listan fungerar utan nät. Då står **Offline – visar listan från …** och
ändringar köas: **Ändringar väntar**, **väntar på synk**. De skickas av sig själva när
nätet är tillbaka.

**Skicka till Home Assistant** syns bara om en administratör har slagit på sänkan och
konfigurerat den. Då hamnar raderna i en todo-lista i Home Assistant (**Skickas…**, **I
Home Assistant**). **Dela/kopiera** kopierar listan som text.

---

## 6. Skafferi och skanning

**Skafferi** är vad ni har hemma. Det används för filtret **Hemma** i receptlistan och för
avdraget på inköpslistan.

- **Lägg till** manuellt, eller **Skanna** en streckkod.
- Fält: **Produktnamn** (*namnet på förpackningen*), **Ingrediens** (vad varan räknas som),
  **Mängd**, **Enhet**, **Streckkod**, **Plats** (**Kyl**, **Frys**, **Skafferi**) och
  **Bäst före**. Varor visar **Går ut snart** eller **Utgången**.
- **Använt …** drar av en del: **Hur mycket har du använt?** → **Dra av**.
- **Slut** tar bort varan och erbjuder **Lägg på inköpslistan** – *{name} är slut – lagd på
  inköpslistan*. **Ångra** finns direkt efteråt.
- Svep en rad åt vänster för snabbåtgärder.

### Skanna

**Skanna streckkod → Starta kameran** och rikta mot koden (**Ficklampa** finns). Går kameran
inte igång kan du skriva **Skriv in EAN-kod** i stället.

1. Appen frågar Open Food Facts. Hittas varan visas **Produkt**, **Märke**,
   **Ingrediensförteckning** och **Kopplad ingrediens**.
2. Står namnet på annat språk (**namn på annat språk**): skriv **Svenskt namn** – *namnet
   sparas för den här streckkoden*, så nästa skanning visar ert namn.
3. Hittas varan inte: **Produkten är inte registrerad någonstans vi kan nå.** Då finns två
   vägar – **Sök hos ICA** (bara administratörer, och bara om hushållet satt ett butiks-id)
   eller **Ange själv** med **Namn på varan** och **Ingrediens**. *Nästa skanning går direkt
   till skafferiet.*
4. **Lägg i skafferiet** med **Mängd**, **Enhet**, **Plats** och **Bäst före**. Eller
   **Slut – lägg på inköpslistan** om det var sista paketet.

Kopplingen till en **Ingrediens** är det som gör skanningen användbar: då vet appen att
"Arla Standardmjölk 3 %" är mjölk, med näringsvärden och allergener. Raden visar **räknas
som …**.

---

## 7. Dagbok

**Dagbok** visar *vad du ätit i dag, mot profilens mål*. Välj **Profil** och **Datum**, och
växla mellan **Dag** och **Vecka**.

**Dagens summa** skriver ut **{eaten} / {target} kcal** och **Kvar i dag** i klartext:
*{n} g protein kvar*, *Proteinmålet är nått*, *{n} g kolhydrater kvar till taket*, *{n} g
över målet*.

### Snabbraden

Det snabbaste sättet att logga: skriv i **Snabbrad** och tryck **Logga**.

> *Vad åt du? t.ex. 2 dl mjölk, 1 banan, 3 msk sylt*

Flera saker på en rad, med komma emellan. Appen räknar om mängden till gram och slår upp
näringsvärdet. Är det tvetydigt frågar den **Vilken menade du?**, och för sånt den inte kan
väga **Hur många gram?**. Det som inte finns i registret kan loggas som **Manuell rad
(utan näringsvärde)**.

### Andra vägar in

- Från veckoplanen: **Åt detta** på kortet **Planerat men inte loggat**.
- Från ett recept: **Logga i dagboken** / **Åt detta**, med antal portioner. Har receptet
  en **Servera med**-grupp frågar appen **Vad hade du till?** – dina val är förkryssade och
  varje kryssad rad loggas separat.
- Från skanningen: en skannad vara kan loggas direkt.
- **Lägg till** manuellt: **Sök ingrediens** eller **Manuell rad** med **Kalorier (kcal)**,
  **Protein (g)**, **Kolhydrater (g)**, **Fett (g)** och **Fiber (g)**.
- **Senast loggat** – *tryck för att logga samma sak igen*.
- **Kopiera gårdagens {måltid}** flyttar över hela gårdagens måltid.

Varje rad kan **Ändra**:s (mängd och enhet – **Gram** eller **Portioner**), flyttas till en
annan **Måltid** eller tas bort. Källan visas som **Recept**, **Skannad vara**,
**Ingrediens** eller **Egen rad**.

**Veckan** visar en stapel per dag mot dagsmålet, plus **Totalt** och **Snitt … kcal/dag**.

**Offline:** loggar du utan nät står **Loggat offline – skickas när du är online igen** och
**väntar på synk**. Raden kan sakna näringsvärden tills den synkats – *ändra den när den
synkats*.

---

## 8. Dela recept

**Dela** på receptsidan skapar en länk som **vem som helst kan öppna – utan inloggning**.

- **Skapa länk** ger adressen; **Kopiera** eller **Dela…**. Appen visar **Delad sedan …
  · {n} visningar**.
- **Återkalla länk** gör den ogiltig för gott. En ny delning får en ny länk. Arkiverade
  recept kan inte delas.

Mottagaren ser en läsbar sida med ingredienser, steg och bilder, och kan **Skriv ut /
PDF**. Sidan är inte sökbar på Google och innehåller inget annat än det receptet.

Har mottagaren en egen ReceptApp klistrar hen in länken under **Importera → Länk** –
*Mottagaren klistrar in länken under Importera → Länk i sin egen ReceptApp.* Då följer
ingredienser, grupper, steg, anteckningar och näringsvärden med exakt, utan att någon AI
behöver läsa sidan. Har hen appen installerad fungerar även **Öppna i min ReceptApp** på
delningssidan.

---

## 9. Admin

Administratörer har en egen meny: **System**, **Användare**, **Ingredienser** och
**Inloggningar**.

**Systemet** visar **Status** (version, drifttid, databas, antal recept och livsmedel),
**Livsmedelsverket** med **Synka nu**, **Backup** (**Ladda ner export** och **Importera
backup**) och **Claude-kostnad** per månad. Finns en ny version står det **En nyare version
finns** med instruktionen att köra `./update.sh` på servern. Under **Appens namn** döper
ni om instansen (1–40 tecken) – namnet slår igenom i menyn, i webbläsarfliken och på
hemskärmen. Kortet **Home Assistant** har reglaget **Skicka inköpslistan till Home
Assistant** och en steg-för-steg-hjälp (**Så konfigurerar du Home Assistant**).

**Användare** är konton som kan logga in – *en profil i hushållet behöver bara ett konto om
personen ska logga in själv*. Här syns också varje användares **Passkeys**, som kan tas
bort en och en eller allihop.

**API-nycklar** på samma sida är för integrationer som inte kan logga in med kaka, till
exempel Home Assistant och Node-RED. Välj **Behörigheter** (**Läsa veckoplan**, **Läsa
inköpslista**, **Ändra inköpslista**, **Läsa dagbokens dygnssumma**). **Kopiera nyckeln nu
– den visas aldrig igen.** Kortet **API för Home Assistant** listar exakt vad nycklarna kan
göra, med färdiga snuttar för `configuration.yaml` och curl. **Återkalla** stänger av en
nyckel direkt.

**Ingredienser** är registret bakom allt: näringsvärden, allergener, enheter och alias.
Fliken **Väntar på granskning** samlar ingredienser som importen skapat men inte kunnat
koppla. Där **Godkänn**er du, **Slå ihop med…** en befintlig, eller kopplar till
Livsmedelsverket. Rätta gärna hit: en ingrediens som är rätt kopplad ger rätt näring,
rätt allergener och rätt inköpsmängd i alla recept som använder den.

**Inloggningar** visar de senaste inloggningarna och avvisade försöken, och kortet **Din
anslutning** (**IP-adress**, **Zon** – **Hemnät** eller **Internet** – och **Läge**).
Det är sidan att titta på innan hushållet slår på zonpolicyn: står det **Lösenord räcker
härifrån** när du sitter hemma, och varnar den inte om `X-Forwarded-For`, är det rätt
inställt.

**Server** (från version 1.13) samlar integrationerna på en egen sida: Claude-nyckeln för
import från foto, PDF, Word och text, Home Assistant och ICA-butiken. I tidigare versioner
sätts de i serverns `.env` – se [README.md](README.md). Utan Claude-nyckel fungerar import
från länk, men inte från foto, PDF, Word eller inklistrad text.

Övriga hushållsinställningar ligger under **Inställningar → Administration**:
standardmåltider i veckoplanen, om importerade recept ska översättas till svenska, max
tillagningstid på vardagar, **Lägsta betyg i veckoplanen** och **Variation: dagar mellan
upprepningar**.

---

## 10. Vanliga frågor

**Varför visas vitlök som allergen?**
Appen hanterar inte bara EU:s fjorton allergener utan också sånt hushåll faktiskt reagerar
på – vitlök, lök, paprika, frukt. De ligger under **Övriga (frukt, grönsaker m.m.)** i
profilen och fungerar precis som de andra: recept som innehåller dem filtreras bort för den
profilen.

**Varför planeras aldrig min favoriträtt?**
Fyra vanliga orsaker, i den ordningen:

1. Någon av de som äter har en allergi eller ett **Ogillar** som receptet krockar med.
2. Betyget är för lågt – under **Lägsta betyg i veckoplanen** väljs receptet aldrig
   automatiskt.
3. Den lagades nyligen. Variationsregeln straffar nylagat i ungefär så många dagar som
   **Variation: dagar mellan upprepningar** säger.
4. Receptet har taggen **högtid** och läggs bara in för hand.

Är det inget av det: kolla att receptet inte är **Arkiverad**, och att tiden passar
(**Max tillagningstid på vardagar**). Du kan alltid lägga in rätten själv på en tom lucka.

**Hur byter jag lösenord eller passkey?**
Lösenord: **Inställningar → Byt lösenord**. Passkey: **Inställningar → Passkeys → Lägg till
passkey** (hemifrån), och **Ta bort** för en enhet du inte har längre. Har du tappat både
telefon och lösenord: logga in hemma med lösenord, eller be en admin nollställa kontot
under **Admin → Användare**.

**Vad händer om jag lämnar importsidan?**
Ingenting går förlorat. Importen körs på servern och hamnar i **Senaste importer** med
status **Att granska** när den är klar. Öppna den när du har tid.

**Varför står det "Ofullständig" på näringsvärdena?**
Näringen räknas från de länkade ingredienserna. Är några rader okopplade blir täckningen
lägre; under 50 % visas inga makron alls. Koppla raderna i redigeraren, eller be en admin
ta hand om dem under **Admin → Ingredienser**.

**Kameran startar inte.**
Kameran kräver att appen nås över `https://`. Fungerar den hemma men inte borta – eller
inte alls – be den som driftar instansen läsa avsnittet *Nå appen utanför hemmet* i
[README.md](README.md).

# Crumblr Trainer

De Static-modus is de eenvoudige testversie van de Trainer. Het dashboard heeft één vaste
workflow: upload één strategie-ZIP met de `.mq5`, `.set` en
`trainer-strategy.json`, upload één historische candle-CSV en start daarna de
autonome verbeterloop.

De strategie en dataset worden server-side vastgezet en blijven na het
vernieuwen van de pagina beschikbaar zolang dezelfde gratis Render-instance
actief blijft. Na een restart of nieuwe deployment moeten de twee bestanden
opnieuw worden geüpload. De interface toont uitsluitend de static Trainer; de
overige onderzoeksmodi en MT5-Workerbediening zijn verborgen.

De optionele Dynamic-laag gebruikt Groq voor onderzoeksbesluiten en Cloudflare
Workers AI voor onafhankelijke review. Een deterministische Controller blijft
de harde poort. Zonder AI-variabelen blijft de bestaande Static-modus actief.
Zie [docs/STANDALONE_DYNAMIC_BUILD.md](docs/STANDALONE_DYNAMIC_BUILD.md).

De curve begint bij de baseline en voegt elke afgeronde test toe. Profit,
verbetering en drawdown blijven daarnaast numeriek zichtbaar. De Trainer heeft
geen handelsbevoegdheid en kan een kandidaat niet zelfstandig live zetten.

## Onderliggende researchkern

Dit is de eerste lokale versie van de Crumblr Trainer: een begrensde,
journal-first researchkern voor tradingstrategieën. De code plaatst geen live
orders, koppelt nog niet met Trader of een AI-agent en promoveert niets
automatisch naar productie.

De kern ondersteunt:

- frozen strategy-versies met bron-, configuratie- en MT5-omgevinghashes;
- drie strikt gescheiden researchmodi;
- campagnes met een maximumaantal experimenten, varianten en runtime;
- een echte MetaTrader 5 Strategy Tester-runner;
- een duurzame takenrij voor een research-only Windows MT5 Worker;
- een downloadbaar handmatig MT5-testpakket met veilige resultaat-upload;
- directe historische baseline-upload voor bestaande MT5-CSV- en JSON-data;
- een autonome, begrensde campagnecyclus die na één startactie alle toegestane
  MT5-tests tot het ingestelde experimentbudget uitvoert;
- automatische planning van de volgende challenger na ieder Worker-resultaat;
- automatische vergelijking van iedere challenger met de frozen baseline en
  een eindcheckpoint met de beste researchkandidaat;
- een live procesdiagram voor hypothese, challenger, MT5-test en besluit;
- deterministische parsing van trade-level R-multiples;
- expectancy, profit factor, drawdown, jaarstabiliteit, chronologische segmenten
  en expliciete walk-forwardresultaten;
- deterministische bootstrapvergelijking met multiple-testing-context;
- statussen die uitsluitend door de Statistical Supervisor worden bepaald;
- exacte en functionele duplicate-detectie;
- permanente positieve én negatieve lessons;
- een SQLite-register plus append-only JSONL-audit trail;
- gecontroleerde CamoFox-browserresearch in MODE 2 en MODE 3;
- een beveiligde JSON-API voor externe clients;
- dashboard-upload voor bestaande MT5-strategieën met automatische herkenning
  van naam, versie, instrument, timeframe en sessie;
- lokale Docker Compose- en Render-deployment;
- een lokale CLI en kleine Python-interfaces voor latere agentkoppelingen.

De dashboard-ready API biedt nu deze drie keuzes:

1. Bestaande strategie optimaliseren.
2. Data van de Crumblr-agent analyseren en verbeteren.
3. Een nieuwe strategie bedenken en daarna met MT5 testen.

De exacte werking en gegevensstromen staan in
[docs/TRAINER_MODES.md](docs/TRAINER_MODES.md).

## Bewuste grenzen van deze versie

Deze versie bevat een responsive webdashboard op de root-URL. Een bestaande
strategie kan als MT5-bestand of ZIP worden toegevoegd; de Trainer leest de
metadata, bewaart een frozen kopie en toont de strategie daarna in MODE 1. Het
dashboard gebruikt dezelfde beveiligde API en bewaart de API-sleutel alleen in
de actieve browsertab. Na een geldige baseline start `Start automatische reeks`
een begrensde campagne. De Trainer plant één veilige variatie tegelijk, de
Windows Worker voert de MT5-test uit, de Trainer vergelijkt het resultaat en
zet zelfstandig de volgende taak klaar. Het diagram ververst iedere vijf
seconden en toont de voortgang. De handmatige pakketroute blijft beschikbaar
als diagnosefallback. Een LLM, automatische Crumblr-koppeling en live-promotie
zijn nog niet aanwezig.
CamoFox 1.14.0 is lokaal gevendored en wordt in de Docker-container als
afgeschermde loopbackservice gestart. Latere adapters kunnen aansluiten op
`TrainerService` en de protocols in `ports.py`, zonder de statistische
researchkern te omzeilen.

Render draait op Linux en kan daarom niet rechtstreeks de Windows-versie van
MetaTrader 5 uitvoeren. Op Render orkestreert de Trainer de volledige campagne.
De meegeleverde Windows Worker hoeft één keer te worden gestart, haalt daarna
iedere taak beveiligd op, gebruikt uitsluitend de Strategy Tester en stuurt de
auditresultaten terug. Na ieder resultaat zet Render automatisch de volgende
test klaar. Een herstart van Render of de Worker verliest een wachtende taak
niet.

De hoogst automatisch bereikbare status is `RESEARCH_PROMISING`.
`SEALED_VALIDATION`, `PAPER_LIVE` en `LIVE_ELIGIBLE` vereisen later aparte
workflows en checkpoints.

## Snel starten

### Aanbevolen lokale Windows-versie

Dubbelklik in de repository op `Start-Crumblr-Trainer.cmd`. De launcher voert
eerst een lokale controle uit en start daarna in één keer de Trainer API, het
dashboard op `http://127.0.0.1:8877`, de Groq-onderzoeksagent met Cloudflare
Workers AI als reviewer en de research-only Windows MT5-worker.

Bij de eerste start vraagt de launcher om de twee API-sleutels en het
Cloudflare Account ID. Sleutels worden met Windows DPAPI versleuteld en zijn
alleen leesbaar voor hetzelfde Windows-account op dezelfde computer. De lokale
dashboardverbinding heeft geen Render API-key nodig.

Omdat Windows `Documenten` in een bedrijfsomgeving naar een netwerkschijf kan
omleiden, gebruikt deze starter bewust de echte lokale gebruikersmap:

```text
%LOCALAPPDATA%\Crumblr Trainer Data
```

De code kan daardoor worden bijgewerkt zonder strategie, dataset, campagnes of
journal te verwijderen. Na iedere afgeronde historische test schrijft de
Trainer tevens `backups\latest.sqlite3`. Als de hoofddatabase ontbreekt, wordt
deze checkpoint bij de volgende start automatisch teruggezet. Logbestanden
staan in `logs\trainer-output.log` en `logs\trainer-error.log`.

Voor een nieuwe lokale campagne is na de candle-CSV een eenmalige MT5-controle
verplicht. Upload daarvoor de audit-CSV van exact dezelfde strategie, inputs,
symbol, timeframe en periode. De Trainer vergelijkt trade-aantal, totale R,
expectancy en drawdown. Bij een te grote afwijking start optimalisatie niet.

Render blijft bruikbaar als tijdelijke demonstratie, maar is niet langer de
primaire opslag voor handmatige Trainer-V1-campagnes.

Python 3.11 of nieuwer is voldoende; de kern heeft geen externe dependencies.

```powershell
python -m crumblr_trainer --home .\runtime init

python -m crumblr_trainer --home .\runtime strategy-add `
  --id silver-bullet `
  --name "Silver Bullet" `
  --version 5.0 `
  --instrument EURUSD `
  --timeframe M5 `
  --session NYAM `
  --source .\examples\strategy.md `
  --strategy-config '{"risk_pct": 0.5}'

python -m crumblr_trainer --home .\runtime campaign-create `
  --id CAM-DEMO `
  --strategy silver-bullet@5.0 `
  --mode MODE_1 `
  --objective "Optimaliseer uitsluitend TP" `
  --allow TP `
  --max-experiments 3 `
  --max-variants 3 `
  --max-runtime-minutes 60 `
  --dataset '{"from":"2022-01-01","to":"2024-12-31"}'

python -m crumblr_trainer --home .\runtime baseline-record `
  --campaign CAM-DEMO `
  --result .\examples\baseline-result.json
```

Daarna kan een experiment worden gepland en geëvalueerd:

```powershell
python -m crumblr_trainer --home .\runtime experiment-plan `
  --id EXP-DEMO `
  --campaign CAM-DEMO `
  --hypothesis "Een 1.5R TP verbetert stabiele expectancy" `
  --reasoning "De frozen baseline sluit winnaars relatief vroeg" `
  --expected-effect "Hogere expectancy zonder materieel slechtere drawdown" `
  --change-type TP `
  --exact-change "Wijzig TP van 1.25R naar 1.5R" `
  --parameters '{"tp_r":1.5}' `
  --tag "#EURUSD" `
  --tag "#Exit"

python -m crumblr_trainer --home .\runtime result-record `
  --experiment EXP-DEMO `
  --result .\examples\challenger-result.json

python -m crumblr_trainer --home .\runtime campaign-complete `
  --campaign CAM-DEMO
```

Gebruik `journal-search break-even`, `strategy-list` en `overview` om het
opgebouwde geheugen te lezen.

## CamoFox-browserresearch

Start lokaal de Docker-container of een aparte CamoFox-server op poort 9377.
Daarna kan MODE 2/3 een externe bron vastleggen:

```powershell
$env:CAMOFOX_ACCESS_KEY = "dezelfde-sleutel-als-de-server"

python -m crumblr_trainer --home .\runtime research-capture `
  --campaign CAM-RESEARCH `
  --url "https://example.com/research" `
  --source-name "Example Research" `
  --summary "De bron bespreekt een alternatieve bevestiging." `
  --hypothesis "Deze bevestiging kan false entries verminderen." `
  --component "structure confirmation" `
  --tag "#MSS"
```

De browserbron wordt nooit gezien als bewijs van edge. De Trainer bewaart de
snapshot, URL, datum, samenvatting en afgeleide hypothese; daarna blijft een
MT5-validatie verplicht. MODE 1 kan de browser niet gebruiken.

## Docker en Render

Voor lokaal Docker-gebruik:

```powershell
Copy-Item .env.example .env
# Vervang beide voorbeeldsleutels in .env.
docker compose up --build
```

De API draait daarna op `http://localhost:8765`. Voor Render staat een complete
Blueprint in `render.yaml`. Zie
[`docs/RENDER_DEPLOY.md`](docs/RENDER_DEPLOY.md) voor de stappen en
[`docs/API.md`](docs/API.md) voor de endpoints.

Dezelfde container ondersteunt ook twee losse gratis Render-testservices:
één voor de Trainer API en één voor CamoFox. Lokaal en bij de betaalde
productie-Blueprint blijven beide standaard samen draaien.

## Backtestdata en lokale strategie-engine

Lokale historische research gebruikt geen algemene vervangende strategie meer.
Upload de oorspronkelijke strategie samen met een expliciete
`trainer-strategy.json`; zie `examples/trainer-strategy.json`. Zonder dit
uitvoerbare contract weigert de Trainer de lokale baseline fail-closed.

Het dashboard kan `CrumblrHistoryExporter.mq5` downloaden. Dit script exporteert
OHLC, tickvolume, spread en real volume naar de gedeelde MT5-map. Daarna kan de
CSV als bevroren dataset worden geüpload. De Trainer gebruikt development,
afgesloten OOS en een sealed holdout en bewaart trade-level MFE/MAE en
exitredenen.

MT5 is de authoritative engine, maar een standaard MT5 HTML/XML-report bevat
niet alle informatie die de supervisor veilig nodig heeft. De EA moet daarom
ook een audit-CSV schrijven met minimaal één kolom:

```text
r_multiple
```

Aanbevolen zijn daarnaast:

```text
trade_id,entry_time,exit_time,pnl,r_multiple,commission,swap,transaction_costs_included,walk_forward_fold
```

Voor development/replay accepteert de parser een genormaliseerd JSON-bestand.
De volledige contractbeschrijving staat in
[`docs/RESULT_CONTRACT.md`](docs/RESULT_CONTRACT.md).

## MT5 uitvoeren

De lokaal aangetroffen standaardlocatie is
`C:\Program Files\MetaTrader 5\terminal64.exe`. De runner schrijft per
experiment een geïsoleerde `.ini` en `.set`, forceert
`Optimization=0`, `Visual=0` en `ShutdownTerminal=1`, en start alleen de
Strategy Tester. Er bestaat geen live-orderinterface in dit project.

Voor normaal gebruik met het Render-dashboard is de Windows Worker de
standaardroute. Open in MT5 eerst **File > Open Data Folder** en gebruik de map
`MQL5\Experts` als `ExpertsDirectory`:

```powershell
.\scripts\run-mt5-worker.ps1 `
  -Terminal "C:\Program Files\MetaTrader 5\terminal64.exe" `
  -ExpertsDirectory "C:\pad\uit\MT5\MQL5\Experts"
```

Het script vraagt om dezelfde Trainer API-sleutel die in het dashboard wordt
gebruikt. Laat dit venster open en klik daarna één keer op **Start automatische
reeks**. De Worker werkt vervolgens het ingestelde campagnebudget af. Bij een
MQ5-bron injecteert de Worker uitsluitend in zijn tijdelijke researchkopie de
auditcollector; de frozen bron blijft ongewijzigd. Een EX5-only strategie moet
zelf het audit-CSV-contract ondersteunen. Zie
[`docs/MT5_WORKER.md`](docs/MT5_WORKER.md) voor de korte installatie-uitleg.

### Handmatige nood-/diagnoseroute via het dashboard

Voor een eerste functionele proef is de doorlopende Worker niet verplicht.
Upload een MQ5-strategie, maak een campagne en kies **Testpakket downloaden**.
De ZIP bevat een instrumented researchkopie van de MQ5-bron, een audit-helper,
een SET-bestand en `LEES-MIJ.txt`. Na de Strategy Tester-run upload je het
gemaakte CSV-bestand met **Resultaat uploaden**. De oorspronkelijke frozen
strategie wordt hierbij niet aangepast.

De helper berekent R-multiples met één vast geldbedrag als risico-aanname. Het
bedrag staat zichtbaar in het pakket en kan in de MT5 Inputs worden aangepast.
Deze handmatige route vereist MQ5-broncode; een EX5-bestand kan niet veilig van
de audit-helper worden voorzien.

```powershell
python -m crumblr_trainer --home .\runtime mt5-run `
  --experiment EXP-DEMO `
  --expert "Crumblr\SilverBullet.ex5" `
  --symbol EURUSD `
  --period M5 `
  --from-date 2022-01-01 `
  --to-date 2024-12-31 `
  --parameters '{"tp_r":1.5}' `
  --audit "C:\pad\naar\EXP-DEMO-audit.csv"
```

## Testen

```powershell
python -m unittest discover -s tests -v
```

De tests gebruiken tijdelijke directories en starten MT5 niet.

## Projectstructuur

```text
crumblr_trainer/
  service.py       stabiele lokale façade en invarianten
  browser.py       begrensde CamoFox REST-client
  api.py           beveiligde HTTP-API
  storage.py       registries en append-only journal
  mt5.py           Strategy Tester-adapter
  worker.py        research-only Windows MT5-takenwerker
  results.py       MT5/audit/JSON parsing
  statistics.py    deterministische supervisor
  duplicates.py    duplicate-hypotheses
  ports.py         uitsluitend grenzen voor latere adapters
  cli.py           lokale bediening
tests/              end-to-end en unit tests
examples/           replaybare demonstratie
docs/               contracten en architectuur
deploy/             gecombineerde Trainer/CamoFox-startconfiguratie
vendor/             ongewijzigde CamoFox 1.14.0-bron
Dockerfile          lokale en Render-container
render.yaml         Render Blueprint
```

Het vastgestelde stappenplan en de gefaseerde route naar Trainer V1.0 staan in
[`docs/TRAINER_V1_JOURNAL.md`](docs/TRAINER_V1_JOURNAL.md).

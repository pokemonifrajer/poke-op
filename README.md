# Harbor City — Roblox open-world alpha

První skutečný projekt hry v Luau: otevřená čtvrť Harbor City s policií, vězením, auty, třemi loupežemi, nemovitostmi a podniky. **Verze 0.3.0-alpha nebyla spuštěna v Roblox Studiu.** Zdrojové, ekonomické, simulované servisní a XML kontroly prošly; fyzika, multiplayer a načtení místa čekají na engine test.

## Otevření bez programování

Otevři dodaný soubor **HarborCity.rbxlx** ve Studiu přes **File → Open from File** a stiskni **Play**. Mapa i všechny skripty jsou uvnitř. Nemusíš je ručně kopírovat, instalovat plugin ani hledat modely.

Pokud soubor bereš z GitHubu, v **Actions → Verify and build → úspěšný běh → Artifacts → HarborCity-place** stáhni archiv a rozbal ho. Artefakt se objeví až po úspěšném běhu. Nebo může vývojář sestavit soubor příkazem `python3 tools/build_place.py`; žádné další Python balíčky nejsou potřeba.

## Co je implementováno

- Ručně rozvržené město s více než 2 700 díly a čtvrtěmi kolem centra, přístavu, průmyslu, školy, Westwoodu a North Hill. Banka, klenotnictví, sklady, škola, obchody a tři obyvatelné domy mají interiéry; vysoké budovy jsou kulisy. Mapa v telefonu odpovídá rozmístění čtvrtí.
- Šest původních vozů: kompaktní auto, sportovní vůz, SUV, muscle car, dodávka a policejní vůz. Server řídí jízdní model, odlišné velikosti, poškození a opravy, světla, blinkry, majáky, výběr barvy a vlastnictví.
- Tři serverem řízené loupeže: banka, klenotnictví a obrněná dodávka. Každá má vlastní místo, časovanou minihru, alarm, kořist, požadovanou dobu úniku, odměnu a cooldown. U banky se může k přípravě připojit až čtyřčlenná posádka.
- Hledanost 1–5, čtyři pěší NPC policisté a deset civilních NPC. Hlídky mají stavy hlídkování / pronásledování / pátrání po poslední známé poloze, kontrolují dohled přes překážky a hráče zatýkají po časovaném zadržení. Více hvězd zvyšuje dosah a počet hlídek.
- Policejní role hráče, policejní tablet a seznam hledaných NPC i hráčů, opakované výjezdy na tři podezřelé NPC, pronásledování, pouta jako nástroj i klávesa F, přerušitelné třísekundové poutání, převedení do vazby, odměna za zatčení, statistika zásahů, služební výplata a služební auto.
- Vězení: cely, jídelna, dvůr, věže, časovaný trest, vězeňské barvy oblečení; dílna zkracující trest, jídlo obnovující zdraví, útěk pomocí karty z prádelny, odtokovým tunelem nebo ventilační chodbou. Policisté mohou otevřít fyzickou bránu na osm sekund; vězeň, který proklouzne ven, je znovu hledaný. Reset ani odpojení nesmažou uložený trest.
- Legální rozvoz, hotovost a bankovní účet, vklady/výběry a historie transakcí. Hráč může koupit tři domy s oddělenými světovými vstupy a interiéry a dvě firmy. Firmy připisují výnos do banky každé tři minuty aktivního hraní. Vlastnictví se ukládá; starší alfa profily si zachovají koupenou Marinu.
- Vlastní firma: registrace v Harbor Commerce za $2 500 / $3 500, výběr jedné ze šesti značek a oboru doprava / autoservis. Aktivní zakázky s převzetím a předáním materiálu, firemní pokladna, výběr zisku, tři úrovně rozšíření, ochrana před dvojím vyplacením a ukládání postupu. Název se sestavuje z připravených voleb; libovolný text se nepřijímá.
- Hlavní menu s kamerou nad skutečným městem, červenými akcenty a tmavými panely. Široká mapa a policejní tablet, autosalon s otáčivým 3D modelem sdílejícím modelování skutečných aut, upravené karoserie, pobřežní palmy, skleněné věže, výlohy, osvětlené interiéry a obchodní centrum.
- Telefon s mapou a navigací, garáží, bankou, prací, policejní databází, správou domů, správou firem a nastavením. HUD, zdraví, rychloměr, minimapa, české texty, klávesnice a dotykové ovládání.
- Den/noc, mlha, místní dešťové částice, pouliční světla, semafory se třemi stavy, deset animovaných civilních chodců, čtyři pěší policejní hlídky a dekorativní silniční auta. Hráčovo auto automaticky zastavuje na červenou u hlavních křižovatek.
- Kontrola odměn a cen na serveru, kontroly vzdálenosti a dohledu, časování podržení interakcí, omezení četnosti požadavků, hrubá detekce nepovolených přesunů a DataStore UpdateAsync se session lockem.

## Hranice této alfy

Tohle není dokončená náhrada GTA ani titul připravený na veřejný provoz. Modely jsou tvořené přímo z Roblox dílů; nejsou to fotorealistické importované modely. Plné posouzení vizuálu vyžaduje Studio.

- Fyzika aut je jednoduchá, s jedním podpůrným paprskem, nikoli čtyřbodový podvozek. Chování při nárazech a mobilní řízení se musí otestovat.
- Policejní NPC jsou **pěší**, neřídí auta a nepoužívají vrtulník. Civilní dopravní auta jsou dekorativní, bez kolizí. Provoz hráčů u červené zastavuje jen na hlavních vytvořených křižovatkách.
- Vězeňské věže jsou prostředí, nemají aktivní strážce ani kamerovou konzoli. Útěk přes servisní dveře používá serverem ověřený přesun za zeď. NPC podezřelí jsou po zatčení automaticky přesunuti do vazby; ruční eskorty ani převozy nejsou implementovány.
- Domy mají oddělené fyzické vchody, místnosti a vlastnictví. Jde o společný světový prostor s kontrolou vstupu, nikoli o soukromé instancované servery. Pozvánky se zamykají, ale dveře nemají dynamický fyzický zámek.
- Výnosy firem se načítají během aktivní herní relace; offline zisk se nepřičítá. Vlastní firmy mají aktivní zakázky a úrovně; nemají nábor zaměstnanců ani offline produkci.
- Nejsou zde zbraně, gore, zvuky motorů/sirén, policejní radar a pokuty, SMS, kontakty, obchod s oblečením, vlastní animace postavy, motorky ani vrtulníky. Tyto funkce zůstávají dalšími vývojovými úkoly.
- Zabezpečení je vývojový základ, ne dokončený audit proti exploitům. Fyzika hráčovy postavy pořád vyžaduje engine test a zátěžové ověření.
- Není potvrzený výkon ani bezchybnost skutečného ukládání. Při chybě ukládání se session uzamkne a hráč odpojí; změny od posledního úspěšného uložení se mohou ztratit.

Další rozšiřování má následovat až po dokončení [testovacího postupu](docs/TESTOVANI.md).

## Ovládání

| Akce | Ovládání |
|---|---|
| Pohyb / jízda | WASD / dotykový ovladač Roblox |
| Interakce / nastoupení | E / tlačítko interakce |
| Vystoupení | Mezerník / Vystoupit |
| Telefon / mapa | P / M |
| Policejní pouta | F / Pouta / nástroj Pouta |
| Běh | Shift / Běh |
| Brzda | Ctrl / Brzda |
| Světla / výstražné blinkry / majáky | L / Q / B |

## Testy a sestavení

```sh
python3 tools/build_place.py
luatex --luaonly tests/syntax.lua
luatex --luaonly tests/domain.lua
luatex --luaonly tests/services.lua
luatex --luaonly tests/expansion.lua
python3 tests/place.py
```

Luau zdroje používají podmnožinu syntakticky kompatibilní s Lua 5.3/5.4. Offline parser nemůže zkontrolovat platnost všech Roblox API a není náhradou Studio testu.

`default.project.json` je volitelný Rojo **code-only** projekt. **Nevytváří město.** Pro kompletní místo použij Python builder; nepřepisuj rozpracované Studio změny novým buildem bez zálohy.

## Architektura

`src/shared` obsahuje konfiguraci a čistou logiku ekonomiky. `src/server` obsahuje data, ochranu požadavků, vozidla, loupeže, vězení, NPC, provoz a propojení služeb. `src/client` zajišťuje pouze UI, ovládací vstupy a lokální efekty. Klient neurčuje odměny, ceny ani výsledek zatčení. `tools/build_place.py` vytváří mapu a vkládá zdroje do příslušných služeb v `.rbxlx`.

Ve Studiu je `Config.StudioPersistence = false`. V publikované hře je ukládání zapnuté a vyžaduje úspěšné načtení profilu. Není zapnuté HTTP ani externí načítání skriptů; projekt nepoužívá free modely či klíče API.

## Nahrání na Roblox

1. Nejprve proveď Studio test a oprav nalezené chyby.
2. Ve svém přihlášeném Studiu zvol **File → Publish to Roblox**, vytvoř novou hru a ponech ji nejdřív soukromou. Tohle nahraje herní místo, zatímco GitHub spravuje zdrojový kód.
3. Ověř hru i ukládání v Roblox klientovi a dokonči multiplayer testy.
4. V Creator Dashboardu projdi obsahový dotazník a požadavky pro zamýšlené publikum. Změna Audience na Public je samostatný krok a závisí na způsobilosti účtu. Roblox může vyžadovat ověření účtu a další podmínky podle publika; samotný soubor hry jejich splnění nezajišťuje. Údaje vyplň pravdivě; pokud potřebuješ pomoc rodiče, proveď nastavení s ním.

Aktuální oficiální návod: [Create and publish games and places](https://create.roblox.com/docs/production/publishing/publish-games-and-places).

Technické podklady: [bezpečnost klient/server](https://create.roblox.com/docs/scripting/security/client-server-boundary), [DataStore a session locking](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing), [VehicleSeat](https://create.roblox.com/docs/reference/engine/classes/VehicleSeat), [LinearVelocity](https://create.roblox.com/docs/reference/engine/classes/LinearVelocity). Zkontrolováno při přípravě projektu 10. 10. 2026.

## Poznámky k verzi 0.3

Nový soubor otevíráš stejně jako předchozí verzi. Sestavení opravuje hranice světa, které omezovaly jižní kampus a průmyslovou oblast. Starší uložené peníze, auta, domy i franšízy zůstávají kompatibilní. Přidává se `Company` a `Arrests`, bez resetu stávajícího DataStore.

Použitá oficiální API dokumentace: [ViewportFrame](https://create.roblox.com/docs/reference/engine/classes/ViewportFrame), [WorldModel](https://create.roblox.com/docs/reference/engine/classes/WorldModel).

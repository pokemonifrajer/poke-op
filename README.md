# Harbor City — Roblox open-world alpha

První skutečný projekt hry v Luau: jedna městská čtvrť, řiditelná auta, banka, policie a vězení. **Verze 0.1.0-alpha nebyla spuštěna v Roblox Studiu.** Zdrojové a simulované testy prošly; jízdní fyzika, multiplayer a import místa čekají na engine test.

## Otevření bez programování

Otevři dodaný soubor **HarborCity.rbxlx** ve Studiu přes **File → Open from File** a stiskni **Play**. Mapa i všechny skripty jsou uvnitř. Nemusíš je ručně kopírovat, instalovat plugin ani hledat modely.

Pokud soubor bereš z GitHubu, v **Actions → Verify and build → úspěšný běh → Artifacts → HarborCity-place** stáhni archiv a rozbal ho. Artefakt se objeví až po úspěšném běhu. Nebo může vývojář sestavit soubor příkazem `python3 tools/build_place.py`; žádné další Python balíčky nejsou potřeba.

## Co je implementováno

- Ručně rozvržená, procedurálně sestavená čtvrť s přibližně 1 900 díly: náměstí, banka s interiérem a trezorem, policejní stanice, garáž, depo, přístav, obytná budova a Northgate vězení. Interiéry mají skutečné průchody; ostatní budovy jsou kulisy.
- Tři původní vozy: Aster Compact, Vela GT a Sentinel Patrol. Server řídí jednoduchý jízdní model, poškození a opravu, světla, výstražné blinkry, majáky, výběr barvy a vlastnictví.
- Bankovní mise: serverové pořadí symbolů, časový zámek, alarm, taška, únik do přístavu, výplata, cooldown a zrušení při selhání. Během hacku se mohou u terminálu připojit až čtyři hráči.
- Hledanost 1–5, čtyři pěší NPC policisté se stavy hlídkování / pronásledování / hledání na posledním známém místě, dohled přes překážky a časované zatčení. Více hvězd zvyšuje dosah a počet zapojených hlídek.
- Policejní role hráče, serverový seznam hledaných, poutání na krátkou vzdálenost, odměna za zatčení, služební výplata a služební auto.
- Vězení: cely, jídelna, dvůr, věže, časovaný trest, vězeňské barvy oblečení; útěk pomocí karty z prádelny nebo odtokovým tunelem. Reset ani odpojení nesmažou uložený trest.
- Legální rozvoz zásilek, hotovost a bankovní účet, vklady/výběry, historie transakcí. Peníze, auta, barvy, vlastnictví bytu, hledanost a trest jsou součástí datového profilu.
- Telefon s mapou a navigací, garáží, bankou, zaměstnáním, policejní databází, bytem a nastavením. HUD, zdraví, rychloměr, minimapa, české texty, klávesnice a dotykové ovládání.
- Den/noc, mlha a místní dešťové částice, pouliční světla, animovaní chodci a dekorativní silniční provoz, který zastavuje u křižovatek.
- Kontrola odměn a cen na serveru, kontroly vzdálenosti a dohledu, časování podržení interakcí, omezení četnosti požadavků, hrubá detekce nepovolených přesunů a DataStore UpdateAsync se session lockem.

## Hranice této alfy

Tohle není dokončená náhrada GTA ani titul připravený na veřejný provoz. Modely jsou tvořené přímo z Roblox dílů; nejsou to fotorealistické importované modely. Plné posouzení vizuálu vyžaduje Studio.

- Fyzika aut je jednoduchá, s jedním podpůrným paprskem, nikoli čtyřbodový podvozek. Chování při nárazech a mobilní řízení se musí otestovat.
- Policejní NPC jsou **pěší**, neřídí auta a nepoužívají vrtulník. Civilní dopravní auta jsou dekorativní, bez kolizí. Světelný cyklus semaforů je zjednodušený.
- Vězeňské věže jsou prostředí, nemají aktivní strážce ani kamerovou konzoli. Útěk přes servisní dveře používá serverem ověřený přesun za zeď. Převozy, ventilace a kooperativní útěk nejsou implementovány.
- Marina je v této alfě **společný přístupný interiér**, ne oddělený soukromý byt. Vlastnictví a pozvánky fungují jako datový systém; zamykání znamená zamknutí pozvánek, nikoli fyzické dveře. Tento doplňkový systém potřebuje před rozšířením soukromé instance.
- Nejsou zde zbraně, násilné efekty, zvuky motorů/sirén, policejní radar a pokuty, SMS, kontakty, obchod s oblečením, vlastní animace postavy, motorky, vrtulníky, rozsáhlé předměstí ani další loupeže. Tlačítka na tyto funkce nejsou předstíraná.
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
| Běh | Shift / Běh |
| Brzda | Ctrl / Brzda |
| Světla / výstražné blinkry / majáky | L / Q / B |

## Testy a sestavení

```sh
python3 tools/build_place.py
lua tests/syntax.lua
lua tests/domain.lua
lua tests/services.lua
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

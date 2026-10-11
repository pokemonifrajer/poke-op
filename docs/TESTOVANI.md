# Testování Harbor City 0.3.0-alpha

## Co bylo ověřeno mimo Roblox

- Syntaxe všech 12 skriptů v kompatibilní podmnožině Lua/Luau (LuaTeX Lua parser).
- 22 testů čisté herní logiky: bankovní převody, ochrana proti opakování odměny, vozidla, nákup tří domů a dvou firem, výnosy, hledanost a tresty.
- 16 testů služeb s výslovně simulovaným rozhraním Roblox: zámek uloženého profilu, chyby načítání a ukládání, staré alfa profily, všechny tři loupeže, timeout a odpojení.
- Struktura XML, jedinečné reference objektů, umístění skriptů, shoda vložených zdrojů s repozitářem, všechny používané interakční body.
- Kontrola všech 45 povinných interakčních markerů, semaforů se třemi lampami, vstupů k domům, letištního terminálu, hlavních budov a průchodnosti tunelu i nové ventilační chodby.

Tohle **nejsou testy v Roblox enginu**. Fyzika, skutečná replikace, pathfinding, načtení XML ve Studiu, mobilní ovládání a živé DataStore API zůstávají neověřené.

## Nejmenší test ve tvém Studiu

1. Otevři `HarborCity.rbxlx` přes **File → Open from File**.
2. Zobraz **Output** a spusť **Play / F5**. V Output má být `[Harbor City] Alpha initialized` a nemají být červené chyby. Pokud se chyba objeví, pošli její celý text nebo screenshot.
3. Stiskni **Vstoupit do města**. V telefonu otevři Garáž a nastav navigaci k výdeji. U recepce stiskni **E**, vyzvedni **Aster Compact**, u sedadla stiskni **E** a zkus **WASD**. Mezerník nebo tlačítko Vystoupit opustí auto.
4. U Civic Bank vstup hlavním vchodem. Na terminálu podrž E. Zapamatuj si čtyři symboly, počkej 10 sekund a zopakuj pořadí. Po alarmu vstup do trezoru a podrž E u tašky 5 sekund.
5. V telefonu otevři Mapu, klikni na Přístav a dovez tašku k tyrkysovému bodu QUAY 04. Po odevzdání má přibýt $3 800 jen jednou.
6. Nech se dostihnout policií: zůstaň stát v její blízkosti 3 sekundy. Ověř přesun do vězení, čas trestu a cesty ven: prádelna → karta → servisní východ; odtok → 3× uvolnit mříž → podzemní chodba → východ; dílna → nástroj → ventilace u cel → průchod → východ.
7. Otestuj přirozené skončení trestu, reset postavy během trestu a zrušení loupeže po resetu.

8. U telefonu otevři **Práce** a vyzkoušej klenotnictví i obrněnou dodávku. Pro každou misi začni u jejího označeného místa, vyřeš minihru, vezmi kořist a dovez ji do přístavu.
9. V telefonu otevři **Domy**, naviguj se postupně k Marině, Westwoodu a North Hill. U recepce kup dům, použij jeho vchod a ověř, že jiný účet bez vlastnictví dovnitř nemůže.
10. Otevři **Firmy → Franšízy**, naviguj se k Harbor Express a Autohausu a kup podnik. Po třech minutách ověř připsaný příjem v bance a v historii transakcí.
11. Při jízdě dojeď ke křižovatce během červené a ověř zastavení. V každém okně 12 s se střídá směr; poslední 3 s svítí žlutá.
12. Projdi pěšky centrum, školní kampus, průmysl, letiště a přístav. Ověř, že městští chodci a hlídky postupují po chodnících bez dlouhého zasekávání.

## Multiplayer a ukládání — před veřejným vydáním

Použij Studio testovací režim **Server & Clients** se dvěma hráči. Jeden je civilista, druhý vstoupí do služby u policejní přepážky. Ověř společnou loupež, zatčení, oddělené účty, obsazené parkoviště, odpojení řidiče a odpojení vedoucího loupeže. Následně vyzkoušej čtyři klienty a případně zatížení vyšším počtem hráčů. Změř snímkovou frekvenci a síťový přenos; v této verzi nejsou naměřené hodnoty.

V běžném Studiu je ukládání záměrně vypnuté. Testovací prostředí může používat nové účty při každém spuštění. **Nezapínej StudioPersistence proti ostrým datům.**

Po soukromém nahrání spusť hru z Roblox klienta na vlastníkově účtu, vydělej peníze, odejdi a znovu se připoj. Ověř návrat peněz a vlastněných aut. U živé hry se profil při chybě načítání nesmí nahradit prázdným profilem. Při ztrátě ukládání se hráč odpojí; poslední neuložené změny se mohou ztratit.

Před zpřístupněním dalším lidem zkontroluj také podmínky Audience v Creator Dashboardu. Soukromý upload sám o sobě není veřejné vydání.

## Nové ověření 0.3

Offline navíc prošlo 14 testů zakládání a rozvoje firmy, oddělené firemní pokladny, časování zakázek, dvojího vyplacení, souběžného poutání, přerušení poutání, zatčení NPC i hráče, vězeňské práce, ventilace a časovaného zavření brány. Celkem 52 testů domény a služeb, kontrola syntaxe 15 zdrojů a kontrola struktury místa. Mockované hranice engine nepokrývají reálný pohyb NPC, rendering, fyziku ani síťové události.

Ve Studiu ještě proveď:

1. V hlavním menu ověř pohyb kamery a tlačítka Vstoupit, Mapa a Nastavení. V garáži přepni všech šest vozů, porovnej náhled se skutečným autem a otestuj lak.
2. Na stanici otevři tablet a nastup do služby. Přijmi výjezd, sleduj červenou značku na mapě, doběhni NPC a stiskni F. Zůstaň v dosahu 3 s; NPC se má přesunout do Northgate a připíše se $400. Zkoušej i vzdálení / přerušení a zatýkání hráče druhým klientem.
3. V telefonu Firmy vyber značku a obor; naviguj k Harbor Commerce. Založ firmu. Přijmi zakázku, vyzvedni materiál, odvez jej na cílové místo a drž E. Předání je možné nejdřív 22 s po vyzvednutí. Zisk patří do firemní pokladny, ručním výběrem do banky. Zakázku nelze vyplatit dvakrát.
4. Ve vězení vyzkoušej dílnu, jídelnu, ventilaci i původní útěky. Práce zkracuje trest dvakrát o 8 s za pobyt. Ventilační trasa se odemkne nástrojem z dílny. Policista otevře hlavní bránu přes venkovní konzoli na 8 s.
5. Po soukromém uploadu ověř skutečné ukládání firmy, firemní pokladny, úrovně a počtu zadržení. Na dvou klientech prověř souběžné zatýkání stejného NPC a odpojení policisty při poutání.

Dosud neprovedeno: všechny body této sekce v Roblox Studiu. Není k dispozici přístup k engine ani měření výkonu na cílových zařízeních.

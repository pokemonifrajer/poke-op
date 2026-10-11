# Testování Harbor City 0.2.0-alpha

## Co bylo ověřeno mimo Roblox

- Syntaxe všech 12 skriptů v kompatibilní podmnožině Lua/Luau (LuaTeX Lua parser).
- 22 testů čisté herní logiky: bankovní převody, ochrana proti opakování odměny, vozidla, nákup tří domů a dvou firem, výnosy, hledanost a tresty.
- 16 testů služeb s výslovně simulovaným rozhraním Roblox: zámek uloženého profilu, chyby načítání a ukládání, staré alfa profily, všechny tři loupeže, timeout a odpojení.
- Struktura XML, jedinečné reference objektů, umístění skriptů, shoda vložených zdrojů s repozitářem, všechny používané interakční body.
- Kontrola všech 32 povinných interakčních markerů, semaforů se třemi lampami, vstupů k domům, letištního terminálu, hlavních budov a průchodnosti tunelu.

Tohle **nejsou testy v Roblox enginu**. Fyzika, skutečná replikace, pathfinding, načtení XML ve Studiu, mobilní ovládání a živé DataStore API zůstávají neověřené.

## Nejmenší test ve tvém Studiu

1. Otevři `HarborCity.rbxlx` přes **File → Open from File**.
2. Zobraz **Output** a spusť **Play / F5**. V Output má být `[Harbor City] Alpha initialized` a nemají být červené chyby. Pokud se chyba objeví, pošli její celý text nebo screenshot.
3. Stiskni **Vstoupit do města**. Sleduj navigaci ke garáži. U recepce stiskni **E**, vyzvedni **Aster Compact**, u sedadla stiskni **E** a zkus **WASD**. Mezerník nebo tlačítko Vystoupit opustí auto.
4. U Civic Bank vstup hlavním vchodem. Na terminálu podrž E. Zapamatuj si čtyři symboly, počkej 10 sekund a zopakuj pořadí. Po alarmu vstup do trezoru a podrž E u tašky 5 sekund.
5. V telefonu otevři Mapu, klikni na Přístav a dovez tašku k tyrkysovému bodu QUAY 04. Po odevzdání má přibýt $3 800 jen jednou.
6. Nech se dostihnout policií: zůstaň stát v její blízkosti 3 sekundy. Ověř přesun do vězení, čas trestu a dvě cesty ven: prádelna → karta → servisní východ; odtok → 3× uvolnit mříž → podzemní chodba → východ.
7. Otestuj přirozené skončení trestu, reset postavy během trestu a zrušení loupeže po resetu.

8. U telefonu otevři **Práce** a vyzkoušej klenotnictví i obrněnou dodávku. Pro každou misi začni u jejího označeného místa, vyřeš minihru, vezmi kořist a dovez ji do přístavu.
9. V telefonu otevři **Domy**, naviguj se postupně k Marině, Westwoodu a North Hill. U recepce kup dům, použij jeho vchod a ověř, že jiný účet bez vlastnictví dovnitř nemůže.
10. Otevři **Firmy**, naviguj se k Harbor Express a Autohausu a kup podnik. Po třech minutách ověř připsaný příjem v bance a v historii transakcí.
11. Při jízdě dojeď ke křižovatce během červené a ověř zastavení. V každém okně 12 s se střídá směr; poslední 3 s svítí žlutá.
12. Projdi pěšky centrum, školní kampus, průmysl, letiště a přístav. Ověř, že městští chodci a hlídky postupují po chodnících bez dlouhého zasekávání.

## Multiplayer a ukládání — před veřejným vydáním

Použij Studio testovací režim **Server & Clients** se dvěma hráči. Jeden je civilista, druhý vstoupí do služby u policejní přepážky. Ověř společnou loupež, zatčení, oddělené účty, obsazené parkoviště, odpojení řidiče a odpojení vedoucího loupeže. Následně vyzkoušej čtyři klienty a případně zatížení vyšším počtem hráčů. Změř snímkovou frekvenci a síťový přenos; v této verzi nejsou naměřené hodnoty.

V běžném Studiu je ukládání záměrně vypnuté. Testovací prostředí může používat nové účty při každém spuštění. **Nezapínej StudioPersistence proti ostrým datům.**

Po soukromém nahrání spusť hru z Roblox klienta na vlastníkově účtu, vydělej peníze, odejdi a znovu se připoj. Ověř návrat peněz a vlastněných aut. U živé hry se profil při chybě načítání nesmí nahradit prázdným profilem. Při ztrátě ukládání se hráč odpojí; poslední neuložené změny se mohou ztratit.

Před zpřístupněním dalším lidem zkontroluj také podmínky Audience v Creator Dashboardu. Soukromý upload sám o sobě není veřejné vydání.

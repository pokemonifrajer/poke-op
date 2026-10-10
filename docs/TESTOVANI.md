# Testování Harbor City 0.1.0-alpha

## Co bylo ověřeno mimo Roblox

- Syntaxe všech 12 skriptů v kompatibilní podmnožině Lua/Luau (LuaTeX Lua parser).
- 18 testů čisté herní logiky: peníze, chybné hodnoty, nákupy, ochrana proti opakování odměny, hledanost, trest, kopie dat.
- 14 testů služeb s výslovně simulovaným rozhraním Roblox: zámek uloženého profilu, chyby načítání a ukládání, opětovné připojení, loupež od terminálu po výplatu, timeout a odpojení.
- Struktura XML, jedinečné reference objektů, umístění skriptů, shoda vložených zdrojů s repozitářem, všechny používané interakční body.
- Geometrické kontroly hlavních vstupů, přístupů k terminálům a průchodnosti tunelu.

Tohle **nejsou testy v Roblox enginu**. Fyzika, skutečná replikace, pathfinding, načtení XML ve Studiu, mobilní ovládání a živé DataStore API zůstávají neověřené.

## Nejmenší test ve tvém Studiu

1. Otevři `HarborCity.rbxlx` přes **File → Open from File**.
2. Zobraz **Output** a spusť **Play / F5**. V Output má být `[Harbor City] Alpha initialized` a nemají být červené chyby. Pokud se chyba objeví, pošli její celý text nebo screenshot.
3. Stiskni **Vstoupit do města**. Sleduj navigaci ke garáži. U recepce stiskni **E**, vyzvedni **Aster Compact**, u sedadla stiskni **E** a zkus **WASD**. Mezerník nebo tlačítko Vystoupit opustí auto.
4. U Civic Bank vstup hlavním vchodem. Na terminálu podrž E. Zapamatuj si čtyři symboly, počkej 10 sekund a zopakuj pořadí. Po alarmu vstup do trezoru a podrž E u tašky 5 sekund.
5. V telefonu otevři Mapu, klikni na Přístav a dovez tašku k tyrkysovému bodu QUAY 04. Po odevzdání má přibýt $3 800 jen jednou.
6. Nech se dostihnout policií: zůstaň stát v její blízkosti 3 sekundy. Ověř přesun do vězení, čas trestu a dvě cesty ven: prádelna → karta → servisní východ; odtok → 3× uvolnit mříž → podzemní chodba → východ.
7. Otestuj přirozené skončení trestu, reset postavy během trestu a zrušení loupeže po resetu.

## Multiplayer a ukládání — před veřejným vydáním

Použij Studio testovací režim **Server & Clients** se dvěma hráči. Jeden je civilista, druhý vstoupí do služby u policejní přepážky. Ověř společnou loupež, zatčení, oddělené účty, obsazené parkoviště, odpojení řidiče a odpojení vedoucího loupeže. Následně vyzkoušej čtyři klienty a případně zatížení vyšším počtem hráčů. Změř snímkovou frekvenci a síťový přenos; v této verzi nejsou naměřené hodnoty.

V běžném Studiu je ukládání záměrně vypnuté. Testovací prostředí může používat nové účty při každém spuštění. **Nezapínej StudioPersistence proti ostrým datům.**

Po soukromém nahrání spusť hru z Roblox klienta na vlastníkově účtu, vydělej peníze, odejdi a znovu se připoj. Ověř návrat peněz a vlastněných aut. U živé hry se profil při chybě načítání nesmí nahradit prázdným profilem. Při ztrátě ukládání se hráč odpojí; poslední neuložené změny se mohou ztratit.

Před zpřístupněním dalším lidem zkontroluj také podmínky Audience v Creator Dashboardu. Soukromý upload sám o sobě není veřejné vydání.

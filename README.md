# Plikownik 1.0.2 (19)

Offline: PDF i podglądy LibreOffice/Microsoft Office, czytanie, zakładki, notatki i udostępnianie.
Edycja DOCX/ODT/DOC/RTF/TXT pozostaje funkcją pomocniczą. Ten pakiet zawiera źródła, nie APK.

## Poprawka 1.0.2 — analiza kodu

Poprawiono `text.trim().isEmpty()` na `text.trim().isEmpty` w obsłudze zaznaczania PDF.
W Dart `isEmpty` jest właściwością, więc nie należy wywoływać jej jak funkcji.
Klucz podpisywania i wszystkie cztery sekrety pozostają niezmienione.

Do przetestowania:
- GitHub Actions: etap `flutter analyze` ma przejść; następnie testy i budowanie APK.
- Zaznacz słowo w PDF, skopiuj je i zakreśl kilka wierszy.
- Przytrzymaj pusty obszar/skan bez tekstu: komunikat zamiast zamknięcia aplikacji.
- Jeśli masz już wersję podpisaną stałym kluczem, zainstaluj jako aktualizację i sprawdź zakładki/notatki.

Kontrola źródeł i spójności wersji została wykonana lokalnie. Pełny Flutter jest sprawdzany w Actions.

## Zmiana 1.0.1 — stały podpis

APK wymaga teraz czterech sekretów GitHub: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`,
`KEY_ALIAS`. Wartości znajdują się w osobnej, prywatnej paczce klucza; nie kopiuj jej do repozytorium.
Dodaj każdy sekret w Settings → Secrets and variables → Actions → New repository secret.
Następnie wyślij kod tej wersji i uruchom kompilację.

Skrypt sprawdza odcisk certyfikatu i dostęp do klucza prywatnego przed pobieraniem LibreOffice.
Brak sekretów, błędne hasło lub inny klucz zatrzymują kompilację. Nie ma podpisu testowego jako zastępstwa.
Odcisk w `tools/signing_certificate.sha256` jest publiczny i może znajdować się w repozytorium.
Zachowaj prywatną paczkę jako kopię zapasową — ten sam klucz ma podpisywać wszystkie przyszłe wersje.

**Pierwsze przejście:** jeśli obecna aplikacja jest podpisana niezachowanym kluczem testowym,
trzeba ją odinstalować raz przed instalacją tej wersji. Odinstalowanie usuwa prywatne zakładki,
notatki i historię. Jeżeli zainstalowana wersja ma już „Kopię zapasową”, zapisz ją poza aplikacją
przed odinstalowaniem i przywróć po instalacji. W starszej wersji eksport TXT pozwala zachować
komentarze do odczytu, ale nie umożliwia późniejszego importu zakreśleń.

Do przetestowania: kompilacja po dodaniu sekretów, instalacja pierwszej wersji ze stałym podpisem,
ponowna kompilacja tego samego kodu i instalacja APK na nią bez odinstalowywania; sprawdź zachowanie
zakładki i notatki. Funkcje czytnika nie zmieniły się względem 1.0.0.

## Nowości 1.0

- **PDF z zaznaczeniami i komentarzami**: w menu „Zapisz PDF z notatkami”, a pod przyciskiem
  udostępniania wybór oryginału albo PDF z notatkami. Eksport zachowuje tekst, grafikę i istniejące
  adnotacje, dodając standardowe adnotacje Highlight z komentarzami. Nie rasteruje stron.
  Oryginał pozostaje nienaruszony; komentarze odczytuje się w panelu adnotacji czytnika PDF.
  Kolory trybu nocnego/ciepłego nie zmieniają eksportu. Pliki podpisane cyfrowo i takie, które
  nie zezwalają na adnotacje, są odrzucane z komunikatem. Dla Office eksportowany jest bieżący podgląd PDF.
- **Zaznaczanie tekstu od Androida 15**: przytrzymaj słowo, przeciągnij palcem bez odrywania do
  końca fragmentu, potem podnieś palec. Panel oferuje kopiowanie tekstu lub zakreślenie wierszy.
  Zaznaczenie obejmuje jedną stronę. Wiersze zapisywane są razem, atomowo; limit 100 wierszy na raz,
  500 zaznaczeń na dokument. Kolor odpowiada ostatnio wybranemu kolorowi zakreślacza.
  Skan bez warstwy tekstowej wymaga zakreślacza obszaru. OCR nie jest częścią tej wersji.
- **Ostre powiększanie**: powyżej 1,4× czytnik renderuje widoczne kafelki 768 px. Po przesunięciu
  doładowuje szczegóły nowego obszaru, utrzymując bazowy podgląd do czasu ich pojawienia się.
  Nie tworzy ogromnej bitmapy całej strony. Kafelki poza ekranem są zwalniane, a oczekujące
  zlecenia dla zamkniętego dokumentu pomijane. Filtry czytania obejmują też kafelki.
- **Kopia danych czytnika** na ekranie głównym: zapis/przywracanie pliku JSON do wybranego miejsca.
  Obejmuje ustawienia, miejsca czytania, zakładki i lokalne notatki; NIE obejmuje dokumentów,
  historii ostatnich plików ani przypięć. Dokumenty przenieś osobno, zachowując ich bajty.
  Przywracanie łączy zakładki i notatki; przy konflikcie identyfikatora zachowuje bieżącą notatkę.
  Bieżące miejsca czytania mają pierwszeństwo, ustawienia wyglądu pochodzą z kopii.
  Limit kopii: 25 MB; import jest walidowany przed zmianami. Przerwany import cofa dziennik przy
  następnym uruchomieniu. Ponowny import tej samej kopii nie mnoży zaznaczeń.
- **Menu w grupach**: czytanie, zaznaczenia, operacje na pliku. Pomoc zaznaczania jest dostępna
  w menu. Zachowane są dotychczasowe gesty Wstecz, pełny ekran i otwieranie plików z innych aplikacji.

## Budowanie i aktualizacja

Wgraj zawartość katalogu `dokumenty` do dotychczasowego repozytorium (łącznie z `.github`).
Commit → Push → GitHub Actions. Pobierz `plikownik-1.0.2-apk` i zainstaluj APK jako aktualizację, jeśli obecna wersja używa już stałego klucza.
Identyfikator aplikacji nie zmienił się. Użyj tego samego klucza podpisu co poprzednio.
Przy pierwszej zmianie podpisu zastosuj procedurę opisaną powyżej; później nie odinstalowuj aplikacji.
Nowa zależność: PdfBox-Android 2.0.27.0 (Apache 2.0); Gradle pobiera ją podczas budowania.
Gotowa aplikacja nadal działa bez dostępu do internetu. Wersja Flutter/LibreOffice pozostaje przypięta.

## Do przetestowania na telefonie

1. Zainstaluj na poprzedniej wersji. Sprawdź zachowanie ostatnich plików, zakładek, notatek i ustawień.
2. Przytrzymaj słowo w PDF, rozszerz palcem zaznaczenie na kilka wierszy, skopiuj je i zakreśl.
   Sprawdź polskie znaki, ostatnią stronę i skan bez tekstu. Zweryfikuj zachowanie po błędzie i zamknięciu pliku.
3. Dodaj komentarze i trzy kolory zaznaczeń. Zapisz/udostępnij PDF z notatkami, otwórz na komputerze
   w czytniku obsługującym adnotacje. Sprawdź tekst, grafiki, istniejące adnotacje, obrót stron i położenie markerów.
   Oryginalny plik ma pozostać bez zmian. Ponów po anulowaniu okna zapisu/udostępniania.
4. Powiększ mały tekst do 6–12×, przesuń poziomo i pionowo, także w dużym arkuszu XLSX/ODS.
   Sprawdź stopniowe wyostrzenie, brak przesunięcia kafelków i drgań, szybkie przewijanie, obrót telefonu.
5. Zapisz kopię danych. Usuń testową zakładkę/notatkę i przywróć kopię; odtwórz ją ponownie,
   sprawdzając brak duplikatów. Spróbuj przywrócić błędny JSON: obecne dane powinny zostać zachowane.
   Najlepiej sprawdź też na drugim urządzeniu z identycznymi dokumentami.
6. Sprawdź pełny ekran, ciepły/ciemny tryb, wyszukiwanie, miniatury, listę notatek i udostępnianie oryginału.
7. Otwórz PDF i DOCX z poczty/WhatsAppa/menedżera plików. Wstecz ma wracać do aplikacji źródłowej.
8. Awaryjna edycja: zaznacz tekst, zmień rozmiar/pogrubienie, zapisz kopię DOCX/ODT i otwórz w LibreOffice.
   Porównaj także kilka własnych dokumentów DOCX/XLSX z widokiem na komputerze, szczególnie czcionki i tabele.

## Weryfikacja

Lokalnie: kompilacja całego kodu natywnego z Android API, AndroidX, PdfBox i atrapami mostka Flutter;
wykonywane testy JVM geometrii obróconych/przyciętych stron, importu/łączenia kopii, wycofywania
przerwanych zapisów i atomowego zapisu zaznaczeń wielu wierszy, plus wcześniejsze testy notatek.
Kontrola struktury źródeł, wersji, XML i braku uprawnienia INTERNET.
Dodano testy Flutter zaznaczania/kopiowania, kafelków, wyboru eksportu i anulowania/błędów kopii.
**Pełnych `flutter analyze`, `flutter test`, kompilacji APK oraz testów na urządzeniu nie wykonano lokalnie.**
GitHub Actions uruchamia analizę i testy przed zbudowaniem APK. Nadanie wersji 1.0 nie zastępuje
końcowego sprawdzenia na telefonie — lista powyżej stanowi sprawdzenie odbiorcze.

## Ograniczenia

Podgląd Office zależy od zgodności LibreOffice i dostępnych czcionek: nie ma gwarancji 1:1 dla
każdego dokumentu Microsoft Office. CSV pozostaje tekstem. Brak OCR i obsługi haseł.
Zakreślenia w wyeksportowanym PDF są standardowymi adnotacjami; ich wygląd i obsługa komentarzy
mogą różnić się między czytnikami. Po otwarciu takiej kopii w Plikowniku widać osadzone zakreślenia,
ale lista lokalnych notatek nie importuje automatycznie adnotacji PDF — do przenoszenia lokalnych danych służy kopia JSON.
Poniżej zachowano historię wcześniejszych wydań; opis 1.0 ma pierwszeństwo przed dawnymi ograniczeniami.

# Historia wcześniejszych wersji

Prosty czytnik dokumentów na Androida, interfejs we Flutterze.
Silnik LibreOffice 26.2.6.3 pracuje wewnątrz aplikacji, bez serwera i bez instalowania drugiej aplikacji.

## Nowości 0.12.0 — wyszukiwanie i udostępnianie notatek

- **Zaznaczenia i notatki** mają wyszukiwanie w komentarzach bez rozróżniania wielkości liter.
  Wpisanie numeru strony znajduje również zaznaczenia z tej strony.
- Filtry **Wszystkie / Żółty / Zielony / Różowy** działają razem z wyszukiwaniem. Licznik pokazuje
  liczbę widocznych pozycji względem wszystkich. Zmiana koloru lub komentarza może usunąć
  pozycję z bieżącego filtra; samo zaznaczenie nadal jest zapisane.
- Menu trzech kropek przy pozycji: **Edytuj notatkę i kolor**, **Kopiuj notatkę**, **Usuń zaznaczenie**.
  Kopiowanie przenosi pełny komentarz do schowka, zachowując podziały wierszy. Dla pustej notatki
  opcja kopiowania jest ukryta. Znacznik potwierdza skopiowanie.
- **Udostępnij wszystkie (TXT)** tworzy plik `nazwa-notatki.txt` w UTF-8 i otwiera systemowy
  wybór aplikacji Androida. Plik zawiera nazwę dokumentu oraz komentarze, numery stron i kolory,
  posortowane według strony i położenia. Obejmuje wszystkie zaznaczenia, niezależnie od filtra.
  Pozycje bez komentarza mają opis „Zaznaczony fragment bez notatki”.
- Zestawienie **nie zawiera tekstu ani obrazów zakreślonych fragmentów**, nie wykonuje OCR.
  Nie jest też kopią zapasową do importowania zaznaczeń. PDF nadal jest udostępniany bez
  lokalnych zakreśleń; istniejące PDF/DOCX i notatki nie są zmieniane podczas przygotowania TXT.
- Dla widoku całych arkuszy zestawienie wyjaśnia znaczenie numerów stron. Udostępniona kopia
  TXT jest niezależna od otwartego podglądu, tak jak pozostałe załączniki aplikacji.
- Panel notatek dostosowuje wysokość do klawiatury, a przy małej ilości miejsca jego górna
  część przewija się. Po przerwanym/nieudanym udostępnieniu można spróbować ponownie.

### Do przetestowania w 0.12.0

1. Dodaj kilka komentarzy w różnych kolorach. Wyszukaj fragment tekstu, także wielkimi
   literami, oraz numer strony. Sprawdź wszystkie filtry kolorów i brak wyników.
2. Przy aktywnym filtrze edytuj komentarz i zmień kolor. Sprawdź, czy zmienił się właściwy
   wpis i czy pozostałe notatki są nienaruszone. Usuń jedną pozycję przy włączonym filtrze.
3. W menu pozycji wybierz Kopiuj notatkę i wklej do wiadomości lub edytora TXT. Sprawdź
   polskie znaki, pełną treść i podziały wierszy.
4. Udostępnij wszystkie (TXT) przez pocztę lub komunikator. Otwórz załącznik na telefonie
   i komputerze: sprawdź nazwę, komentarze i numery stron. Przy aktywnym filtrze TXT nadal
   ma zawierać wszystkie zaznaczenia z dokumentu.
5. Anuluj systemowe udostępnianie, spróbuj ponownie, potem wróć do dokumentu i przewijaj.
6. Sprawdź panel notatek z klawiaturą, pionowo i poziomo, oraz zwykłe udostępnianie PDF/DOCX.

Lokalnie przeszły testy przechowywania zaznaczeń i zestawienia TXT (kolejność, polskie znaki,
nowe wiersze, brak zmian w danych, puste komentarze i brak wpisów) oraz kompilacja natywnej Javy
z API Androida/AndroidX i atrapami mostka Flutter. Dodano scenariusz interfejsu filtrowania,
kopiowania, edycji właściwego wpisu i ponawiania udostępnienia. Pełnych `flutter analyze`,
`flutter test` i budowania APK nie wykonano lokalnie — uruchomi je GitHub Actions.

## Nowości 0.11.0 — zakreślacz i notatki

- **Menu → Zakreślacz** w PDF i podglądach dokumentów Office. Przeciągnij palcem poziomo
  po wierszu lub ukośnie, aby objąć prostokątem większy fragment. To zaznaczanie obszaru,
  nie automatyczny wybór słów. Działa również na skanach bez warstwy tekstowej.
- Kolory: **żółty, zielony i różowy**, z przezroczystością umożliwiającą czytanie tekstu.
  Kolor zaznaczenia pozostaje ten sam w oryginalnym, ciemnym i ciepłym trybie czytania.
- W trybie zakreślacza przewijanie i powiększanie są wyłączone, aby ruch palca rysował.
  **Zakończ** lub pierwszy gest Wstecz wraca do przewijania. Ustaw powiększenie przed rysowaniem.
  Drugi palec anuluje rozpoczęte zaznaczenie zamiast rysować przypadkowy obszar.
- **Cofnij ostatnie zaznaczenie** usuwa ostatni fragment dodany w bieżącej sesji zakreślacza.
- **Menu → Zaznaczenia i notatki** pokazuje listę w kolejności stron. Dotknięcie pozycji
  przenosi do jej miejsca; ikona notatki otwiera edycję komentarza i koloru, kosz usuwa
  zaznaczenie wraz z komentarzem. Komentarz może mieć do 1000 znaków.
- Położenie jest zapisywane względem strony, więc zaznaczenia zachowują miejsce przy
  powiększeniu, obrocie oraz ponownym otwarciu. Obejmują PDF i podglądy Worda/LibreOffice/arkuszy.
- Zaznaczenia i notatki są **lokalnymi danymi Plikownika**, osobnymi od dokumentu.
  **Nie są nanoszone do oryginału ani do udostępnianego/eksportowanego PDF.**
  Nie są to standardowe adnotacje PDF odczytywane przez inne programy.
  Identyczna kopia pliku używa tych samych zaznaczeń. Po zmianie zawartości pliku powstaje
  nowy zestaw; podgląd wydruku i widok całych arkuszy mają oddzielne zestawy.
- Limit: 500 zaznaczeń w dokumencie, do 200 dokumentów/widoków i 2 MB danych na dokument.
  Zapis przez plik tymczasowy; błąd nie jest sygnalizowany jako sukces i nie usuwa wcześniejszych
  zaznaczeń. Czyszczenie historii nie usuwa notatek; odinstalowanie lub wyczyszczenie danych aplikacji je usuwa.
- Informacje o pliku pokazują również liczbę zaznaczeń.

### Do przetestowania w 0.11.0

1. PDF → menu → Zakreślacz. Zaznacz wiersz na żółto, następny na zielono i fragment na różowo.
   Sprawdź rysowanie z lewej do prawej i w odwrotną stronę. Zakończ i przewijaj normalnie.
2. Cofnij ostatnie zaznaczenie. Pozostałe mają zostać. Pierwsze Wstecz podczas rysowania
   ma zakończyć tryb zakreślacza, a nie zamknąć dokument.
3. Zaznaczenia i notatki → ikona notatki: wpisz polski tekst i zmień kolor. Zamknij aplikację,
   otwórz ten sam plik i sprawdź zaznaczenia oraz komentarz.
4. Z listy przejdź do zaznaczenia na innej stronie; usuń jedną pozycję. Po ponownym otwarciu
   usunięta pozycja nie powinna wrócić, a pozostałe mają zostać.
5. Zaznacz fragment po powiększeniu, następnie pomniejsz i obróć telefon. Kolor ma pozostać
   na tym samym fragmencie dokumentu. Sprawdź także ciemny i ciepły widok.
6. Powtórz na skanie PDF, DOCX/ODT oraz arkuszu. Zaznaczanie nie wymaga rozpoznanego tekstu.
7. Podczas rysowania dołóż drugi palec — rozpoczęte zaznaczenie powinno zostać anulowane.
8. Udostępnij plik i PDF z podglądu: odbiorca dostaje dokument bez lokalnych zaznaczeń i notatek.
9. Kontrolnie sprawdź zwykłe przewijanie, powiększanie, zakładki stron oraz powrót do poczty/WhatsAppa.

Lokalnie przeszły testy przechowywania zaznaczeń: zapis i ponowny odczyt, polskie znaki,
zmiana koloru, usuwanie, granice współrzędnych, limity, zachowanie danych przy błędnym żądaniu
oraz nieudana podmiana pliku. Przeszła kompilacja Javy z API Androida/AndroidX i atrapami mostka Flutter.
Dodano testy interfejsu gestów, współrzędnych, notatki i cofania. Pełne `flutter analyze`,
`flutter test` i budowanie APK wykona GitHub Actions; nie wykonano ich lokalnie ani nie testowano APK na telefonie.
Test JVM używa wyłącznie testowej biblioteki JSON-Java 20240303 z weryfikacją SHA-256;
produkcyjna aplikacja używa systemowego `org.json` Androida i nadal działa offline.

## Poprawka 0.10.1 — analiza Fluttera

Usunięto niepotrzebny import `package:flutter/material.dart` z `test/bookmarks_test.dart`,
zgłoszony przez `flutter analyze`. Funkcje aplikacji są takie jak w 0.10.0.
Lokalnie nie uruchomiono ponownie Fluttera; analizę, testy i budowanie APK wykona GitHub Actions.

### Do przetestowania w 0.10.1

- Po Commit/Push sprawdź, czy przechodzą kroki `flutter analyze`, `flutter test` i budowanie APK.
- Po instalacji dodaj zakładkę strony PDF, zamknij dokument i sprawdź jej zachowanie po ponownym otwarciu.

## Nowości 0.10.0 — zakładki i lista dokumentów

- **Zakładki stron** w PDF i podglądach Office: przycisk obok numeru strony dodaje/usuwa
  zakładkę. Menu trzech kropek → Zakładki pokazuje listę zapisanych stron, przechodzi do
  wybranej i pozwala usuwać poszczególne zakładki. W widoku arkuszy lista używa nazw zakładek
  arkusza, gdy liczba nazw odpowiada liczbie stron.
- Zakładki są osobnymi danymi Plikownika: nie zmieniają PDF ani załącznika. Są zapisywane
  lokalnie dla zawartości pliku i typu podglądu, więc identyczna kopia ma te same zakładki.
  Zmieniona treść otrzymuje nowy zestaw. Limit: 50 stron w dokumencie, 200 dokumentów/widoków.
  Zakładki nie są automatycznie usuwane po przekroczeniu limitu — wyświetlany jest komunikat.
  Czyszczenie listy ostatnich plików nie usuwa zakładek; odinstalowanie/wyczyszczenie danych aplikacji je usuwa.
  Nie jest to import spisu treści ani zakładek zapisanych wewnątrz PDF.
- **Postęp na liście ostatnich**: rozmiar pliku, ostatnio oglądana strona i pasek jej położenia.
  Pasek pokazuje pozycję strony w dokumencie, nie potwierdza przeczytania treści. Starsze wpisy
  historii otrzymają dane po ponownym otwarciu pliku. TXT/CSV nie mają podziału na strony.
- **Sortowanie listy**: ostatnio otwierane, najdawniej otwierane, nazwa A–Z i nazwa Z–A.
  Przypięte pozycje pozostają na górze. Sortowanie działa razem z wyszukiwaniem i jest
  zapamiętywane niezależnie od koloru czytnika i opcji niewygaszania.
- **Informacje o pliku** w menu dokumentu: nazwa, format, rozmiar oryginalnego pliku,
  liczba stron bieżącego podglądu oraz liczba zakładek.
- Przy ponownym otwarciu arkusza z listy ostatnich odtwarzany jest używany wcześniej
  tryb całych arkuszy albo podglądu wydruku. Pozycja i zakładki odpowiadają temu samemu trybowi.

### Do przetestowania w 0.10.0

1. Otwórz wielostronicowy PDF, dodaj zakładki na dwóch różnych stronach, zamknij aplikację
   i otwórz plik ponownie. Menu → Zakładki ma zawierać obie strony; dotknięcie przenosi na stronę.
2. Usuń jedną zakładkę z listy, drugą przyciskiem przy numerze strony. Zamknij i otwórz plik —
   usunięte zakładki nie powinny wrócić. Powtórz dodanie w podglądzie DOCX/ODT.
3. Przeczytaj dalszą stronę PDF i wróć do ekranu głównego. Lista ma pokazać tę stronę i rozmiar.
   Stary wpis bez postępu otwórz jeszcze raz, aby uzupełnić dane.
4. Przetestuj wszystkie cztery sortowania oraz wyszukiwanie przy sortowaniu. Przypięte
   pozostają nad pozostałymi. Uruchom ponownie aplikację i sprawdź zapamiętanie sortowania.
5. Menu → Informacje o pliku: sprawdź PDF, DOCX i TXT. Dla DOCX rozmiar dotyczy pliku DOCX,
   a liczba stron jego podglądu. Udostępnienie pliku nadal ma działać.
6. W XLSX/ODS włącz widok całych arkuszy, wybierz dalszą zakładkę i zaznacz ją jako zakładkę
   czytelnika. Zamknij dokument, otwórz go z ostatnich — tryb, miejsce i zakładka mają zostać.
7. Kontrolnie sprawdź ciemny/ciepły tryb, pełny ekran, powrót do poczty/WhatsAppa i zmianę
   rozmiaru tekstu w edytorze. Sprawdź dolny pasek również przy dużej czcionce systemowej.

Lokalnie przeszły testy logiki zakładek (zapis/odczyt formatu, usuwanie, brak duplikatów,
nieprawidłowe strony, limit i zwalnianie miejsca) oraz kompilacja Javy z API Androida/AndroidX
z atrapami mostka Flutter. Do workflow dodano scenariusze interfejsu zakładek, błędu zapisu,
informacji o pliku, sortowania i powrotu do widoku arkusza. Pełnych `flutter analyze`,
`flutter test` i kompilacji APK nie wykonano lokalnie — uruchomi je GitHub Actions.
Próby na telefonie pozostają do wykonania.

## Nowości 0.9.0 — tryb czytania

- **Tryb czytania** (ikona obok udostępniania): Oryginał, Ciemny i Ciepły.
  Ciemny odwraca kolory całej strony, w tym zdjęć i wykresów: białe tło staje się czarne,
  czarny tekst biały. Ciepły przyciemnia niebieską i zieloną składową — biel staje się
  jasnopomarańczowa, czarny tekst pozostaje czarny. Filtry nie zmieniają zapisanych plików ani załączników.
- **Czytaj na pełnym ekranie** ukrywa paski aplikacji i systemu. Dotknięcie dokumentu
  pokazuje lub chowa kontrolki. Pierwsze Wstecz kończy pełny ekran, drugie zamyka dokument
  zgodnie z wcześniejszym zachowaniem (załącznik z innej aplikacji wraca bez ekranu głównego).
- Opcja **Nie wygaszaj ekranu** działa podczas podglądu PDF/Office; po zamknięciu dokumentu
  normalne wygaszanie wraca. Preferencje koloru i wygaszania są zapamiętywane.
- **Powrót do miejsca czytania**: strona, miejsce na stronie, powiększenie oraz przesunięcie
  poziome. Zapis przy przewijaniu jest ograniczony do około jednej aktualizacji na sekundę;
  zamknięcie dokumentu i przejście aplikacji w tło zapisują aktualną pozycję.
  Zakładka jest powiązana z zawartością pliku (SHA-256), więc działa również dla jego identycznej
  lokalnej kopii. Zmieniony dokument otrzymuje nową zakładkę. Pamiętamy do 100 dokumentów/widoków.
- **Miniatury / arkusze** w menu trzech kropek: siatka stron i przejście do wybranej strony.
  Ładowane są małe obrazy widocznych miniatur, a nie wszystkie strony naraz.
- **Szukaj w dokumencie** w tym samym menu: PDF oraz podgląd Office, podświetlenie aktywnego
  wyniku i poprzedni/następny wynik. Wyszukiwanie postępuje stronami i można je zatrzymać.
  Wymaga Androida 15/API 35 lub nowszego; na starszych urządzeniach opcja jest ukryta.
  Nie obejmuje OCR skanów. Limit 200 znaków zapytania i 500 wyników.
- **Widok całych arkuszy** dla XLS/XLSX/ODS: jedna zakładka na jednej dużej stronie, wybór
  zakładki po nazwie w siatce miniatur. Można wrócić do zwykłego podglądu wydruku.
  To nadal podgląd PDF, nie siatka edytowalnych komórek. Zgodnie z zachowaniem silnika
  obejmuje również ukryte arkusze — przed włączeniem pokazujemy potwierdzenie.
  Udostępniany/eksportowany PDF ma układ aktualnego podglądu, a oryginalny arkusz pozostaje bez zmian.
  Jeżeli silnik zwróci inną liczbę stron niż nazw zakładek, miniatury pokazują numery stron,
  aby nie przypisać stronie błędnej nazwy.
- Powiększenie do 12×, dopasowanie do szerokości, zachowanie względnego miejsca po obrocie.
  Rozdzielczość strony dostosowuje się do ekranu i powiększenia (do 2400 px szerokości / 3500 px
  wysokości). Bardzo rozległe arkusze mogą być niewyraźne — nie ma jeszcze renderowania kafelkowego.
  Nie wykonujemy ponownego renderowania przy samej zmianie kolorów.

### Do przetestowania w 0.9.0

1. **Kolory:** PDF z tekstem i zdjęciem → Tryb czytania → Ciemny, Ciepły, Oryginał.
   Ciemny ma mieć czarne tło i jasny tekst, ciepły jasnopomarańczowe tło i ciemny tekst.
   Udostępnij PDF — odbiorca ma dostać oryginalne kolory.
2. **Pełny ekran:** włącz, przewijaj palcem, powiększ, dotknij aby pokazać i ponownie schować
   kontrolki. Sprawdź gesty systemowe. Wstecz ma najpierw przywrócić zwykły podgląd.
3. **Zapamiętywanie:** przewiń na dalszą stronę, powiększ, przesuń poziomo, zamknij i otwórz
   ten sam plik z ostatnich. Powtórz po zamknięciu całej aplikacji.
4. **Obrót:** w środku długiego PDF obróć telefon pion/poziom, również przy powiększeniu.
   Numer strony i miejsce czytania mają zostać zachowane, bez drgania przy szczypaniu.
5. **Miniatury:** otwórz długi PDF, wybierz odległą stronę. Sprawdź płynność przewijania siatki.
6. **Wyszukiwanie:** PDF z tekstem oraz DOCX/ODT → szukaj słowa obecnego na kilku stronach,
   użyj następnego/poprzedniego wyniku; przetestuj brak wyników i przerwanie wyszukiwania.
   Skan bez tekstu ma zwrócić brak wyników, a nie zawiesić aplikację.
7. **Arkusze:** XLSX i ODS z kilkoma zakładkami → Widok całych arkuszy → Miniatury / arkusze.
   Sprawdź nazwy, szeroką tabelę, powrót do podglądu wydruku i udostępniony PDF.
8. **Wygaszanie i powroty:** włącz Nie wygaszaj ekranu, odczekaj zwykły czas wygaszania;
   potem zamknij dokument i sprawdź przywrócenie wygaszania. Otwórz dokument z WhatsAppa/poczty
   i wróć do aplikacji źródłowej; sprawdź też udostępnianie i edycję po użyciu trybu czytania.

Lokalna weryfikacja: kompilacja natywnej Javy z API Androida/AndroidX i atrapami mostka Flutter,
kontrole składni plików pomocniczych i struktury źródeł. Do workflow dodano scenariusze Flutter:
pełny ekran, zapis zakładki, obrót, wyszukiwanie/cancel i leniwe miniatury. Nie uruchomiono lokalnie
`flutter analyze`, `flutter test`, silnika LibreOffice ani APK na telefonie; workflow wykona
analizę, testy i pełną kompilację. Ocena płynności i współpracy z ColorOS wymaga telefonu.

Źródła użytych interfejsów:
- https://developer.android.com/develop/ui/views/layout/immersive
- https://developer.android.com/reference/android/graphics/pdf/PdfRenderer.Page
- https://developer.android.com/reference/android/graphics/pdf/models/PageMatchBounds
- https://help.libreoffice.org/latest/en-US/text/shared/guide/pdf_params.html (`SinglePageSheets`)

## Nowości 0.8.0 — czytanie i udostępnianie

- Przycisk **Udostępnij** otwiera systemowy wybór aplikacji Androida. Dla dokumentu
  Word/LibreOffice lub arkusza wybierz oryginalny format albo podgląd PDF.
  PDF, TXT i CSV udostępnisz bez dodatkowego wyboru formatu.
- Załącznik jest osobną kopią otwartego pliku. Zamknięcie podglądu nie usuwa załącznika.
  Aplikacja odbierająca dostaje odczyt konkretnego pliku przez Android FileProvider.
  Plikownik nie wysyła plików samodzielnie i nadal nie wymaga internetu.
- Na ekranie głównym: **wyszukiwanie po nazwie lub formacie** oraz **przypinanie do 5 dokumentów**.
  Przypięte kopie są na górze, pozostają po restarcie, czyszczeniu historii i otwieraniu kolejnych plików.
  Kosz usuwa tylko nieprzypięte kopie. Aby usunąć przypiętą pozycję, najpierw ją odepnij.
- Historia nadal ma limit 10 kopii / 200 MB. Gdy przypięte kopie zajmą miejsce,
  nowy dokument można czytać, lecz może nie zostać dodany do historii.
  Lista przechowuje lokalne kopie z chwili otwarcia, a nie monitoruje zmian pliku źródłowego.
- Czytanie i udostępnianie są na pierwszym planie. Edycja pozostaje pod ołówkiem,
  tworzenie pod **Nowy dokument**. **Zapisz kopię PDF** i **Otwórz inny plik** są w menu trzech kropek.
- Kopie załączników mają limit 500 MB łącznie; starsze niż 48 godzin są usuwane przy kolejnym
  udostępnieniu. Android może również zwolnić pamięć podręczną. Limit pojedynczego pliku to 100 MB.
- AndroidX Core 1.13.1 jest zależnością kompilacji dla FileProvider. Nie wymaga połączenia przy używaniu aplikacji.

### Do przetestowania w 0.8.0

1. Otwórz DOCX/ODT i arkusz; udostępnij osobno oryginał i podgląd PDF przez pocztę
   lub komunikator. Sprawdź nazwę, rozszerzenie, treść i otwarcie załącznika po stronie odbiorcy.
2. Udostępnij PDF oraz TXT. Zamknij podgląd i sprawdź, czy przygotowany załącznik nadal się otwiera.
3. Anuluj wybór formatu i systemowe udostępnianie. Czytanie, przewijanie i ponowne udostępnienie mają działać.
4. Wyszukaj ostatni plik po części nazwy i po formacie, np. PDF; sprawdź brak wyników.
5. Przypnij dokument, uruchom aplikację ponownie i wyczyść historię. Przypięty ma zostać i dać się otworzyć.
   Sprawdź limit pięciu przypięć i zachowanie przypiętych po otwarciu ponad dziesięciu różnych plików.
6. Otwórz załącznik z poczty/WhatsAppa, udostępnij go, wróć i użyj Wstecz — bez ekranu głównego Plikownika.
7. Kontrolnie edytuj tekst, zmień rozmiar zaznaczenia i zapisz. Otwórz wynik ponownie.

Lokalnie sprawdzono moduł załączników oraz kompilację natywnej Javy z API Androida i atrapami
interfejsów Fluttera. Testy interfejsu dla udostępniania i listy dodano do GitHub Actions.
Pełne `flutter analyze`, `flutter test` i budowanie APK wykona workflow; próba na telefonie pozostaje do wykonania.

## Poprawka 0.7.1 — rozmiar czcionki

- Poprawiono parametr przekazywany do `.uno:FontHeight`: rozmiar w punktach trafia
  do **`FontHeight.Height`**, zamiast do **`FontHeight`**. Ten drugi oznacza całą strukturę,
  nie pojedynczą liczbę. Takiego samego pola używa [FontController oficjalnej aplikacji Android](https://github.com/LibreOffice/core/blob/libreoffice-25.2.0.3/android/source/src/java/org/libreoffice/FontController.java). Definicja: [SvxFontHeight w svxitems.sdi](https://github.com/LibreOffice/core/blob/master/svx/sdi/svxitems.sdi).
- W 0.7.0 zmieniono typ zapisu wartości i okno wyboru, ale nie naprawiono tej nazwy pola.
  To była niepełna poprawka. Test regresji teraz wymaga właściwego pola i odrzuca poprzednią postać.
- Raport z telefonu wskazywał zakończenie procesu 65 ms po `.uno:FontHeight`, bez wyjątku Java.
  Sam raport nie zawierał stosu wywołań silnika; związek błędnego parametru z zakończeniem
  jest silną przesłanką, a usunięcie awarii wymaga potwierdzenia na telefonie.
- Interfejs i pozostałe funkcje pozostają takie jak w 0.7.0.

### Do przetestowania w 0.7.1

1. W nowym DOCX wpisz kilka liter, zaznacz je i wybierz kolejno **12 → 18 → 24 → 12 pkt**.
   Tekst powinien zmieniać rozmiar, a aplikacja pozostać otwarta.
2. Ustaw rozmiar bez zaznaczenia, dopisz tekst i sprawdź, czy otrzymał wybraną wielkość.
3. Powtórz zmianę w istniejącym DOCX lub ODT, zapisz i otwórz dokument ponownie.
   Sprawdź również Cofnij/Ponów po zmianie rozmiaru.
4. Jeśli aplikacja nadal się zamknie: po ponownym uruchomieniu **O aplikacji → Kopiuj diagnostykę**.
   Dopisz format dokumentu i wybraną wielkość czcionki.

Lokalnie uruchomiono testy argumentów dla wszystkich 14 rozmiarów i odrzucania wartości spoza zakresu.
Test sprawdza zgodność nazwy pola z definicją UNO, ale nie uruchamia silnika LibreOffice.
Pełne flutter analyze, testy Flutter i build APK wykona GitHub Actions; test telefonu pozostaje do wykonania.

## Nowości 0.7.0

- Poprawiono błędny parametr wyszukiwania przy wyłączonym rozróżnianiu wielkości liter:
  `TransliterationModules.IGNORE_CASE` ma wartość **256**, a nie **1**. Wartość 1 oznacza
  moduł konwersji na małe litery. Włączone rozróżnianie nadal przekazuje 0.
  Źródło: [definicja UNO](https://github.com/LibreOffice/core/blob/master/offapi/com/sun/star/i18n/TransliterationModules.idl).
  Test regresji sprawdza obie wartości. Związek tego błędu z konkretnym zamknięciem aplikacji
  wymaga jeszcze potwierdzenia na urządzeniu.

- Edytor Office ma nowy interfejs: jasne tło, zielone akcenty, zaokrąglone przyciski,
  nazwę dokumentu i stały przycisk Zapisz. Narzędzia są w grupach **Tekst / Akapit / Narzędzia / Plik**.
- Okna rozmiaru czcionki, potwierdzenia zamiany, błędów i wyjścia mają wspólny nowy wygląd.
  Okno wyjścia oferuje **Zapisz i wyjdź / Odrzuć zmiany / Edytuj dalej**.
  Większe okna przewijają się, gdy telefon jest poziomo lub ma powiększoną czcionkę systemową.
- Zastąpiono systemową listę rozmiarów czcionki siatką przycisków. Polecenie formatujące
  jest wysyłane dopiero po zamknięciu okna. Argument FontHeight ma sprawdzony format JSON
  z wartością tekstową, a rozmiar jest ograniczony do 8–72 pkt.
  **Przyczyna zgłoszonego zamykania aplikacji nie jest potwierdzona logiem ani odtworzeniem na telefonie.**
  Zmiana tej ścieżki wymaga sprawdzenia opisanym poniżej testem.
- **Zapisz** aktualizuje otwarty plik, jeśli Android przyznał aplikacji prawo zapisu do jego URI.
  W przeciwnym razie najpierw wybierasz miejsce na kopię. Kolejne zapisy w tej samej edycji
  aktualizują wybraną kopię bez okna wyboru. Po zapisie pozostajesz w edytorze.
  Uprawnienia mogą wygasnąć po zamknięciu aplikacji; przy odmowie wybierz Zapisz jako.
- **Zapisz jako** i **Eksport PDF** są w grupie Plik. PDF nie oznacza dokumentu jako zapisanego.
- Przed nadpisaniem aplikacja tworzy kopię wcześniejszych bajtów pliku. Jeżeli zapis się nie powiedzie,
  próbuje je przywrócić. Gdy również przywracanie zawiedzie, zachowuje kopię w prywatnej pamięci
  i wyświetla błąd. Nie jest to atomowy zapis dla wszystkich dostawców plików.
- W „O aplikacji” dostępne jest **Kopiuj diagnostykę**: wersja, ostatnia operacja, błąd Java
  oraz dostępne systemowe informacje o zakończeniu procesu. Dane pozostają lokalnie;
  nic nie jest automatycznie wysyłane. Przycisk kopiuje raport do schowka.
- Nowy układ i zwykły zapis dotyczą edytora Office. Edytor TXT nadal korzysta z Fluttera i Zapisz jako.

### Do przetestowania w 0.7.0

1. **Rozmiar czcionki:** w kopii DOCX zaznacz słowo i wybierz kolejno 12, 18, 24 i 12 pkt.
   Powtórz bez zaznaczenia, wpisując kilka znaków po zmianie; otwórz i anuluj okno wyboru.
   Jeżeli aplikacja się zamknie, uruchom ją ponownie → O aplikacji → Kopiuj diagnostykę.
   Wklej raport i dopisz, czy zamknęła się przy otwieraniu okna, czy po wybraniu liczby.
2. **Wyszukiwanie:** włącz i wyłącz „Rozróżniaj wielkość liter”, szukaj dalej i zamień słowo.
   To osobna kontrolka od rozmiaru czcionki — sprawdź, czy ona również działa bez zamknięcia.
3. **Układ:** sprawdź cztery grupy przycisków i przewijanie poziome dłuższych pasków.
   Otwórz okno rozmiaru i okno wyjścia pionowo, poziomo oraz z widoczną klawiaturą.
4. **Zapis:** zapisz kopię, zmień kolejne zdanie i naciśnij Zapisz. Za drugim razem nie powinno
   być wyboru folderu. Wyjdź i otwórz kopię ponownie — powinna zawierać obie zmiany.
   Osobno sprawdź anulowanie pierwszego wyboru pliku oraz Zapisz jako do innej kopii.
5. **Wyjście:** sprawdź osobno Zapisz i wyjdź, Odrzuć zmiany i Edytuj dalej.
   Po anulowaniu okna wyboru pliku edytor powinien pozostać otwarty z wprowadzonym tekstem.
6. **Regresja:** B/I/U, obie listy, cofanie i PDF. Otwórz wynik w LibreOffice na komputerze.
   Przy pliku z komunikatora zamknij edytor, a potem podgląd — wróć do komunikatora.

Lokalnie przeszła kompilacja Java z API Androida i atrapami interfejsów Fluttera oraz testy
argumentów rozmiaru i zapisu (sukces, przerwany zapis, przywrócenie, brak dostępu do odczytu,
zachowanie kopii przy nieudanym przywróceniu). Nie wykonano lokalnie flutter analyze, testów Flutter,
renderowania UI na Androidzie ani próby APK na telefonie. GitHub Actions wykonuje analizę,
testy i pełne budowanie; scenariusze interfejsu powyżej pozostają do sprawdzenia na urządzeniu.
Automatyczne odzyskiwanie niezapisanej sesji nie jest jeszcze zaimplementowane.

## Nowości 0.6.0

- Listy punktowane i numerowane w edytorze DOCX, ODT, DOC i RTF. Ustaw kursor w akapicie
  albo zaznacz akapity i naciśnij „• Lista” lub „1. Lista”. Ponowne naciśnięcie wyłącza listę.
- „Szukaj / zamień” otwiera panel nad dokumentem. Wpisz szukaną treść i używaj
  „Następny” oraz „Poprzedni”; znaleziony fragment jest zaznaczany i przewijany do widoku.
- Opcjonalne rozróżnianie wielkości liter. Wyszukiwanie dosłowne, bez wyrażeń regularnych.
- Aby zmienić jeden fragment, najpierw go znajdź, a następnie naciśnij „Zamień”.
  „Zamień wszystkie” wymaga potwierdzenia i obejmuje cały dokument.
  Puste pole „Zamień na…” usuwa dopasowaną treść. Zmiany można cofnąć.
- Limit frazy i tekstu zamiany: po 1000 znaków. Wyszukiwanie nie oznacza dokumentu jako zmienionego.
- Poprawiono odświeżanie po automatycznym przesunięciu widoku poziomo do kursora/wyniku.

Edycja i zapis poprzedniej wersji zostały potwierdzone przez użytkownika.
Dla tej wersji sprawdzono lokalnie kompilację Java z API Androida i atrapami klas Fluttera,
a także testy argumentów wyszukiwania (Unicode, znaki specjalne, wielkość liter, kierunek,
zamiana na pusty tekst i ograniczenia wejścia). Nie uruchomiono lokalnie Fluttera ani APK;
pełny build i testy Flutter wykonuje GitHub Actions. Nowe operacje silnika trzeba sprawdzić na telefonie.

Krótki test: w kopii dokumentu utwórz listę, znajdź powtarzające się słowo, zamień jedno
wystąpienie, potem wszystkie pozostałe, użyj Cofnij i zapisz. Otwórz wynik na komputerze.
Sprawdź również wyszukanie słowa, którego nie ma, oraz polskie litery.
Nowe listy i zamiana dotyczą dokumentów Office; TXT zachowuje dotychczasowy edytor.

Implementacja poleceń odpowiada definicjom LibreOffice:
[rodzaje wyszukiwania](https://github.com/LibreOffice/core/blob/master/include/svl/srchitem.hxx)
i [testy wyszukiwania w widoku dokumentu](https://github.com/LibreOffice/core/blob/master/sw/qa/extras/tiledrendering/tiledrendering.cxx).

## Poprawki 0.5.1

- Usunięto pięć błędów analizatora w edytorze TXT: dekorację pola przypisaną do komunikatu
  błędu oraz odwołania do czterech usuniętych pól starego edytora DOCX.
- Nazwa widoczna na telefonie i w aplikacji: **Plikownik**.
- Nowa ikona: kremowy otwarty segregator na ciemnozielonym tle, z pomarańczową zakładką.
  Ikona adaptacyjna dopasowuje się do kształtu ikon telefonu.
- Identyfikator Androida i nazwa pakietu Dart pozostają bez zmian, więc projekt nadal buduje się
  w istniejącym repozytorium. Przy tym samym podpisie APK aktualizuje istniejącą aplikację.
- Dodano test komunikatu o błędzie zapisu TXT oraz ponowienia zapisu bez utraty treści.
- Lokalnie sprawdzono zmiany źródeł i XML. Analizator Flutter i testy interfejsu uruchamia GitHub Actions;
  nie wykonano ich lokalnie dla 0.5.1.

## Nowości 0.5.0

- Ołówek w DOCX, ODT, DOC i RTF otwiera żywy dokument w silniku LibreOffice.
  Dotknięcie tekstu ustawia kursor; klawiatura zmienia istniejącą treść.
  Przytrzymanie zaznacza słowo; niebieskie uchwyty pozwalają rozszerzyć zaznaczenie.
- Pasek narzędzi: pogrubienie, kursywa, podkreślenie, rozmiar czcionki,
  wyrównanie, cofnij/ponów, kopiuj/wytnij/wklej oraz zaznacz wszystko.
  Pasek można przewijać poziomo. Formatowanie dotyczy zaznaczenia lub dalszego pisania.
- Zapis przez „Zapisz jako” w tym samym formacie; przycisk PDF eksportuje bieżącą treść.
  Anulowanie okna zapisu pozostawia dokument w edytorze. Wyjście pyta o odrzucenie zmian.
  Po zapisaniu dokumentu aplikacja otwiera zapisaną kopię w podglądzie.
- Nowy DOCX otwiera się w tym samym edytorze. TXT ma osobny edytor całej treści.
- Widok edycji rysuje bieżący fragment dokumentu; nie konwertuje go do edytowalnego pola tekstowego.
  Powiększanie zachowuje punkt pod palcami. Nie zastępuje formatowania dokumentu własnym szablonem.
- Pozostaje poprawka stabilności powiększania podglądu PDF z 0.4.0.

**Nowy edytor wymaga testu na telefonie.** Lokalnie sprawdzono składnię Dart,
kompilację kodu Java z API Androida i atrapami interfejsów Fluttera oraz tworzenie DOCX.
Nie wykonano lokalnie `flutter analyze`, testów Flutter ani budowania APK;
wykonuje je dołączony GitHub Actions. Próby klawiatury, zaznaczania, zapisu przez LibreOffice
oraz porównanie wyniku na komputerze pozostają do wykonania na urządzeniu.
Test tworzenia DOCX nie jest testem zapisu przez żywy silnik.

## Zachowania z wersji 0.3.0

- Wstecz z pliku otwartego przez inną aplikację kończy podgląd bez pokazywania ekranu głównego.
- Wstecz z dokumentu wybranego w aplikacji wraca do listy ostatnich dokumentów.
- Lista ostatnich plików przechowuje maksymalnie 10 lokalnych kopii (łącznie do 200 MB).
  Są to kopie z chwili otwarcia; późniejsze zmiany oryginału nie odświeżają ich automatycznie.
- Lista zostaje po ponownym uruchomieniu aplikacji. Kosz usuwa nieprzypięte pozycje (od 0.8.0).
  Usuwane są wyłącznie prywatne kopie, nie oryginały w innych folderach/aplikacjach.

## Przewijanie z wersji 0.2.0

- Ciągłe przewijanie stron PDF i podglądów Office pionowo, palcem.
- Powiększanie dwoma palcami z zachowaniem przewijania; poziome przesuwanie po przybliżeniu.
- Doczytywanie widocznych stron i zwalnianie obrazów po ich opuszczeniu.
- Automatyczny licznik strony, skok do wybranej strony, dopasowanie szerokości.
- Identyfikator dokumentu chroni przed mieszaniem wyników renderowania przy zmianie pliku.
- Wersja poprzednia otwiera pliki poprawnie według testu użytkownika. Nowe przewijanie
  sprawdzono statycznie; załączony test interfejsu zostanie uruchomiony w GitHub Actions.

## Co jest w tej wersji

- Otwieranie plików przez przycisk lub Androidowe „Otwórz za pomocą”.
- PDF: ciągła lista stron, powiększanie gestem, wybór numeru strony.
- TXT i CSV: podgląd tekstu, wyszukiwanie z podświetleniem, zmiana wielkości tekstu w podglądzie.
- DOCX, ODT, DOC, RTF, XLSX, ODS i XLS: lokalna konwersja do podglądu PDF przez LibreOffice.
- Zapis kopii podglądu PDF do wybranego folderu. TXT/CSV nie mają jeszcze eksportu PDF.
- Jasny i ciemny interfejs zgodny z ustawieniem telefonu; papier dokumentu pozostaje biały.
- Podgląd nie zmienia pliku. W edytorze Office Zapisz może aktualizować plik, a Zapisz jako tworzy kopię.
  Aplikacja nie zawiera uprawnienia do internetu w wersji release.

**To prototyp do testów, nie zweryfikowany produkt końcowy.** Sprawdzono składnię Dart, strukturę projektu,
kompletność zasobów silnika, sumę kontrolną pakietu i obecność używanych funkcji JNI.
Nie zbudowano tutaj nowego APK ani nie uruchomiono nowego przewijania na urządzeniu. Testy Flutter i kompilacja
są uruchamiane przez załączony GitHub Actions. Testy interfejsu używają atrapy komunikacji z Androidem;
nie dowodzą poprawności renderowania LibreOffice.

## Uruchomienie — bez instalowania Fluttera i Javy

1. Na GitHubie utwórz repozytorium `dokumenty` i sklonuj je w GitHub Desktop.
2. Z rozpakowanego ZIP-a skopiuj **zawartość folderu `dokumenty`** do głównego folderu repozytorium.
   `pubspec.yaml` musi być bezpośrednio w katalogu repozytorium. Skopiuj również `.github` i `.gitignore`.
3. Zrób Commit, następnie Push origin.
4. Otwórz Actions → „Zbuduj Plikownik APK”. Pierwszy build pobiera dodatkowo około 84 MB silnika.
5. Gdy build będzie zielony, pobierz artefakt `plikownik-1.0.2-apk`.
6. Rozpakuj artefakt, prześlij `app-release.apk` na telefon i zainstaluj.
7. Otwórz aplikację i wybierz plik. Przy pierwszym dokumencie Office nastąpi przygotowanie silnika.
8. Aby otwierać pliki domyślnie: w menedżerze plików wybierz dokument → Otwórz za pomocą → Plikownik →
   Zawsze, jeśli Android udostępni tę opcję. Ustawienie może być osobne dla poszczególnych formatów.

Jeśli build jest czerwony, skopiuj log pierwszego nieudanego kroku. Jeśli aplikacja zamyka się przy
otwieraniu Office, podaj format, nazwę testowego pliku i moment zamknięcia. Nie nadpisuj oryginałów
testowymi eksportami.

## Wymagania i ograniczenia

- Android 8.0+ (API 26), procesor ARM64. Nie jest to paczka dla emulatora x86 ani starych urządzeń ARM32.
- Podgląd Office jest **podglądem wydruku**. Arkusz może zostać podzielony na wiele stron według ustawień
  wydruku zapisanych w pliku. Ta wersja nie ma siatki komórek ani zakładek arkuszy.
- Brakujące czcionki, inne wersje silnika i import formatów Microsoftu mogą zmienić układ. Nie ma gwarancji 1:1.
- W przypadku arkuszy obowiązują obszary wydruku i widoczność ustawione w oryginale; podgląd może nie pokazać
  komórek poza obszarem wydruku. Nie traktuj go jako pełnego przeglądu wszystkich danych skoroszytu.
- Edycja obejmuje tekst i podstawowe formatowanie. Przebudowa tabel, edycja obrazków, komentarze i śledzenie zmian nie mają kontrolek.
- Arkusze oraz PDF pozostają do odczytu. Wklejanie do edytora przenosi tekst bez formatowania; limit jednorazowego wklejenia to 20 000 znaków.
- Ochronę edycji obsługuje LibreOffice. Interfejs nie pozwala jej wyłączać. Zapis dokumentu podpisanego nie zachowuje ważności podpisu.
- Brak obsługi haseł i makr w interfejsie.
- PDF jest renderowany do obrazu strony: brak zaznaczania tekstu i wyszukiwania w PDF/Office w tej wersji.
- Limit pliku: 100 MB. TXT/CSV: 2 MB, automatyczne UTF-8/UTF-16 z BOM, w razie błędu UTF-8 Windows-1250.
- Pliki z błędnym rozszerzeniem, nietypową zawartością lub nieprawidłowym typem MIME mogą się nie otworzyć.
- Kopie robocze są w prywatnej pamięci podręcznej aplikacji. Stare kopie są sprzątane przy otwieraniu plików
  po upływie doby; Android również może wyczyścić cache. Pliki źródłowe pozostają w swoich folderach.
- Dostawca plików z chmury może potrzebować internetu, by pobrać plik. Sama aplikacja go nie pobiera —
  do pracy offline wybieraj dokumenty już zapisane na telefonie.

## Podpis i kolejne aktualizacje

Od 1.0.1 wymagane są wszystkie cztery sekrety opisane na początku tego pliku.
Podpis testowy jest wyłączony. Nie umieszczaj klucza ani haseł w repozytorium.
Po pierwszej instalacji ze stałym kluczem kolejne APK instaluj jako aktualizację.

## Test na telefonie

1. W trybie samolotowym otwórz lokalny DOCX i naciśnij ołówek.
2. Dotknij środka istniejącego zdania, wpisz „zażółć gęślą jaźń”, usuń kilka liter i naciśnij Enter.
3. Przytrzymaj słowo, przeciągnij uchwyt zaznaczenia, użyj B, I, U i rozmiaru czcionki.
4. Cofnij i ponów zmianę. Skopiuj, wytnij i wklej krótki fragment.
5. Powiększ dwoma palcami; przewijaj pionowo i poziomo. Sprawdź położenie kursora po pokazaniu klawiatury.
6. Anuluj „Zapisz jako”: zmiany powinny pozostać. Następnie zapisz kopię jako DOCX.
7. Otwórz kopię w LibreOffice na komputerze: sprawdź zmienione zdania, tabelę i obrazek.
8. Powtórz dla ODT, następnie DOC/RTF, jeśli ich używasz. Sprawdź też PDF wyeksportowany z edytora.
9. Otwórz plik z komunikatora. Po zamknięciu edytora i podglądu powinien pojawić się komunikator.
10. Sprawdź nowy DOCX, edycję TXT oraz odrzucenie niezapisanych zmian.

Silnik LibreOffice dąży do zachowania struktury i układu, ale nie zapewnia zgodności wyglądu 1:1
z każdą wersją Microsoft Word ani z brakującymi na telefonie czcionkami. Pierwsze próby wykonuj na kopiach.

## Kod i budowanie

- `native/` zawiera pliki Androida przywracane po wygenerowaniu projektu.
- `OfficeEditor.java` obsługuje żywy widok, klawiaturę, zaznaczenie, komendy UNO i zapis.
- `DocumentEdits.java` służy w aplikacji wyłącznie do utworzenia pustego nowego DOCX.
- Zmieniono deklarację Java `Document.saveAs` na `int`, zgodnie z wartością zwracaną przez JNI silnika;
  edytor sprawdza rezultat zapisu. Nie zmieniono binarnego silnika LibreOffice.
- `flutter analyze` i `flutter test` są wymagane przed zbudowaniem APK w Actions.
- Testy Flutter sprawdzają przekazanie dokumentów do edycji, ponowne otwarcie zapisu, anulowanie TXT
  oraz wcześniejsze otwieranie i gesty podglądu. Nie uruchamiają silnika LibreOffice.
- Zachowaj katalog `.github` podczas kopiowania projektu.

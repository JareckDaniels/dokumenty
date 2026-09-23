# Plikownik 0.8.0 — wersja testowa

Prosty czytnik dokumentów na Androida, interfejs we Flutterze.
Silnik LibreOffice 26.2.6.3 pracuje wewnątrz aplikacji, bez serwera i bez instalowania drugiej aplikacji.

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
5. Gdy build będzie zielony, pobierz artefakt `plikownik-0.8.0-apk`.
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

Pierwsza wersja może budować się bez sekretów na tymczasowym kluczu testowym. Kolejny build w nowym
środowisku GitHub może mieć inny podpis i wymagać odinstalowania poprzedniej wersji. Odinstalowanie usuwa listę ostatnich dokumentów i jej prywatne kopie, ale nie usuwa plików źródłowych
z folderu Pobrane. Usuwa cache i ustawienia samej aplikacji.

Przed zwykłym użytkowaniem kolejnych wersji skonfiguruj stały klucz przez sekrety Actions:
`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`.
Podaj wszystkie cztery albo żaden. Nie umieszczaj klucza i haseł w repozytorium.
Przejście z podpisu testowego na stały wymaga odinstalowania wersji testowej.

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

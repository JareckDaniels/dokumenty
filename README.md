# Dokumenty 0.4.0 — wersja testowa

Prosty czytnik dokumentów na Androida, interfejs we Flutterze.
Silnik LibreOffice 26.2.6.3 pracuje wewnątrz aplikacji, bez serwera i bez instalowania drugiej aplikacji.

## Nowości 0.4.0

- Stabilizacja powiększania: podczas gestu zmienia się wyłącznie transformacja obrazu.
  Układ listy przeliczany jest po zakończeniu gestu, a pozycja korygowana w fazie układania,
  przed rysowaniem. Wszystkie strony i odstępy skalują się proporcjonalnie.
- DOCX: przycisk ołówka otwiera dopisywanie nowych akapitów na końcu dokumentu.
  Dostępne są rozmiar czcionki, pogrubienie i kursywa dla dopisywanego tekstu.
  Zapis tworzy nowy DOCX; nie przechodzi przez PDF ani konwersję istniejącej treści.
- TXT: edycja całej treści i zapis nowej kopii UTF-8.
- Przycisk „Nowy dokument”: tworzenie DOCX albo TXT.
- „Zapisz jako” otwiera wybór folderu w Androidzie. Anulowanie pozostawia wpisany tekst w edytorze.
  Wyjście z niezapisanej edycji wymaga potwierdzenia odrzucenia zmian.
- Po zapisaniu aplikacja otwiera nowy plik w podglądzie. Limit edytora: 200 000 znaków.

Dopisywanie DOCX sprawdzono na przesłanych dokumentach, w tym na pliku z tabelami i obrazkiem:
oryginalne elementy XML i wszystkie inne składniki ZIP zachowały treść. Przeszły testy Unicode,
formatowania i utworzenia nowego DOCX, wykonane lokalnie w Javie. Testy gestów i interfejsu są
załączone do GitHub Actions; nowego APK nie uruchomiono jeszcze na telefonie.

## Zachowania z wersji 0.3.0

- Wstecz z pliku otwartego przez inną aplikację kończy podgląd bez pokazywania ekranu głównego.
- Wstecz z dokumentu wybranego w aplikacji wraca do listy ostatnich dokumentów.
- Lista ostatnich plików przechowuje maksymalnie 10 lokalnych kopii (łącznie do 200 MB).
  Są to kopie z chwili otwarcia; późniejsze zmiany oryginału nie odświeżają ich automatycznie.
- Lista zostaje po ponownym uruchomieniu aplikacji. Można ją wyczyścić przyciskiem kosza.
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
- Operacje edycji tworzą nowy plik przez „Zapisz jako”. Podgląd nie zmienia oryginału. Nie zawiera uprawnienia do internetu w wersji release.

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
4. Otwórz Actions → „Zbuduj Dokumenty APK”. Pierwszy build pobiera dodatkowo około 84 MB silnika.
5. Gdy build będzie zielony, pobierz artefakt `dokumenty-0.4.0-apk`.
6. Rozpakuj artefakt, prześlij `app-release.apk` na telefon i zainstaluj.
7. Otwórz aplikację i wybierz plik. Przy pierwszym dokumencie Office nastąpi przygotowanie silnika.
8. Aby otwierać pliki domyślnie: w menedżerze plików wybierz dokument → Otwórz za pomocą → Dokumenty →
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
- Edycja DOCX w tej wersji to dopisywanie na końcu; brak zmiany istniejących zdań i formatowania wybranych fragmentów.
- ODT, DOC, arkusze, RTF i PDF pozostają do odczytu. Nie ma jeszcze ich edycji.
- Dokumenty DOCX z włączoną ochroną edycji lub podpisem cyfrowym nie są modyfikowane.
- Brak obsługi haseł i makr w interfejsie.
- PDF jest renderowany do obrazu strony: brak zaznaczania tekstu i wyszukiwania w PDF/Office w tej wersji.
- Limit pliku: 100 MB. TXT/CSV: 2 MB, automatyczne UTF-8/UTF-16 z BOM, w razie błędu UTF-8 Windows-1250.
- Pliki z błędnym rozszerzeniem, nietypową zawartością lub nieprawidłowym typem MIME mogą się nie otworzyć.
- Kopie robocze są w prywatnej pamięci podręcznej aplikacji. Stare kopie są sprzątane przy otwieraniu plików
  po upływie doby; Android również może wyczyścić cache. Oryginalne pliki pozostają w swoich folderach.
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

1. Włącz tryb samolotowy i otwórz lokalny PDF, TXT, DOCX, ODT, XLSX oraz ODS.
2. Sprawdź polskie znaki, przechodzenie między stronami, powiększenie i otwieranie drugiego pliku.
3. Sprawdź rachunek ODS ze scaleniami i kalkulator z formułami względem podglądu wydruku w LibreOffice.
4. W DOCX z tabelami porównaj tabele, obraz, kolejność stron i końcówki tekstu.
5. Zapisz podgląd do nowego PDF i otwórz go na komputerze.
6. Otwórz załącznik z poczty przez „Otwórz za pomocą”.
7. Sprawdź odmowę dostępu, anulowanie wyboru i błędny plik: powinien pojawić się komunikat, nie utrata oryginału.

Przesłane przez użytkownika przykładowe dokumenty **nie są dołączone do projektu** i nie wolno ich
wgrywać do publicznego repozytorium jako danych testowych.

## Dla kolejnej iteracji

Własne pliki Androida są w `native/` i `szablony/`, ponieważ `android/` powstaje na nowo przy buildzie.
Nie edytuj wygenerowanego `android/`. Flutter jest przypięty do 3.38.5. Używamy zgodnego zestawu
Gradle/AGP/Kotlin wygenerowanego przez tę wersję Fluttera, zamiast nadpisywać go starszym zestawem.
Silnik jest pobierany z przypiętego pakietu F-Droid i sprawdzany SHA-256. Zawarte w nim biblioteki są
niezmienione. Źródła Java JNI pochodzą z tego samego wydania LibreOffice, z jedną opisaną poprawką obsługi błędu.

Moduł `DocumentEdits.java` wykonuje ograniczoną edycję DOCX: dodaje akapity przed końcowym
`sectPr` w `word/document.xml`, zachowując pozostałe wpisy ZIP bez zmian. To nie jest pełny edytor
WYSIWYG. Docelowa edycja w dowolnym miejscu dokumentu i arkuszy nadal wymaga osobnej integracji.
Test `test_native/DocumentEditsTest.java` sprawdza tworzenie, dopisywanie, polskie znaki, emoji,
formatowanie i zachowanie oryginału. Własne przykłady użytkownika nie są pakowane do repozytorium.

Źródła i pełne informacje licencyjne silnika znajdują się w `licenses/NOTICE.txt` oraz w aplikacji.
Kod własny: MIT; pliki z LibreOffice i komponenty silnika zachowują własne licencje.

# Dokumenty 0.5.0 — wersja testowa

Prosty czytnik dokumentów na Androida, interfejs we Flutterze.
Silnik LibreOffice 26.2.6.3 pracuje wewnątrz aplikacji, bez serwera i bez instalowania drugiej aplikacji.

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
5. Gdy build będzie zielony, pobierz artefakt `dokumenty-0.5.0-apk`.
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
- Edycja obejmuje tekst i podstawowe formatowanie. Przebudowa tabel, edycja obrazków, komentarze i śledzenie zmian nie mają kontrolek.
- Arkusze oraz PDF pozostają do odczytu. Wklejanie do edytora przenosi tekst bez formatowania; limit jednorazowego wklejenia to 20 000 znaków.
- Ochronę edycji obsługuje LibreOffice. Interfejs nie pozwala jej wyłączać. Zapis dokumentu podpisanego nie zachowuje ważności podpisu.
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

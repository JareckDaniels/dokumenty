# Dokumenty 0.1.1 — wersja testowa

Prosty czytnik dokumentów na Androida, interfejs we Flutterze.
Silnik LibreOffice 26.2.6.3 pracuje wewnątrz aplikacji, bez serwera i bez instalowania drugiej aplikacji.

## Poprawka 0.1.1

Usunięto zbędny import `dart:typed_data`, który zatrzymywał krok `flutter analyze`.
Numer kompilacji podniesiono do 2. Pozostałe funkcje bez zmian.

## Co jest w tej wersji

- Otwieranie plików przez przycisk lub Androidowe „Otwórz za pomocą”.
- PDF: strony, powiększanie gestem, wybór numeru strony.
- TXT i CSV: podgląd tekstu, wyszukiwanie z podświetleniem, zmiana wielkości tekstu w podglądzie.
- DOCX, ODT, DOC, RTF, XLSX, ODS i XLS: lokalna konwersja do podglądu PDF przez LibreOffice.
- Zapis kopii podglądu PDF do wybranego folderu. TXT/CSV nie mają jeszcze eksportu PDF.
- Jasny i ciemny interfejs zgodny z ustawieniem telefonu; papier dokumentu pozostaje biały.
- Aplikacja nie zmienia oryginalnego pliku. Nie zawiera uprawnienia do internetu w wersji release.

**To prototyp do testów, nie zweryfikowany produkt końcowy.** Sprawdzono składnię Dart, strukturę projektu,
kompletność zasobów silnika, sumę kontrolną pakietu i obecność używanych funkcji JNI.
Nie uruchomiono tutaj aplikacji na urządzeniu ani nie zbudowano APK. Testy Flutter i kompilacja
są uruchamiane przez załączony GitHub Actions. Testy interfejsu używają atrapy komunikacji z Androidem;
nie dowodzą poprawności renderowania LibreOffice.

## Uruchomienie — bez instalowania Fluttera i Javy

1. Na GitHubie utwórz repozytorium `dokumenty` i sklonuj je w GitHub Desktop.
2. Z rozpakowanego ZIP-a skopiuj **zawartość folderu `dokumenty`** do głównego folderu repozytorium.
   `pubspec.yaml` musi być bezpośrednio w katalogu repozytorium. Skopiuj również `.github` i `.gitignore`.
3. Zrób Commit, następnie Push origin.
4. Otwórz Actions → „Zbuduj Dokumenty APK”. Pierwszy build pobiera dodatkowo około 84 MB silnika.
5. Gdy build będzie zielony, pobierz artefakt `dokumenty-0.1.1-apk`.
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
- Bez edycji, zapisu Office, makr w interfejsie i obsługi dokumentów chronionych hasłem.
- PDF jest renderowany do obrazu strony: brak zaznaczania tekstu i wyszukiwania w PDF/Office w tej wersji.
- Limit pliku: 100 MB. TXT/CSV: 2 MB, automatyczne UTF-8/UTF-16 z BOM, w razie błędu UTF-8 Windows-1250.
- Pliki z błędnym rozszerzeniem, nietypową zawartością lub nieprawidłowym typem MIME mogą się nie otworzyć.
- Kopie robocze są w prywatnej pamięci podręcznej aplikacji. Stare kopie są sprzątane przy otwieraniu plików
  po upływie doby; Android również może wyczyścić cache. Oryginalne pliki pozostają w swoich folderach.
- Dostawca plików z chmury może potrzebować internetu, by pobrać plik. Sama aplikacja go nie pobiera —
  do pracy offline wybieraj dokumenty już zapisane na telefonie.

## Podpis i kolejne aktualizacje

Pierwsza wersja może budować się bez sekretów na tymczasowym kluczu testowym. Kolejny build w nowym
środowisku GitHub może mieć inny podpis i wymagać odinstalowania poprzedniej wersji. Aplikacja na tym
etapie nie przechowuje własnych dokumentów ani edycji, a odinstalowanie nie usuwa plików źródłowych
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

Dodanie edycji wymaga osobnego widoku edytora i testów zapisu/ponownego otwarcia. Obecny podgląd PDF
nie jest edytorem Office i nie wystarczy do niego samo dołożenie przycisków. Użyty silnik udostępnia
funkcje edycji, ale nie zostały one jeszcze zintegrowane.

Źródła i pełne informacje licencyjne silnika znajdują się w `licenses/NOTICE.txt` oraz w aplikacji.
Kod własny: MIT; pliki z LibreOffice i komponenty silnika zachowują własne licencje.

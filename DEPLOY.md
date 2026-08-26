# CalisLevel — uruchomienie za 0 zł

## 1. Supabase
1. Załóż darmowy projekt Supabase.
2. Otwórz **SQL Editor**.
3. Wklej cały plik `supabase/INSTALL_ALL.sql` i kliknij **Run**.
4. W **Project Settings / API Keys** skopiuj:
   - Project URL
   - Publishable key (ew. anon key w starszym widoku)
5. Otwórz `config.js` i wpisz te dwie wartości.

**Nigdy nie wklejaj do aplikacji klucza `service_role`.** Frontend ma korzystać wyłącznie z publicznego/publishable klucza, a prywatność wymusza Row Level Security z `INSTALL_ALL.sql`.

## 2. Auth
W Supabase ustaw **Site URL** na adres GitHub Pages, np.:
`https://twoj-login.github.io/calislevel/`

Jeśli zostawisz potwierdzanie adresu e-mail, nowy użytkownik musi kliknąć link z wiadomości. Dla zamkniętej grupy kumpli możesz w ustawieniach Auth zdecydować, czy chcesz wymagać potwierdzania e-mail.

## 3. GitHub Pages
W repozytorium umieść **zawartość** folderu CalisLevel (nie ZIP):
- `index.html`
- `styles.css`
- `app.js`
- `config.js`
- `manifest.webmanifest`
- `sw.js`
- `icons/`

Folder `supabase/` i dokumentację możesz również zostawić w repo — aplikacji to nie przeszkadza.

GitHub → repo → Settings → Pages → Deploy from a branch → `main` → `/(root)`.

## 4. iPhone
1. Otwórz adres GitHub Pages w Safari.
2. Udostępnij.
3. **Do ekranu początkowego**.
4. Uruchamiaj CalisLevel z ikony.

## 5. Pierwsze konto
Po rejestracji wejdź w **Plany** i kliknij **„Dodaj 3 gotowe plany Calis Athletic”**. Marcin lub inny zaawansowany użytkownik może ten przycisk zignorować i od razu stworzyć własne plany.

## Co jest w bazie
- 387 ćwiczeń startowych + nielimitowane ćwiczenia własne,
- planowanie i logowanie treningów,
- serie, kg, powtórzenia, RPE, timer,
- XP, CalisScore, streak, ranking lifetime i sezonowy,
- kalisteniczne skille,
- pomiary i PR,
- kalkulator BMR/TDEE, cele kcal i makro,
- dziennik jedzenia + własne produkty,
- baza przykładowych podstawowych produktów,
- suplementy, dawka, dni i godzina,
- kalendarz treningów i innych wpisów,
- profile publiczne/prywatne,
- RLS izolujące prywatne dane użytkowników.

## Backup / darmowy hosting
Frontend jest statyczny i działa na GitHub Pages. Dane są w Supabase, dzięki czemu logowanie na drugim urządzeniu pokazuje te same dane użytkownika. PWA cache'uje sam interfejs; do synchronizacji danych potrzebny jest internet.

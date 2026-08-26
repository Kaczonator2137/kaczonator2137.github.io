# CalisLevel

Darmowa PWA do treningu, kalisteniki, odżywiania, suplementacji i rywalizacji ze znajomymi.

## Główne moduły
- **Konta i synchronizacja** — Supabase Auth + PostgreSQL.
- **Trening** — plany własne, aktywna sesja, serie, kg, powtórzenia, RPE, timer przerw.
- **3 plany Calis Athletic** — opcjonalny starter pod atletyczną/kalisteniczną sylwetkę.
- **Ćwiczenia** — 489 pozycji po zastosowaniu najnowszej migracji oraz dowolne własne ćwiczenia.
- **Ranking** — CalisScore, sezon, lifetime XP, streak.
- **Dieta** — Mifflin-St Jeor, TDEE, cel masa/utrzymanie/redukcja, makro, dziennik jedzenia.
- **Suplementy** — nazwa, dawka, jednostka, dni, godzina, checklista.
- **Kalendarz** — treningi, pomiary, regeneracja i notatki.
- **Progres** — pomiary, skille i rekordy.
- **Prywatność** — RLS; publiczne są tylko dane potrzebne do profilu/rankingu, jeśli użytkownik ustawi profil publiczny.

## Ranking
CalisScore celowo nie jest prostym rankingiem „kto podnosi najwięcej”. Uwzględnia XP, wykonane treningi, streak i opanowane skille. Jest też osobny sezonowy XP, dzięki czemu nowi użytkownicy mogą rywalizować z osobami mającymi dłuższą historię konta.

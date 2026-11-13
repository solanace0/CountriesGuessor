# CountriesGuessor

Игра-угадайка стран и городов с онлайном (друзья, лобби, синхронные матчи) на Supabase.

## Структура
- `index.html` — вся игра одним файлом (Project URL Supabase и publishable-ключ уже вшиты)
- `supabase/1_schema.sql`, `supabase/2_entities.sql` — база данных (запускаются один раз)

## 1. Supabase (один раз)
1. Supabase → **SQL Editor → New query**: вставьте `supabase/1_schema.sql` → **Run**.
2. Новый запрос: вставьте `supabase/2_entities.sql` → **Run**. Внизу должно быть `entities_loaded = 5663`.
3. **Authentication → Sign In / Providers → Email → Confirm email = OFF** → Save. Без этого регистрация не завершится.
4. Секретный ключ `sb_secret_...` в код и на GitHub не кладите никогда. Если он где-то светился, пересоздайте его (Settings → API Keys).

## 2. GitHub
1. github.com → **New repository** → имя, например `countries-guessor` → Create.
2. На странице репозитория: **uploading an existing file**. Распакуйте архив и перетащите в окно ВСЁ содержимое: `index.html`, папку `supabase`, `README.md`, `.nojekyll` → **Commit changes**.
   (Лимит веб-загрузки GitHub — 25 МБ на файл, `index.html` весит около 14 МБ, это подходит.)

## 3a. Vercel (рекомендую)
1. vercel.com → войдите через GitHub → **Add New → Project** → выберите репозиторий → **Import**.
2. Framework Preset: **Other**. Build Command и Output Directory оставьте пустыми → **Deploy**.
3. Через минуту получите адрес вида `https://countries-guessor.vercel.app`. Любое изменение в GitHub обновляет сайт само.

## 3b. GitHub Pages (вместо Vercel)
Settings → Pages → Source: **Deploy from a branch** → Branch: `main`, папка `/ (root)` → Save. Адрес: `https://ВАШ_НИК.github.io/countries-guessor/`.

## 4. Проверка онлайна
Откройте сайт → «Онлайн» → зарегистрируйте два онлайн-аккаунта в двух браузерах (или обычном и приватном окне) → добавьте друг друга в друзья → «Играть».

## Если что-то не работает
- «На сервере нет таблиц или функций» — не выполнены SQL-скрипты.
- «Подтверждение почты» — не выключен Confirm email.
- «Нет связи с сервером» — проверьте Project URL в начале онлайн-блока кода `OL_CFG` в `index.html`.
- Ошибки Realtime/матч не обновляется — Database → Publications → `supabase_realtime` должна содержать `cg_matches` и `cg_friendships`.

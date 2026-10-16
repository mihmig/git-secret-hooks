# git-secret-hooks

Глобальный git-хук, который не даёт закоммитить секреты: `.env`,
`http-client.private.env.json`, приватные ключи — и токены, вписанные прямо в код.

Ставится один раз на машину и работает во **всех** репозиториях, включая те, которые
вы склонируете завтра. Один и тот же скрипт работает в git-bash на Windows и в обычном
`sh` на Linux.

## Зачем это нужно

Токен, попавший в git, нельзя «просто удалить». Как только коммит ушёл на сервер:

- его видят форки, зеркала, кэш GitHub и чужие локальные копии;
- публичные репозитории постоянно сканируют боты — счёт идёт на минуты, а не на дни;
- `git commit --amend` и `git push --force` переписывают историю, но **не отзывают** сам
  токен: у того, кто его уже забрал, он продолжает работать.

Поэтому после утечки порядок такой: **сначала отозвать** секрет (для Telegram-бота —
`/revoke` у [@BotFather](https://t.me/BotFather)), выдать новый, и только потом думать об
истории. Этот хук решает другую задачу — чтобы следующего раза не было: он срабатывает
до создания коммита, когда отзывать ещё нечего.

Хук — локальная защита на вашей машине. Он не заменяет серверную (GitHub Secret
scanning → Push protection), а дополняет её: ловит проблему раньше и работает в том
числе с приватными репозиториями и с self-hosted git.

## Что внутри

```
hooks/pre-commit   сам хук
install.sh         установка (Linux, macOS, git-bash)
remove.sh          удаление
install.cmd        то же для Windows: обёртка, вызывает install.sh через sh.exe от Git
remove.cmd         то же для удаления
.gitattributes     фиксирует LF в sh-файлах — иначе autocrlf сломает хук при клоне
```

## Установка

**Linux, macOS, git-bash:**

```bash
git clone <этот-репозиторий> git-secret-hooks && cd git-secret-hooks && ./install.sh
```

**Windows:** двойной клик по `install.cmd` или из cmd/PowerShell:

```bat
install.cmd
```

Установщик кладёт хук в `~/.config/git/hooks/pre-commit`, прописывает
`core.hooksPath = ~/.config/git/hooks` в глобальный `.gitconfig` и запускает
самопроверку на временном репозитории:

```
✔ хук установлен: C:/Users/user/.config/git/hooks/pre-commit
✔ core.hooksPath = ~/.config/git/hooks
✔ самопроверка пройдена: секреты блокируются, чистый коммит проходит
```

Значение с тильдой git раскрывает сам, поэтому одна и та же настройка одинаково верна
на Windows и на Linux.

### Ключи install.sh

| Ключ | Зачем |
|------|-------|
| `--hooks-dir DIR` | положить хук в другой каталог (по умолчанию `~/.config/git/hooks`) |
| `--no-config` | не менять `core.hooksPath` — например, чтобы поставить хук в `.git/hooks` одного репозитория |
| `--no-test` | пропустить самопроверку |
| `--force` | перезаписать `core.hooksPath`, если он уже указывает на другой каталог (прежнее значение сохранится и вернётся при `remove.sh`) |

Без `--force` установщик не затирает чужой `core.hooksPath`, а останавливается и
объясняет варианты. Ключи `.cmd` принимает те же: `install.cmd --no-test`.

## Что блокируется

**Файлы — по имени, в любом каталоге:**

| Шаблон | Что это |
|--------|---------|
| `.env`, `.env.*` | переменные окружения. Шаблоны `.env.example`, `.env.sample`, `.env.template`, `.env.dist` разрешены |
| `*.private.env.json` | в том числе `http-client.private.env.json` от IDE JetBrains |
| `id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519` | приватные SSH-ключи |
| `*.key`, `*.p12`, `*.pfx`, `*.jks`, `*.keystore` | ключи и хранилища сертификатов |
| `.netrc`, `_netrc`, `.pgpass` | файлы с паролями |
| `*.tfstate`, `*.tfstate.backup`, `*.tfvars` | состояние и переменные Terraform |
| `credentials.json`, `client_secret*.json`, `service-account*.json` | ключи сервисных аккаунтов Google |

**Строки в добавляемом коде** — это важнее списка файлов, потому что токен чаще попадает
прямо в `config.py` или `bot.py`, а не в аккуратный `.env`:

токены Telegram-ботов, блоки `-----BEGIN PRIVATE KEY-----`, ключи AWS (`AKIA…`), токены
GitHub (`ghp_…`, `github_pat_…`), GitLab (`glpat-…`), Slack (`xoxb-…`), ключи OpenAI и
Anthropic (`sk-…`, `sk-ant-…`).

Проверяются только добавляемые строки в индексе, поэтому `git add -f` защиту не обходит.

## Примеры

Попытка закоммитить всё подряд:

```console
$ git add -A && git commit -m "бот"
✖ Эти файлы нельзя коммитить:
    .env
    api/http-client.private.env.json
  → git rm --cached <файл> и добавьте его в .gitignore
✖ Похоже на секреты в коде:
  bot.py:
      token = "123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawx"
Коммит отменён. Ложное срабатывание? git commit --no-verify
```

Убираем лишнее из индекса — и коммит проходит:

```console
$ git rm --cached .env api/http-client.private.env.json
$ git commit -m "бот"
[main a1b2c3d] бот
 2 files changed, 12 insertions(+)
```

Ложное срабатывание (например, тестовая фикстура с заведомо недействительным ключом):

```bash
git commit --no-verify -m "фикстура для теста парсера"
```

Проверить хук, ничего не коммитя:

```bash
git add -A && sh ~/.config/git/hooks/pre-commit; echo "код: $?"
```

## Удаление

```bash
./remove.sh
```

```bat
remove.cmd
```

`remove.sh` удаляет только свой хук (узнаёт его по метке `git-secret-hooks` в первых
строках) и возвращает `core.hooksPath` к прежнему значению, а если его не было — сбрасывает
настройку. Чужой хук и чужой `core.hooksPath` он не трогает, а сообщает о них.

## Чего хук не делает

- **Не защищает коллег.** Он стоит у вас на машине; у остальных — нет. Командная защита
  живёт на сервере: GitHub Secret scanning с push protection, GitLab Secret Detection,
  или [gitleaks](https://github.com/gitleaks/gitleaks) в CI.
- **Не работает в husky-репозиториях.** Husky и `pre-commit` прописывают
  `core.hooksPath` на уровне репозитория, а локальная настройка важнее глобальной. Там
  поставьте хук внутрь репозитория: `./install.sh --hooks-dir .git/hooks --no-config`
  (или добавьте его в цепочку husky).
- **Отключает `.git/hooks` в остальных репозиториях** — это поведение самого
  `core.hooksPath`. Для `pre-commit` это обойдено: в конце наш хук сам запускает
  `.git/hooks/pre-commit` репозитория, если тот есть (зацикливания нет: свою же копию
  он узнаёт по метке, а повторный вызов — по переменной `GIT_SECRET_HOOKS_CHAINED`).
  Но локальные `commit-msg`,
  `pre-push` и прочие без такой обёртки работать перестанут — если они у вас есть,
  скопируйте их в `~/.config/git/hooks/`.
- **Не ищет секреты в уже существующей истории.** Для этого есть
  [gitleaks](https://github.com/gitleaks/gitleaks) (`gitleaks detect`), а для вычистки —
  [git-filter-repo](https://github.com/newren/git-filter-repo) или BFG. И помните: чистка
  истории бессмысленна без отзыва токена.
- **Ловит не всё.** Это набор шаблонов, а не анализатор. Пароль в виде
  `password = "qwerty123"` он не заметит.

## Как добавить свои правила

Правила — обычный `sh`, править можно прямо в `hooks/pre-commit`, а потом запустить
`./install.sh` ещё раз.

Новый запрещённый файл — ветка `case` в блоке 1:

```sh
    secrets.yaml|*.secrets.yaml)                        echo "$path" ;;
```

Новый шаблон токена — строка в блоке 2 (регулярка в формате `grep -E`):

```sh
re="$re|ya29\.[A-Za-z0-9_-]{50,}"                        # Google OAuth access token
```

Разрешить файл, который сейчас блокируется, — добавьте его к пустой ветке-исключению
в начале `case`:

```sh
    .env.example|.env.sample|.env.template|.env.dist|.env.ci) ;;
```

## Полезное дополнение: глобальный gitignore

Чтобы секретные файлы вообще не мелькали в `git status` и не попадали в индекс
случайно:

```bash
git config --global core.excludesFile '~/.config/git/ignore'
```

```bash
printf '.env\n.env.*\n!.env.example\n*.private.env.json\n' >> ~/.config/git/ignore
```

Хук при этом остаётся второй линией: `.gitignore` не спасает от `git add -f` и не
смотрит внутрь кода, а хук делает и то, и другое.

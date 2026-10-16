#!/bin/sh
# install.sh — ставит глобальный pre-commit хук, запрещающий коммит секретов.
#
# Использование: ./install.sh [ключи]
#   --hooks-dir DIR  куда положить хук (по умолчанию ~/.config/git/hooks)
#   --no-config      не менять core.hooksPath (например, для husky-репозиториев)
#   --no-test        не запускать самопроверку после установки
#   --force          перезаписать core.hooksPath, если он уже указывает на другой каталог
#   -h, --help       эта справка
set -eu

MARKER='git-secret-hooks'
say() { printf '%s\n' "$*"; }
die() { printf 'ОШИБКА: %s\n' "$*" >&2; exit 1; }

hooks_dir=''
set_config=1
run_test=1
force=0

while [ $# -gt 0 ]; do
  case "$1" in
    --hooks-dir)   [ $# -ge 2 ] || die "--hooks-dir требует путь"; hooks_dir=$2; shift 2 ;;
    --hooks-dir=*) hooks_dir=${1#*=}; shift ;;
    --no-config)   set_config=0; shift ;;
    --no-test)     run_test=0; shift ;;
    --force)       force=1; shift ;;
    -h|--help)     sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             die "неизвестный аргумент: $1 (см. --help)" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git не найден в PATH"
[ -n "${HOME:-}" ] || die "переменная HOME не задана"

src_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
hook_src="$src_dir/hooks/pre-commit"
[ -f "$hook_src" ] || die "не найден файл хука: $hook_src"
sh -n "$hook_src" || die "в $hook_src синтаксическая ошибка"

[ -n "$hooks_dir" ] || hooks_dir="$HOME/.config/git/hooks"
mkdir -p "$hooks_dir" || die "не удалось создать каталог $hooks_dir"
# абсолютный путь: относительный сломал бы самопроверку, она работает из временного каталога
hooks_dir=$(CDPATH= cd -- "$hooks_dir" && pwd) || die "не удалось открыть каталог $hooks_dir"
dest="$hooks_dir/pre-commit"

# ---------- не затираем чужой core.hooksPath молча ----------
if [ "$set_config" -eq 1 ]; then
  current=$(git config --global --get core.hooksPath 2>/dev/null || true)
  current_abs=''
  case "$current" in
    '')    ;;
    '~/'*) current_abs="$HOME/${current#\~/}" ;;
    *)     current_abs=$current ;;
  esac
  if [ -n "$current_abs" ] && [ "$current_abs" != "$hooks_dir" ]; then
    [ "$force" -eq 1 ] || die "core.hooksPath уже указывает на $current
  Варианты: скопировать hooks/pre-commit туда вручную, запустить с --no-config
  или с --force (прежнее значение сохранится и вернётся при remove.sh)."
    git config --global gitsecrethooks.previousHooksPath "$current"
    say "! прежний core.hooksPath ($current) сохранён для remove.sh"
  fi
fi

# ---------- установка ----------
if [ -e "$dest" ] && ! grep -q -- "$MARKER" "$dest" 2>/dev/null; then
  backup="$dest.bak.$(date +%Y%m%d%H%M%S)"
  cp -- "$dest" "$backup"
  say "! ваш прежний хук сохранён: $backup"
fi
cp -- "$hook_src" "$dest"
chmod +x "$dest"
say "✔ хук установлен: $dest"

if [ "$set_config" -eq 1 ]; then
  value=$hooks_dir
  case "$hooks_dir" in
    "$HOME"/*) value="~/${hooks_dir#"$HOME"/}" ;;   # с тильдой работает и на Windows, и на Linux
  esac
  git config --global core.hooksPath "$value"
  say "✔ core.hooksPath = $value"
else
  say "— core.hooksPath не менялся (--no-config)"
fi

# ---------- самопроверка на временном репозитории ----------
if [ "$run_test" -eq 1 ]; then
  tmp=$(mktemp -d) || die "не удалось создать временный каталог"
  trap 'rm -rf "$tmp"' EXIT HUP INT TERM
  rc=0
  (
    cd "$tmp"
    git init -q .
    printf 'TOKEN=secret\n' > .env
    printf 'token = "123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsawx"\n' > bot.py
    printf 'print(1)\n' > main.py
    git add -A 2>/dev/null
    sh "$dest" >/dev/null 2>&1 && exit 1   # секреты в индексе — хук обязан запретить
    git rm -q --cached .env bot.py
    sh "$dest" >/dev/null 2>&1 || exit 2   # чистый индекс — хук обязан разрешить
    exit 0
  ) || rc=$?
  case "$rc" in
    0) say "✔ самопроверка пройдена: секреты блокируются, чистый коммит проходит" ;;
    1) die "самопроверка: хук НЕ заблокировал секреты" ;;
    2) die "самопроверка: хук запретил чистый коммит" ;;
    *) die "самопроверка не прошла (код $rc)" ;;
  esac
fi

say ''
say 'Готово. Хук работает во всех репозиториях этой машины, включая новые.'
say 'Обойти разово:   git commit --no-verify'
say 'Удалить:         ./remove.sh'

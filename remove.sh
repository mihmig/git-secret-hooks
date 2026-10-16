#!/bin/sh
# remove.sh — удаляет глобальный pre-commit хук git-secret-hooks.
#
# Использование: ./remove.sh [ключи]
#   --hooks-dir DIR  откуда удалять (по умолчанию ~/.config/git/hooks)
#   --no-config      не трогать core.hooksPath
#   -h, --help       эта справка
set -eu

MARKER='git-secret-hooks'
say() { printf '%s\n' "$*"; }
die() { printf 'ОШИБКА: %s\n' "$*" >&2; exit 1; }

hooks_dir=''
set_config=1

while [ $# -gt 0 ]; do
  case "$1" in
    --hooks-dir)   [ $# -ge 2 ] || die "--hooks-dir требует путь"; hooks_dir=$2; shift 2 ;;
    --hooks-dir=*) hooks_dir=${1#*=}; shift ;;
    --no-config)   set_config=0; shift ;;
    -h|--help)     sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)             die "неизвестный аргумент: $1 (см. --help)" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git не найден в PATH"
[ -n "${HOME:-}" ] || die "переменная HOME не задана"

[ -n "$hooks_dir" ] || hooks_dir="$HOME/.config/git/hooks"
if [ -d "$hooks_dir" ]; then                       # if, а не && : при set -e ложное && завершит скрипт
  hooks_dir=$(CDPATH= cd -- "$hooks_dir" && pwd)
fi
dest="$hooks_dir/pre-commit"

# ---------- сам файл хука ----------
if [ -e "$dest" ]; then
  if grep -q -- "$MARKER" "$dest" 2>/dev/null; then
    rm -f -- "$dest"
    say "✔ удалён $dest"
  else
    say "! $dest — не наш хук (нет метки $MARKER), оставлен как есть"
  fi
else
  say "— $dest не найден"
fi

# ---------- core.hooksPath ----------
if [ "$set_config" -eq 1 ]; then
  current=$(git config --global --get core.hooksPath 2>/dev/null || true)
  current_abs=''
  case "$current" in
    '')    ;;
    '~/'*) current_abs="$HOME/${current#\~/}" ;;
    *)     current_abs=$current ;;
  esac
  prev=$(git config --global --get gitsecrethooks.previousHooksPath 2>/dev/null || true)

  if [ -z "$current_abs" ]; then
    say "— core.hooksPath не задан, менять нечего"
  elif [ "$current_abs" != "$hooks_dir" ]; then
    say "! core.hooksPath указывает на $current (не на наш каталог), оставлен как есть"
  elif [ -n "$prev" ]; then
    git config --global core.hooksPath "$prev"
    git config --global --unset gitsecrethooks.previousHooksPath
    say "✔ core.hooksPath восстановлен: $prev"
  else
    git config --global --unset core.hooksPath
    say "✔ core.hooksPath сброшен (снова работают .git/hooks репозиториев)"
  fi
else
  say "— core.hooksPath не менялся (--no-config)"
fi

# ---------- напоминание про резервные копии ----------
backups=$(ls -1 "$hooks_dir"/pre-commit.bak.* 2>/dev/null || true)
if [ -n "$backups" ]; then
  say ''
  say 'Остались резервные копии прежних хуков (удалите вручную при необходимости):'
  printf '%s\n' "$backups" | sed 's/^/    /'
fi

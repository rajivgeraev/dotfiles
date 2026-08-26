#!/bin/bash
# Односторонняя ручная синхронизация ~/... <-> htzr:sync_mac/... через rclone.
#
# Использование:
#   ./sync-mac.sh push [--dry-run]   # локально -> Hetzner (обычный режим, реальное удаление на remote)
#   ./sync-mac.sh pull [--dry-run]   # Hetzner -> локально (разово, при восстановлении на новой системе)
#
# rclone sync делает назначение точной копией источника, включая удаление лишнего — это осознанный выбор,
# не copy. Перед первым запуском в новом направлении настоятельно рекомендуется --dry-run.
#
# Чтобы исключить папку из синхронизации целиком (на любом уровне вложенности, в любой из задач) — положи
# внутрь неё пустой файл-маркер с именем .nosync. Ничего никуда переносить не нужно, папка остаётся на месте.
set -euo pipefail

NOSYNC_MARKER=".nosync"

# локальная_папка|remote_путь
JOBS=(
  "$HOME/sync|htzr:sync_mac/sync"
  "$HOME/dev|htzr:sync_mac/dev"
#  "$HOME/Desktop|htzr:sync_mac/Desktop"
#  "$HOME/Downloads|htzr:sync_mac/Downloads"
#  "$HOME/.claude|htzr:sync_mac/claude"
)

usage() {
  echo "Usage: $0 <push|pull> [--dry-run]"
  exit 1
}

[ $# -ge 1 ] || usage
DIRECTION="$1"
shift
EXTRA_FLAGS=("$@")

case "$DIRECTION" in
  push|pull) ;;
  *) usage ;;
esac

COMMON_FLAGS=(--progress --transfers=8 --copy-links --exclude-if-present "${NOSYNC_MARKER}")
if [ "${#EXTRA_FLAGS[@]}" -gt 0 ]; then
  COMMON_FLAGS+=("${EXTRA_FLAGS[@]}")
fi

for job in "${JOBS[@]}"; do
  IFS='|' read -r LOCAL REMOTE <<< "$job"

  if [ "$DIRECTION" = push ]; then
    SRC="$LOCAL"; DST="$REMOTE"
  else
    SRC="$REMOTE"; DST="$LOCAL"
  fi

  echo "=== ${DIRECTION}: ${SRC} -> ${DST} ==="
  rclone sync "$SRC" "$DST" "${COMMON_FLAGS[@]}"
done

echo "=== Готово (${DIRECTION}) ==="

#!/usr/bin/env bash
# Calcula la siguiente versión a partir de los tags vX.Y.Z del repositorio.
#   uso: ci/siguiente-version.sh [PATCH|MINOR|MAJOR]   (por defecto PATCH)
# Imprime solo X.Y.Z. Si HEAD ya tiene un tag vX.Y.Z imprime esa versión y sale con 3
# (el commit ya fue publicado). Sin tags previos la primera versión es 1.0.0.
set -euo pipefail

INCREMENTO=${1:-PATCH}
case "$INCREMENTO" in
  PATCH|MINOR|MAJOR) ;;
  *) echo "Incremento no válido: $INCREMENTO (usa PATCH, MINOR o MAJOR)" >&2; exit 1 ;;
esac

PATRON='^v[0-9]+\.[0-9]+\.[0-9]+$'

ACTUAL=$(git tag --points-at HEAD | grep -E "$PATRON" | sort -V | tail -n1 || true)
if [ -n "$ACTUAL" ]; then
  echo "${ACTUAL#v}"
  exit 3
fi

ULTIMO=$(git tag --list 'v*' | grep -E "$PATRON" | sort -V | tail -n1 || true)
if [ -z "$ULTIMO" ]; then
  echo "1.0.0"
  exit 0
fi

IFS=. read -r MAYOR MENOR PARCHE <<< "${ULTIMO#v}"
case "$INCREMENTO" in
  MAJOR) echo "$((MAYOR + 1)).0.0" ;;
  MINOR) echo "${MAYOR}.$((MENOR + 1)).0" ;;
  PATCH) echo "${MAYOR}.${MENOR}.$((PARCHE + 1))" ;;
esac

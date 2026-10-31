#!/usr/bin/env bash
# Pruebas de ci/siguiente-version.sh sobre repos git temporales.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/siguiente-version.sh"
FALLOS=0

nuevo_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email test@lab.local
  git -C "$dir" config user.name test
  git -C "$dir" commit -q --allow-empty -m inicial
  echo "$dir"
}
commit() { git -C "$1" commit -q --allow-empty -m "cambio $RANDOM"; }

comprobar() { # comprobar NOMBRE DIR ESPERADO RC_ESPERADO [INCREMENTO]
  local salida rc
  salida=$(cd "$2" && bash "$SCRIPT" ${5:-})
  rc=$?
  if [ "$salida" = "$3" ] && [ "$rc" = "$4" ]; then
    echo "OK   $1"
  else
    echo "FAIL $1: esperado '$3' rc=$4, obtenido '$salida' rc=$rc"
    FALLOS=$((FALLOS + 1))
  fi
}

R=$(nuevo_repo)
comprobar "sin tags -> 1.0.0" "$R" 1.0.0 0

R=$(nuevo_repo); git -C "$R" tag v1.0.0; commit "$R"
comprobar "patch por defecto" "$R" 1.0.1 0
comprobar "PATCH explícito" "$R" 1.0.1 0 PATCH
comprobar "MINOR" "$R" 1.1.0 0 MINOR
comprobar "MAJOR" "$R" 2.0.0 0 MAJOR

R=$(nuevo_repo); git -C "$R" tag v1.0.9; commit "$R"; git -C "$R" tag v1.0.10; commit "$R"
comprobar "orden semver, no alfabético" "$R" 1.0.11 0

R=$(nuevo_repo); git -C "$R" tag v1.0.0; commit "$R"; git -C "$R" tag vbasura; git -C "$R" tag v2.0; commit "$R"
comprobar "ignora tags que no son vX.Y.Z" "$R" 1.0.1 0

R=$(nuevo_repo); git -C "$R" tag v1.0.0; commit "$R"; git -C "$R" tag v1.2.3
comprobar "HEAD ya etiquetado -> rc 3" "$R" 1.2.3 3

R=$(nuevo_repo)
comprobar "incremento inválido -> rc 1" "$R" "" 1 MEGA

if [ "$FALLOS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALLOS fallos"; exit 1; fi

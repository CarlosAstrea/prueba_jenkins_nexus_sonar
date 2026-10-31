#!/usr/bin/env bash
# Cliente mínimo de la REST API de Bitbucket Cloud para los PRs de feature/* hacia develop.
#   ci/bitbucket.sh buscar-pr <rama>  -> id del PR abierto, o nada
#   ci/bitbucket.sh crear-pr  <rama>  -> "<id> <url>" (reutiliza el abierto si existe)
#   ci/bitbucket.sh merge-pr  <rama>  -> fusiona el PR abierto (merge_commit)
# Variables: BB_API_USER, BB_TOKEN, BITBUCKET_WORKSPACE, BITBUCKET_REPO, BB_API (opcional).
# Códigos de salida: 0 ok, 1 error de uso o de la API, 2 no hay PR abierto (merge-pr).
set -euo pipefail

DESTINO=develop
API=${BB_API:-https://api.bitbucket.org/2.0}
: "${BB_API_USER:?falta BB_API_USER}" "${BB_TOKEN:?falta BB_TOKEN}"
: "${BITBUCKET_WORKSPACE:?falta BITBUCKET_WORKSPACE}" "${BITBUCKET_REPO:?falta BITBUCKET_REPO}"
BASE="$API/repositories/$BITBUCKET_WORKSPACE/$BITBUCKET_REPO/pullrequests"
CUERPO=$(mktemp)
trap 'rm -f "$CUERPO"' EXIT

# llamar METODO URL [JSON] [args curl...] -> deja la respuesta en $CUERPO; falla si no es 2xx
llamar() {
  local metodo=$1 url=$2 datos=${3:-} codigo
  shift 3 || shift $#
  local extra=("$@")
  if [ -n "$datos" ]; then extra+=(-H 'Content-Type: application/json' --data "$datos"); fi
  codigo=$(curl -sS -o "$CUERPO" -w '%{http_code}' -u "$BB_API_USER:$BB_TOKEN" -X "$metodo" "${extra[@]}" "$url")
  case "$codigo" in
    2*) return 0 ;;
    *) echo "Bitbucket respondió HTTP $codigo a $metodo $url:" >&2; cat "$CUERPO" >&2; echo >&2; return 1 ;;
  esac
}

# imprime "<id> <url>" del PR abierto de la rama hacia develop, o nada
pr_abierto() {
  local rama=$1
  llamar GET "$BASE" "" -G \
    --data-urlencode "q=source.branch.name=\"$rama\" AND destination.branch.name=\"$DESTINO\" AND state=\"OPEN\"" \
    --data-urlencode "fields=values.id,values.links.html.href"
  jq -r '.values[0] // empty | "\(.id) \(.links.html.href)"' "$CUERPO"
}

[ $# -eq 2 ] || { echo "uso: $0 buscar-pr|crear-pr|merge-pr <rama>" >&2; exit 1; }
COMANDO=$1
RAMA=$2

case "$COMANDO" in
  buscar-pr)
    pr_abierto "$RAMA" | cut -d' ' -f1
    ;;
  crear-pr)
    EXISTENTE=$(pr_abierto "$RAMA")
    if [ -n "$EXISTENTE" ]; then
      echo "$EXISTENTE"
      exit 0
    fi
    DATOS=$(jq -cn --arg rama "$RAMA" --arg destino "$DESTINO" \
      '{title: $rama, source: {branch: {name: $rama}}, destination: {branch: {name: $destino}}, close_source_branch: true}')
    llamar POST "$BASE" "$DATOS"
    jq -r '"\(.id) \(.links.html.href)"' "$CUERPO"
    ;;
  merge-pr)
    EXISTENTE=$(pr_abierto "$RAMA")
    if [ -z "$EXISTENTE" ]; then
      echo "No hay PR abierto de $RAMA hacia $DESTINO" >&2
      exit 2
    fi
    ID=${EXISTENTE%% *}
    llamar POST "$BASE/$ID/merge" '{"type":"pullrequest","merge_strategy":"merge_commit","close_source_branch":true}'
    echo "PR #$ID fusionado en $DESTINO (${EXISTENTE#* })"
    ;;
  *)
    echo "Comando desconocido: $COMANDO" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
# Pruebas de ci/bitbucket.sh contra un servidor HTTP falso (python3).
# Se ejecuta donde corren los pipelines (contenedor de Jenkins): necesita bash, curl, jq y python3.
set -uo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/bitbucket.sh"
TMP=$(mktemp -d)
PUERTO=18765
FALLOS=0

cat > "$TMP/mock.py" <<'PY'
import json, sys, urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer

estado_path, log_path, puerto = sys.argv[1], sys.argv[2], int(sys.argv[3])

class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _estado(self):
        with open(estado_path) as f: return json.load(f)
    def _resp(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def _log(self):
        with open(log_path, "a") as f: f.write(self.command + " " + self.path + "\n")
    def do_GET(self):
        self._log()
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query).get("q", [""])[0]
        prs = [p for p in self._estado()["abiertos"] if '"%s"' % p["rama"] in q]
        self._resp(200, {"values": [{"id": p["id"], "links": {"html": {"href": "https://bb.test/pr/%d" % p["id"]}}} for p in prs]})
    def do_POST(self):
        self._log()
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode() if n else ""
        with open(log_path, "a") as f: f.write("BODY " + body + "\n")
        if self.path.endswith("/merge"):
            st = self._estado().get("merge", 200)
            if st == 200:
                self._resp(200, {"id": 7, "state": "MERGED"})
            else:
                self._resp(st, {"type": "error", "error": {"message": "Conflictos en el merge"}})
        else:
            self._resp(201, {"id": 99, "links": {"html": {"href": "https://bb.test/pr/99"}}})

HTTPServer(("127.0.0.1", puerto), H).serve_forever()
PY

estado() { echo "$1" > "$TMP/estado.json"; : > "$TMP/log"; }
estado '{"abiertos":[]}'
python3 "$TMP/mock.py" "$TMP/estado.json" "$TMP/log" "$PUERTO" &
MOCK=$!
trap 'kill $MOCK 2>/dev/null; rm -rf "$TMP"' EXIT
for _ in $(seq 1 50); do curl -s "http://127.0.0.1:$PUERTO/" >/dev/null && break; sleep 0.1; done

export BB_API="http://127.0.0.1:$PUERTO" BB_API_USER=u BB_TOKEN=t BITBUCKET_WORKSPACE=ws BITBUCKET_REPO=repo

ok()   { echo "OK   $1"; }
fail() { echo "FAIL $1"; FALLOS=$((FALLOS + 1)); }

# 1. buscar-pr con rama que tiene "/" -> consulta URL-encoded y devuelve el id
estado '{"abiertos":[{"id":7,"rama":"feature/a-b"}]}'
SAL=$(bash "$SCRIPT" buscar-pr feature/a-b); RC=$?
if [ "$SAL" = "7" ] && [ $RC -eq 0 ] && grep -qi 'feature%2Fa-b' "$TMP/log"; then ok "buscar-pr codifica la rama y devuelve el id"; else fail "buscar-pr: '$SAL' rc=$RC log=$(cat "$TMP/log")"; fi

# 2. buscar-pr sin PR -> salida vacía, rc 0
estado '{"abiertos":[]}'
SAL=$(bash "$SCRIPT" buscar-pr feature/x); RC=$?
if [ -z "$SAL" ] && [ $RC -eq 0 ]; then ok "buscar-pr sin PR -> vacío"; else fail "buscar-pr vacío: '$SAL' rc=$RC"; fi

# 3. crear-pr cuando ya existe -> no hace POST
estado '{"abiertos":[{"id":7,"rama":"feature/a-b"}]}'
SAL=$(bash "$SCRIPT" crear-pr feature/a-b); RC=$?
if [ "$SAL" = "7 https://bb.test/pr/7" ] && [ $RC -eq 0 ] && ! grep -q '^POST' "$TMP/log"; then ok "crear-pr reutiliza el PR abierto"; else fail "crear-pr existente: '$SAL' rc=$RC log=$(cat "$TMP/log")"; fi

# 4. crear-pr sin PR -> POST hacia develop con close_source_branch
estado '{"abiertos":[]}'
SAL=$(bash "$SCRIPT" crear-pr feature/nueva); RC=$?
if [ "$SAL" = "99 https://bb.test/pr/99" ] && [ $RC -eq 0 ] \
   && grep -q '"destination":{"branch":{"name":"develop"}}' "$TMP/log" \
   && grep -q '"close_source_branch":true' "$TMP/log"; then ok "crear-pr crea el PR hacia develop"; else fail "crear-pr nuevo: '$SAL' rc=$RC log=$(cat "$TMP/log")"; fi

# 5. merge-pr sin PR abierto -> rc 2 y mensaje claro
estado '{"abiertos":[]}'
ERR=$(bash "$SCRIPT" merge-pr feature/x 2>&1 >/dev/null); RC=$?
if [ $RC -eq 2 ] && echo "$ERR" | grep -q 'No hay PR abierto de feature/x hacia develop'; then ok "merge-pr sin PR -> rc 2"; else fail "merge-pr sin PR: rc=$RC err='$ERR'"; fi

# 6. merge-pr OK -> merge_commit
estado '{"abiertos":[{"id":7,"rama":"feature/a-b"}],"merge":200}'
bash "$SCRIPT" merge-pr feature/a-b >/dev/null 2>&1; RC=$?
if [ $RC -eq 0 ] && grep -q 'POST /repositories/ws/repo/pullrequests/7/merge' "$TMP/log" && grep -q '"merge_strategy":"merge_commit"' "$TMP/log"; then ok "merge-pr fusiona con merge_commit"; else fail "merge-pr ok: rc=$RC log=$(cat "$TMP/log")"; fi

# 7. merge-pr con 409 -> rc 1 y el cuerpo del error visible
estado '{"abiertos":[{"id":7,"rama":"feature/a-b"}],"merge":409}'
ERR=$(bash "$SCRIPT" merge-pr feature/a-b 2>&1); RC=$?
if [ $RC -eq 1 ] && echo "$ERR" | grep -q 'Conflictos en el merge'; then ok "merge-pr con 409 -> rc 1 y error visible"; else fail "merge-pr 409: rc=$RC err='$ERR'"; fi

# 8. comando desconocido -> rc 1
bash "$SCRIPT" borrar-todo x >/dev/null 2>&1; RC=$?
if [ $RC -eq 1 ]; then ok "comando desconocido -> rc 1"; else fail "comando desconocido rc=$RC"; fi

if [ "$FALLOS" -eq 0 ]; then echo "TODOS OK"; exit 0; else echo "$FALLOS fallos"; exit 1; fi

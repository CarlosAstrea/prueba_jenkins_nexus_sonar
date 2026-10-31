#!/usr/bin/env bash
# Ejecuta un comando git usando GIT_USER/GIT_PASS (inyectados por withCredentials)
# sin escribirlos en la URL ni en el log.   uso: ci/git-con-credenciales.sh <args de git...>
set -euo pipefail
: "${GIT_USER:?falta GIT_USER}" "${GIT_PASS:?falta GIT_PASS}"

ASKPASS=$(mktemp)
trap 'rm -f "$ASKPASS"' EXIT
cat > "$ASKPASS" <<'EOF'
#!/bin/sh
case "$1" in
  Username*) echo "$GIT_USER" ;;
  *) echo "$GIT_PASS" ;;
esac
EOF
chmod 700 "$ASKPASS"

GIT_ASKPASS="$ASKPASS" GIT_TERMINAL_PROMPT=0 git -c credential.helper= "$@"

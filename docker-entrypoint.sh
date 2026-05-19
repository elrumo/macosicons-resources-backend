#!/usr/bin/env sh
# Probes the database host before handing off to Strapi so that
# connectivity problems surface with useful diagnostics instead of
# a bare `connect ETIMEDOUT` from mysql2.

DB_HOST="${DATABASE_HOST:-strapiDB}"
DB_PORT="${DATABASE_PORT:-3306}"
MAX_ATTEMPTS=30
SLEEP_SECS=2

log() {
  printf '[wait-for-db] %s\n' "$1"
}

log "target=${DB_HOST}:${DB_PORT} (DATABASE_CLIENT=${DATABASE_CLIENT:-<unset>})"

i=1
while [ "$i" -le "$MAX_ATTEMPTS" ]; do
  resolved=$(getent hosts "$DB_HOST" 2>/dev/null | awk '{print $1}' | head -n1)

  if [ -n "$resolved" ]; then
    if nc -z -w 3 "$DB_HOST" "$DB_PORT" 2>/dev/null; then
      log "ok: ${DB_HOST} -> ${resolved}:${DB_PORT} (attempt ${i})"
      exec "$@"
    fi
    log "attempt ${i}/${MAX_ATTEMPTS}: dns=${resolved} tcp=failed"
  else
    log "attempt ${i}/${MAX_ATTEMPTS}: dns=<unresolved> tcp=skipped"
  fi

  i=$((i + 1))
  sleep "$SLEEP_SECS"
done

log "FAILED after ${MAX_ATTEMPTS} attempts. Diagnostics:"
log "  hostname: $(hostname 2>/dev/null)"
log "  own ip:   $(hostname -i 2>/dev/null)"
log "  resolv.conf:"
sed 's/^/    /' /etc/resolv.conf 2>/dev/null || log "    <unreadable>"
log "Starting Strapi anyway so mysql2 emits its native error..."
exec "$@"

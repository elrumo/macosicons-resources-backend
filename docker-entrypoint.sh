#!/usr/bin/env sh
# Probes the database host before handing off to Strapi so that
# connectivity problems surface with useful diagnostics instead of
# a bare `connect ETIMEDOUT` from mysql2.

DB_HOST="${DATABASE_HOST:-strapiDB}"
DB_PORT="${DATABASE_PORT:-3306}"
MAX_ATTEMPTS=15
SLEEP_SECS=2

log() {
  printf '[wait-for-db] %s\n' "$1"
}

log "================================================================"
log "target=${DB_HOST}:${DB_PORT} (DATABASE_CLIENT=${DATABASE_CLIENT:-<unset>})"
log "container hostname=$(hostname 2>/dev/null)"
log "/etc/hosts:"
sed 's/^/    /' /etc/hosts 2>/dev/null || log "    <unreadable>"
log "/etc/resolv.conf:"
sed 's/^/    /' /etc/resolv.conf 2>/dev/null || log "    <unreadable>"
log "Initial name resolution:"
log "  getent ahostsv4 ${DB_HOST}:"
getent ahostsv4 "$DB_HOST" 2>&1 | head -5 | sed 's/^/    /' || log "    <none>"
log "  getent ahostsv6 ${DB_HOST}:"
getent ahostsv6 "$DB_HOST" 2>&1 | head -5 | sed 's/^/    /' || log "    <none>"
log "================================================================"

# Warn loudly if the target resolves to loopback - that's never a working
# DB inside a container, and the most common cause is DATABASE_HOST=localhost
# in .env or the strapi container's own hostname colliding with the DB name.
v4_first=$(getent ahostsv4 "$DB_HOST" 2>/dev/null | awk '{print $1}' | head -n1)
case "${v4_first}" in
  127.*|::1)
    log "WARNING: ${DB_HOST} resolves to loopback (${v4_first}). The DB is"
    log "         not reachable from inside this container at that address."
    log "         Check that DATABASE_HOST in .env points at the DB service"
    log "         name (e.g. strapiDB) and that this container is on the"
    log "         same docker network as the DB container."
    ;;
esac

i=1
while [ "$i" -le "$MAX_ATTEMPTS" ]; do
  v4_ip=$(getent ahostsv4 "$DB_HOST" 2>/dev/null | awk '{print $1}' | head -n1)

  if [ -n "$v4_ip" ]; then
    case "${v4_ip}" in
      127.*) ;;  # don't bother probing loopback
      *)
        if nc -z -w 3 "$v4_ip" "$DB_PORT" 2>/dev/null; then
          log "ok: ${DB_HOST} -> ${v4_ip}:${DB_PORT} (attempt ${i})"
          exec "$@"
        fi
        ;;
    esac
  fi

  log "attempt ${i}/${MAX_ATTEMPTS}: v4=${v4_ip:-<unresolved>} tcp=failed"
  i=$((i + 1))
  sleep "$SLEEP_SECS"
done

log "FAILED after ${MAX_ATTEMPTS} attempts. Starting Strapi anyway so"
log "mysql2 emits its native error."
exec "$@"

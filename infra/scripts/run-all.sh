#!/usr/bin/env bash
# infra/scripts/run-all.sh
#
# Brings up the whole EventHub stack on a clean machine using plain podman
# commands: network -> datastores -> app services -> gateway -> frontend ->
# one-shot analytics job. No Compose.
#
# ASSUMPTIONS you should double-check against your actual repo before
# relying on this (marked inline too):
#   - The gateway service lives at services/gateway-node (or wherever you
#     actually put it) and listens on GATEWAY_PORT internally.
#   - Each service other than the catalog exposes its own /health endpoint
#     and defines its own HEALTHCHECK in its Containerfile. The catalog
#     doesn't (see its README/Containerfile), so it gets a TCP readiness
#     check here instead of a podman Health.Status check.
#   - Service env var names (PGHOST, MONGODB_URI, etc.) match whatever
#     each service's own README says - adjust the *_ENV blocks below to
#     match reality rather than trust these names blindly.
#
# Rerunning this script is safe: it skips creating anything that already
# exists rather than failing on it.

set -euo pipefail


ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NETWORK="eventhub-net"

# Datastores
MYSQL_NAME="eventhub-mysql";      MYSQL_IMAGE="docker.io/library/mysql:8.4";              MYSQL_PORT=3306
POSTGRES_NAME="eventhub-postgres"; POSTGRES_IMAGE="docker.io/library/postgres:16";        POSTGRES_PORT=5432
MONGO_NAME="eventhub-mongo";      MONGO_IMAGE="docker.io/library/mongo:7";                MONGO_PORT=27017
REDIS_NAME="eventhub-redis";      REDIS_IMAGE="docker.io/library/redis:7";                REDIS_PORT=6379
RABBIT_NAME="eventhub-rabbitmq";  RABBIT_IMAGE="docker.io/library/rabbitmq:3-management"; RABBIT_PORT=5672


MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-catalog_root_pw}"
MYSQL_DATABASE="${MYSQL_DATABASE:-catalog}"
MYSQL_USER="${MYSQL_USER:-catalog_user}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-catalog_pw}"

POSTGRES_DB="${POSTGRES_DB:-auth}"
POSTGRES_USER="${POSTGRES_USER:-auth_user}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-auth_pw}"

MONGO_DB="${MONGO_DB:-booking}"

# App services
CATALOG_NAME="eventhub-catalog";     CATALOG_PORT=8081
AUTH_NAME="eventhub-auth";           AUTH_PORT=8082
BOOKING_NAME="eventhub-booking";     BOOKING_PORT=8083
NOTIFY_NAME="eventhub-notification-worker"
AI_INSIGHT_NAME="eventhub-ai-insight"; AI_INSIGHT_PORT=8084
ANALYTICS_NAME="eventhub-analytics"; ANALYTICS_PORT=8085
GATEWAY_NAME="eventhub-gateway";     GATEWAY_PORT="${GATEWAY_PORT:-8080}"
FRONTEND_NAME="eventhub-frontend";   FRONTEND_PORT=3000

# Helpers
log() { echo "[run-all] $*"; }

container_exists() { podman ps -a --format '{{.Names}}' | grep -qx "$1"; }
volume_exists()    { podman volume ls --format '{{.Name}}' | grep -qx "$1"; }

# Waits on a container's own HEALTHCHECK (defined in its Containerfile or
# passed via --health-cmd on `podman run`).
wait_for_healthy() {
  local name="$1" timeout="${2:-90}" waited=0
  log "waiting for ${name} to report healthy..."
  while true; do
    status="$(podman inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "starting")"
    [ "$status" = "healthy" ] && { log "${name} is healthy"; return 0; }
    if [ "$status" = "unhealthy" ]; then
      log "ERROR: ${name} reported unhealthy. Last health log:"
      podman inspect -f '{{json .State.Health.Log}}' "$name" 2>/dev/null || true
      podman logs --tail 50 "$name" || true
      exit 1
    fi
    sleep 2; waited=$((waited + 2))
    if [ "$waited" -ge "$timeout" ]; then
      log "ERROR: ${name} did not become healthy within ${timeout}s"
      podman logs --tail 50 "$name" || true
      exit 1
    fi
  done
}

# TCP readiness check via a throwaway helper container on the same network,
# for anything without its own HTTP health endpoint (the catalog service).
wait_for_tcp() {
  local host="$1" port="$2" timeout="${3:-90}"
  log "waiting for ${host}:${port} to accept connections..."
  if ! podman run --rm --network "$NETWORK" busybox:stable sh -c \
      "i=0; until nc -z -w2 '$host' '$port'; do i=\$((i+2)); [ \$i -ge $timeout ] && exit 1; sleep 2; done"; then
    log "ERROR: ${host}:${port} not reachable within ${timeout}s"
    exit 1
  fi
  log "${host}:${port} is reachable"
}

# 1. Network

if podman network exists "$NETWORK" 2>/dev/null; then
  log "network ${NETWORK} already exists"
else
  log "creating network ${NETWORK}"
  podman network create "$NETWORK"
fi

# 2. Datastores
if container_exists "$MYSQL_NAME"; then
  log "${MYSQL_NAME} already exists, starting it"
  podman start "$MYSQL_NAME" >/dev/null
else
  log "starting ${MYSQL_NAME}"
  podman run -d --name "$MYSQL_NAME" --network "$NETWORK" \
    -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" \
    -e MYSQL_DATABASE="$MYSQL_DATABASE" \
    -e MYSQL_USER="$MYSQL_USER" \
    -e MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    -v eventhub-mysql-data:/var/lib/mysql \
    --health-cmd "mysqladmin ping -h 127.0.0.1 -u root -p\$MYSQL_ROOT_PASSWORD --silent" \
    --health-interval 10s --health-timeout 5s --health-retries 5 --health-start-period 20s \
    "$MYSQL_IMAGE"
fi

if container_exists "$POSTGRES_NAME"; then
  log "${POSTGRES_NAME} already exists, starting it"
  podman start "$POSTGRES_NAME" >/dev/null
else
  log "starting ${POSTGRES_NAME}"
  podman run -d --name "$POSTGRES_NAME" --network "$NETWORK" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -v eventhub-postgres-data:/var/lib/postgresql/data \
    --health-cmd "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB" \
    --health-interval 10s --health-timeout 5s --health-retries 5 --health-start-period 15s \
    "$POSTGRES_IMAGE"
fi

if container_exists "$MONGO_NAME"; then
  log "${MONGO_NAME} already exists, starting it"
  podman start "$MONGO_NAME" >/dev/null
else
  log "starting ${MONGO_NAME}"
  podman run -d --name "$MONGO_NAME" --network "$NETWORK" \
    -e MONGO_INITDB_DATABASE="$MONGO_DB" \
    -v eventhub-mongo-data:/data/db \
    --health-cmd "mongosh --quiet --eval 'db.adminCommand(\"ping\")'" \
    --health-interval 10s --health-timeout 5s --health-retries 5 --health-start-period 15s \
    "$MONGO_IMAGE"
fi

if container_exists "$REDIS_NAME"; then
  log "${REDIS_NAME} already exists, starting it"
  podman start "$REDIS_NAME" >/dev/null
else
  log "starting ${REDIS_NAME}"
  podman run -d --name "$REDIS_NAME" --network "$NETWORK" \
    -v eventhub-redis-data:/data \
    --health-cmd "redis-cli ping" \
    --health-interval 10s --health-timeout 5s --health-retries 5 --health-start-period 10s \
    "$REDIS_IMAGE"
fi

if container_exists "$RABBIT_NAME"; then
  log "${RABBIT_NAME} already exists, starting it"
  podman start "$RABBIT_NAME" >/dev/null
else
  if ! volume_exists "eventhub-rabbitmq-data"; then
    podman volume create eventhub-rabbitmq-data >/dev/null
  fi
  log "pre-chowning eventhub-rabbitmq-data to uid/gid 999"
  podman unshare chown -R 999:999 \
    "$(podman volume inspect eventhub-rabbitmq-data --format '{{.Mountpoint}}')"
  
  log "starting ${RABBIT_NAME}"
  podman run -d --name "$RABBIT_NAME" --network "$NETWORK" \
    -v eventhub-rabbitmq-data:/var/lib/rabbitmq \
    --health-cmd "rabbitmq-diagnostics -q ping" \
    --health-interval 10s --health-timeout 5s --health-retries 5 --health-start-period 20s \
    "$RABBIT_IMAGE"
fi

wait_for_healthy "$MYSQL_NAME"
wait_for_healthy "$POSTGRES_NAME"
wait_for_healthy "$MONGO_NAME"
wait_for_healthy "$REDIS_NAME"
wait_for_healthy "$RABBIT_NAME"

# ---------------------------------------------------------------------------
# 3. Build app images
# ---------------------------------------------------------------------------
log "building images"
podman build --format docker -t eventhub/catalog:latest      "$ROOT_DIR/services/legacy-catalog-java"
podman build --format docker -t eventhub/auth:latest         "$ROOT_DIR/services/auth-service-node"
podman build --format docker -t eventhub/booking:latest      "$ROOT_DIR/services/booking-service-python"
podman build --format docker -t eventhub/notify:latest       "$ROOT_DIR/services/notification-worker-go"
podman build --format docker -t eventhub/ai-insight:latest   "$ROOT_DIR/services/ai-insight-service-python"
podman build --format docker -t eventhub/analytics:latest    "$ROOT_DIR/services/analytics-service-python"
podman build --format docker -t eventhub/api-gateway:latest      "$ROOT_DIR/api-gateway"
podman build --format docker -t eventhub/frontend:latest     "$ROOT_DIR/frontend" \
  --build-arg REACT_APP_API_BASE_URL="http://localhost:${GATEWAY_PORT}"

# ---------------------------------------------------------------------------
# 4. App services (container-to-container traffic uses container names;
#    only the gateway and frontend get published host ports)
# ---------------------------------------------------------------------------
if container_exists "$CATALOG_NAME"; then
  podman start "$CATALOG_NAME" >/dev/null
else
  log "starting ${CATALOG_NAME}"
  podman run -d --name "$CATALOG_NAME" --network "$NETWORK" \
    -e SERVER_PORT="$CATALOG_PORT" \
    -e SPRING_DATASOURCE_URL="jdbc:mysql://${MYSQL_NAME}:${MYSQL_PORT}/${MYSQL_DATABASE}" \
    -e SPRING_DATASOURCE_USERNAME="$MYSQL_USER" \
    -e SPRING_DATASOURCE_PASSWORD="$MYSQL_PASSWORD" \
    eventhub/catalog:latest
fi
# No real /health endpoint on this one (see its README) - TCP check instead
# of relying on podman's Health.Status.
wait_for_tcp "$CATALOG_NAME" "$CATALOG_PORT"

if container_exists "$AUTH_NAME"; then
  podman start "$AUTH_NAME" >/dev/null
else
  log "starting ${AUTH_NAME}"
  podman run -d --name "$AUTH_NAME" --network "$NETWORK" \
    -e PORT="$AUTH_PORT" \
    -e PGHOST="$POSTGRES_NAME" -e PGPORT="$POSTGRES_PORT" \
    -e PGDATABASE="$POSTGRES_DB" -e PGUSER="$POSTGRES_USER" -e PGPASSWORD="$POSTGRES_PASSWORD" \
    eventhub/auth:latest
fi
wait_for_healthy "$AUTH_NAME"

if container_exists "$BOOKING_NAME"; then
  podman start "$BOOKING_NAME" >/dev/null
else
  log "starting ${BOOKING_NAME}"
  podman run -d --name "$BOOKING_NAME" --network "$NETWORK" \
    -e PORT="$BOOKING_PORT" \
    -e MONGO_URI="mongodb://${MONGO_NAME}:${MONGO_PORT}/${MONGO_DB}" \
    -e RABBITMQ_HOST="$RABBIT_NAME" -e RABBITMQ_PORT="$RABBIT_PORT" \
    -e AUTH_SERVICE_URL="http://${AUTH_NAME}:${AUTH_PORT}" \
    eventhub/booking:latest
fi
wait_for_healthy "$BOOKING_NAME"

if container_exists "$NOTIFY_NAME"; then
  podman start "$NOTIFY_NAME" >/dev/null
else
  log "starting ${NOTIFY_NAME}"
  podman run -d --name "$NOTIFY_NAME" --network "$NETWORK" \
    -e RABBITMQ_URL="amqp://guest:guest@${RABBIT_NAME}:${RABBIT_PORT}/" \
    -e RABBITMQ_QUEUE="bookings" \
    eventhub/notify:latest
fi
# Worker has no published port - if its Containerfile defines a HEALTHCHECK
# (e.g. a small internal probe), this still works via podman's Health.Status.
wait_for_healthy "$NOTIFY_NAME"

if container_exists "$AI_INSIGHT_NAME"; then
  podman start "$AI_INSIGHT_NAME" >/dev/null
else
  log "starting ${AI_INSIGHT_NAME}"
  podman run -d --name "$AI_INSIGHT_NAME" --network "$NETWORK" \
    -e PORT="$AI_INSIGHT_PORT" \
    eventhub/ai-insight:latest
fi
wait_for_healthy "$AI_INSIGHT_NAME"

if container_exists "$ANALYTICS_NAME"; then
  podman start "$ANALYTICS_NAME" >/dev/null
else
  log "starting ${ANALYTICS_NAME}"
  podman run -d --name "$ANALYTICS_NAME" --network "$NETWORK" \
    -e PORT="$ANALYTICS_PORT" \
    -e REDIS_HOST="$REDIS_NAME" -e REDIS_PORT="$REDIS_PORT" \
    eventhub/analytics:latest
fi
wait_for_healthy "$ANALYTICS_NAME"

# ---------------------------------------------------------------------------
# 5. Gateway (only starts once every backend it fronts is ready) and frontend
# ---------------------------------------------------------------------------
if container_exists "$GATEWAY_NAME"; then
  podman start "$GATEWAY_NAME" >/dev/null
else
  log "starting ${GATEWAY_NAME}"
  podman run -d --name "$GATEWAY_NAME" --network "$NETWORK" \
    -p "${GATEWAY_PORT}:${GATEWAY_PORT}" \
    -e PORT="$GATEWAY_PORT" \
    -e CATALOG_URL="http://${CATALOG_NAME}:${CATALOG_PORT}" \
    -e AUTH_URL="http://${AUTH_NAME}:${AUTH_PORT}" \
    -e BOOKING_URL="http://${BOOKING_NAME}:${BOOKING_PORT}" \
    -e AI_INSIGHT_URL="http://${AI_INSIGHT_NAME}:${AI_INSIGHT_PORT}" \
    -e ANALYTICS_URL="http://${ANALYTICS_NAME}:${ANALYTICS_PORT}" \
    eventhub/api-gateway:latest
fi
wait_for_healthy "$GATEWAY_NAME"

if container_exists "$FRONTEND_NAME"; then
  podman start "$FRONTEND_NAME" >/dev/null
else
  log "starting ${FRONTEND_NAME}"
  # The browser runs outside the podman network, so the frontend must be
  # pointed at the gateway's *published host port* (baked in at build time
  # above via --build-arg), not the gateway's container name.
  podman run -d --name "$FRONTEND_NAME" --network "$NETWORK" \
    -p "${FRONTEND_PORT}:80" \
    eventhub/frontend:latest
fi
wait_for_healthy "$FRONTEND_NAME"

# ---------------------------------------------------------------------------
# 6. Run the analytics job once, now that everything is up, so the
#    dashboard has real data by the time this script finishes.
# ---------------------------------------------------------------------------
log "running analytics job"
podman run --rm --network "$NETWORK" \
  -e REDIS_URL="redis://${REDIS_NAME}:${REDIS_PORT}/0" \
  -e CATALOG_SERVICE_URL="http://${CATALOG_NAME}:${CATALOG_PORT}" \
  -e BOOKING_SERVICE_URL="http://${BOOKING_NAME}:${BOOKING_PORT}" \
  eventhub/analytics:latest python job.py

log "done. frontend: http://localhost:${FRONTEND_PORT}  gateway: http://localhost:${GATEWAY_PORT}"
#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/test-project-ajay-8050-8163/WebDashboard(Frontend)"
cd "$WORKSPACE"
LOGFILE=/tmp/webdashboard_devserver.log
PREVIEW=/tmp/webdashboard_root_preview.html
# Build if build script exists
HAS_BUILD=$(node -e "try{const p=require('./package.json');console.log(p.scripts&&p.scripts.build?1:0);}catch(e){console.log(0);}")
if [ "${HAS_BUILD}" = "1" ]; then
  npm run build --silent >"${LOGFILE}.build" 2>&1 || { echo "build failed, see ${LOGFILE}.build" >&2; tail -n 200 "${LOGFILE}.build" >&2; exit 13; }
fi
# Start dev server in a new process group
PORT=3000
setsid sh -c "PORT=${PORT} npm start" >"${LOGFILE}" 2>&1 &
LAUNCH_PID=$!
sleep 0.5
PGID=$(ps -o pgid= -p ${LAUNCH_PID} | tr -d ' ' || true)
if [ -z "${PGID}" ]; then
  echo "Failed to determine process group" >&2
  kill -TERM ${LAUNCH_PID} 2>/dev/null || true
  exit 14
fi
# Ensure we only kill this process group on exit
trap 'pg=${PGID}; if [ -n "${pg}" ]; then kill -TERM -"${pg}" 2>/dev/null || true; fi' EXIT
# wait for HTTP readiness with incremental backoff
TRY=0; MAX=30; SLEEP=1
while [ $TRY -lt $MAX ]; do
  if curl -sSf "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then break; fi
  if ! kill -0 ${LAUNCH_PID} 2>/dev/null; then
    echo "dev server process exited early, see ${LOGFILE}" >&2
    tail -n 200 "${LOGFILE}" >&2
    exit 15
  fi
  sleep $SLEEP
  TRY=$((TRY+1))
  SLEEP=$((SLEEP+1))
done
if [ $TRY -ge $MAX ]; then
  echo "server did not respond on ${PORT}" >&2
  kill -TERM -${PGID} 2>/dev/null || true
  exit 16
fi
# Capture a small HTML preview and leave logs for evidence
curl -sSf "http://127.0.0.1:${PORT}/" | head -n 200 > "${PREVIEW}"
# clean shutdown
kill -TERM -${PGID} 2>/dev/null || true
sleep 1
echo "preview saved: ${PREVIEW}, logs: ${LOGFILE}"

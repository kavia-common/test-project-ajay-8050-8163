#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/test-project-ajay-8050-8163/WebDashboard(Frontend)"
cd "$WORKSPACE"
LOGFILE=/tmp/webdashboard_devserver.log
PORT=3000
# Start dev server in new process group and background, capturing logs
setsid sh -c "PORT=${PORT} npm start" >"${LOGFILE}" 2>&1 &
LAUNCH_PID=$!
# Give a short moment for process group to be created
sleep 0.5
PGID=$(ps -o pgid= -p ${LAUNCH_PID} | tr -d ' ' || true)
if [ -z "${PGID}" ]; then
  echo "Failed to determine process group" >&2
  kill -TERM ${LAUNCH_PID} 2>/dev/null || true
  exit 14
fi
# Emit started info
echo "LAUNCH_PID=${LAUNCH_PID}" > /tmp/webdashboard_devserver_started.info
echo "PGID=${PGID}" >> /tmp/webdashboard_devserver_started.info
echo "logs: ${LOGFILE}"

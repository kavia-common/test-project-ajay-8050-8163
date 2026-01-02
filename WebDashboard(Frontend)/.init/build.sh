#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/test-project-ajay-8050-8163/WebDashboard(Frontend)"
cd "$WORKSPACE"
LOGFILE=/tmp/webdashboard_devserver.log
# run build only if package.json has a build script
HAS_BUILD=$(node -e "try{const p=require('./package.json');console.log(p.scripts&&p.scripts.build?1:0);}catch(e){console.log(0);}")
if [ "${HAS_BUILD}" = "1" ]; then
  npm run build --silent >"${LOGFILE}.build" 2>&1 || { echo "build failed, see ${LOGFILE}.build" >&2; tail -n 200 "${LOGFILE}.build" >&2; exit 13; }
fi

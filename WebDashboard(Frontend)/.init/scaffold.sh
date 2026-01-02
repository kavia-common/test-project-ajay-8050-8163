#!/usr/bin/env bash
set -euo pipefail
# scaffold: create minimal React app in workspace, merge intelligently when non-empty
WORKSPACE="/home/kavia/workspace/code-generation/test-project-ajay-8050-8163/WebDashboard(Frontend)"
PROFILE=/etc/profile.d/node_tooling.sh
TMP_PROFILE=$(mktemp)
# ensure workspace exists
mkdir -p "$WORKSPACE"
# persist minimal global environment (idempotent; backup if differs)
NPMPREFIX=$(npm config get prefix 2>/dev/null || echo "")
NPM_BIN=""
if [ -n "$NPMPREFIX" ]; then NPM_BIN="$NPMPREFIX/bin"; fi
cat > "$TMP_PROFILE" <<'EOF'
# node/npm tooling environment (auto-generated)
export NODE_ENV="${NODE_ENV:-development}"
export PATH="${PATH}:/usr/local/bin"
EOF
if [ -n "$NPM_BIN" ]; then echo "export PATH=\"$NPM_BIN:\$PATH\"" >> "$TMP_PROFILE"; fi
if [ -f "$PROFILE" ]; then
  if ! cmp -s "$PROFILE" "$TMP_PROFILE"; then
    sudo cp -a "$PROFILE" "$PROFILE.bak" || true
    sudo mv "$TMP_PROFILE" "$PROFILE"
  else
    rm -f "$TMP_PROFILE"
  fi
else
  sudo mv "$TMP_PROFILE" "$PROFILE"
fi
# move into workspace
cd "$WORKSPACE"
# detect TS intent
USE_TS=false
if [ -f "$WORKSPACE/tsconfig.json" ]; then USE_TS=true; fi
# detect CRA availability
USE_CRA=false
if command -v create-react-app >/dev/null 2>&1; then
  CRA_BIN=$(command -v create-react-app)
  CRA_VER=$($CRA_BIN --version 2>/dev/null || true)
  if [ -n "$CRA_VER" ]; then USE_CRA=true; fi
fi
# helper to try Vite fallback
scaffold_with_vite(){
  # prefer npm template with vite; create-app like minimal template
  # non-interactive: use npm create vite@latest
  if command -v npm >/dev/null 2>&1; then
    if [ "$USE_TS" = true ]; then
      npm create vite@latest . -- --template react-ts >/dev/null 2>&1 || return 1
    else
      npm create vite@latest . -- --template react >/dev/null 2>&1 || return 1
    fi
    return 0
  fi
  return 1
}
# scaffold logic
if [ -z "$(ls -A "$WORKSPACE")" ]; then
  # empty workspace: scaffold in-place
  if [ "$USE_CRA" = true ]; then
    if [ "$USE_TS" = true ]; then
      "$CRA_BIN" --template typescript . --use-npm --silent || { echo "CRA failed" >&2; scaffold_with_vite || exit 7; }
    else
      "$CRA_BIN" . --use-npm --silent || { echo "CRA failed" >&2; scaffold_with_vite || exit 8; }
    fi
  else
    if command -v npx >/dev/null 2>&1; then
      if [ "$USE_TS" = true ]; then
        npx create-react-app . --template typescript --use-npm --silent || { echo "npx CRA failed" >&2; scaffold_with_vite || exit 9; }
      else
        npx create-react-app . --use-npm --silent || { echo "npx CRA failed" >&2; scaffold_with_vite || exit 10; }
      fi
    else
      scaffold_with_vite || { echo "No npx and CRA unavailable" >&2; exit 11; }
    fi
  fi
else
  # non-empty: scaffold into temp dir then merge
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT
  if [ "$USE_CRA" = true ]; then
    if [ "$USE_TS" = true ]; then
      "$CRA_BIN" --template typescript "$TMPDIR" --use-npm --silent || { rm -rf "$TMPDIR"; echo "CRA temp scaffold failed" >&2; scaffold_with_vite && rm -rf "$TMPDIR" || exit 12; }
    else
      "$CRA_BIN" "$TMPDIR" --use-npm --silent || { rm -rf "$TMPDIR"; echo "CRA temp scaffold failed" >&2; scaffold_with_vite && rm -rf "$TMPDIR" || exit 13; }
    fi
  else
    if command -v npx >/dev/null 2>&1; then
      if [ "$USE_TS" = true ]; then
        npx create-react-app "$TMPDIR" --template typescript --use-npm --silent || { rm -rf "$TMPDIR"; echo "npx CRA temp scaffold failed" >&2; scaffold_with_vite && rm -rf "$TMPDIR" || exit 14; }
      else
        npx create-react-app "$TMPDIR" --use-npm --silent || { rm -rf "$TMPDIR"; echo "npx CRA temp scaffold failed" >&2; scaffold_with_vite && rm -rf "$TMPDIR" || exit 15; }
      fi
    else
      scaffold_with_vite || { echo "No npx and CRA unavailable for temp scaffold" >&2; rm -rf "$TMPDIR"; exit 16; }
    fi
  fi
  # backup existing critical files
  for f in package.json package-lock.json yarn.lock; do [ -f "$WORKSPACE/$f" ] && cp -a "$WORKSPACE/$f" "$WORKSPACE/$f.bak" >/dev/null 2>&1 || true; done
  # merge package.json scripts and dependencies using node
  if [ -f "$TMPDIR/package.json" ]; then
    node -e "const fs=require('fs'),W='$WORKSPACE',T='$TMPDIR';const wp=W+'/package.json',tp=T+'/package.json'; if(fs.existsSync(tp)){const a=JSON.parse(fs.readFileSync(tp)),b=fs.existsSync(wp)?JSON.parse(fs.readFileSync(wp)):{}; b.scripts=b.scripts||{}; b.dependencies=b.dependencies||{}; b.devDependencies=b.devDependencies||{}; Object.assign(b.scripts,a.scripts||{}); Object.assign(b.dependencies,a.dependencies||{}); Object.assign(b.devDependencies,a.devDependencies||{}); fs.writeFileSync(wp,JSON.stringify(b,null,2));}"
  fi
  # copy non-conflicting files (skip node_modules and package.json)
  (cd "$TMPDIR" && shopt -s dotglob; for p in * .[^.]*; do [ -e "$p" ] || continue; case "$p" in package.json|node_modules) continue ;; esac; if [ ! -e "$WORKSPACE/$p" ]; then cp -a "$p" "$WORKSPACE/"; fi; done)
  rm -rf "$TMPDIR"
  trap - EXIT
fi
# ensure .static-docs exists
mkdir -p "$WORKSPACE/.static-docs"
# ensure basic scripts exist in package.json (non-destructive)
if [ -f "$WORKSPACE/package.json" ]; then
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{};p.scripts.start=p.scripts.start||'react-scripts start';p.scripts.build=p.scripts.build||'react-scripts build';p.scripts.test=p.scripts.test||'react-scripts test';fs.writeFileSync('package.json',JSON.stringify(p,null,2));"
fi
exit 0

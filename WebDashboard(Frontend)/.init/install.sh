#!/usr/bin/env bash
set -euo pipefail
# install: install runtime and dev dependencies idempotently
WORKSPACE="/home/kavia/workspace/code-generation/test-project-ajay-8050-8163/WebDashboard(Frontend)"
cd "$WORKSPACE"
PKG_MANAGER=npm
[ -f package.json ] || { echo "ERROR: package.json missing, run scaffold first" >&2; exit 9; }
# Check Node/npm and provide remediation guidance; fail only if unusable
NODE_V=$(command -v node >/dev/null 2>&1 && node -v || echo "")
NPM_V=$(command -v npm >/dev/null 2>&1 && npm -v || echo "")
if [ -z "$NODE_V" ] || [ -z "$NPM_V" ]; then
  echo "ERROR: node or npm not found. Install Node LTS (>=16) and npm. Example: sudo apt-get update && sudo apt-get install -y nodejs npm" >&2
  exit 10
fi
NODE_MAJOR=$(echo "$NODE_V" | sed -E 's/^v?([0-9]+).*/\1/' || echo 0)
if [ "$NODE_MAJOR" -lt 12 ]; then
  echo "ERROR: Node ${NODE_V} unsupported; upgrade to >=16 recommended. Remediation: sudo apt-get remove -y nodejs && curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash - && sudo apt-get install -y nodejs" >&2
  exit 10
fi
# Detect toolchain
IS_CRA=$(node -e "try{const p=require('./package.json');console.log((p.dependencies&&p.dependencies['react-scripts'])||(p.devDependencies&&p.devDependencies['react-scripts'])?1:0)}catch(e){console.log(0)}")
IS_VITE=$(node -e "try{const p=require('./package.json');console.log((p.devDependencies&&p.devDependencies['vite'])||(p.dependencies&&p.dependencies['vite'])?1:0)}catch(e){console.log(0)}")
# Ensure react/react-dom exist in package.json (use '*' as placeholder if absent)
node -e "const fs=require('fs'),p=JSON.parse(fs.readFileSync('package.json'));p.dependencies=p.dependencies||{};let ch=false;if(!p.dependencies.react){p.dependencies.react='*';ch=true;}if(!p.dependencies['react-dom']){p.dependencies['react-dom']='*';ch=true;}if(ch)fs.writeFileSync('package.json',JSON.stringify(p,null,2));" >/dev/null
# Install runtime deps according to package.json
$PKG_MANAGER i --no-audit --no-fund --silent >/dev/null
# Detect TypeScript usage
USE_TS=false
if [ -f tsconfig.json ]; then USE_TS=true; else
  if node -e "try{const p=require('./package.json');console.log(!!((p.devDependencies&&p.devDependencies.typescript)||(p.dependencies&&p.dependencies.typescript)))}catch(e){console.log(false)}" | grep -q true; then USE_TS=true; fi
fi
# Prepare dev deps array (plain space-separated string to avoid bash array expansion quoting issues)
DEV_DEPS_BASE=("@testing-library/react" "@testing-library/jest-dom" "jest")
DEV_DEPS=()
for d in "${DEV_DEPS_BASE[@]}"; do DEV_DEPS+=("$d"); done
if [ "$USE_TS" = true ]; then
  for d in "@types/react" "@types/react-dom" "@types/jest" "ts-jest" "typescript"; do DEV_DEPS+=("$d"); done
fi
if [ "$IS_CRA" = "1" ]; then DEV_DEPS+=("react-scripts"); fi
# Compute missing packages by checking package.json (idempotent). Use json detection per-package to avoid false positives.
MISSING=()
for pkg in "${DEV_DEPS[@]}"; do
  node -e "try{const p=require('./package.json');const has=(p.devDependencies&&p.devDependencies['$pkg'])||(p.dependencies&&p.dependencies['$pkg']);process.exit(has?0:1);}catch(e){process.exit(1);}"
  if [ $? -ne 0 ]; then
    MISSING+=("$pkg")
  fi
done
if [ ${#MISSING[@]} -gt 0 ]; then
  # Install missing dev deps in one command
  echo "Installing devDependencies: ${MISSING[*]}"
  $PKG_MANAGER i -D --no-audit --no-fund --silent "${MISSING[@]}" >/dev/null
else
  echo "No missing devDependencies; skipping install"
fi
# Write jest.config.js if missing
if [ ! -f jest.config.js ]; then
  cat > jest.config.js <<'JST'
module.exports={testEnvironment:'jsdom',transform:{'^.+\\.(js|jsx|ts|tsx)$':'babel-jest'}};
JST
fi
# Write babel.config.js if missing
if [ ! -f babel.config.js ]; then
  cat > babel.config.js <<'BABEL'
module.exports={presets:['@babel/preset-env','@babel/preset-react']};
BABEL
fi
# Validate that npm and node are on PATH and report versions
echo "node: $(node -v) npm: $(npm -v)"

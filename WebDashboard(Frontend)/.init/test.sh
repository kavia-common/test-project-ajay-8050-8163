#!/usr/bin/env bash
set -euo pipefail
# Minimal non-interactive test runner script for the workspace
WORKSPACE="/home/kavia/workspace/code-generation/test-project-ajay-8050-8163/WebDashboard(Frontend)"
cd "$WORKSPACE"
mkdir -p src/__tests__
# create test matching project TS/JS usage
if [ -f tsconfig.json ]; then
  cat > src/__tests__/App.test.tsx <<'TS'
import React from 'react'
import { render, screen } from '@testing-library/react'
function App(){ return <div>WebDashboard (scaffold)</div> }
test('renders scaffold text', ()=>{ render(<App/>); expect(screen.getByText(/WebDashboard/i)).toBeTruthy() })
TS
else
  cat > src/__tests__/App.test.jsx <<'JS'
import React from 'react'
import { render, screen } from '@testing-library/react'
function App(){ return <div>WebDashboard (scaffold)</div> }
test('renders scaffold text', ()=>{ render(<App/>); expect(screen.getByText(/WebDashboard/i)).toBeTruthy() })
JS
fi
TMP_REPORT=/tmp/webdashboard_test_output.txt
# detect react-scripts usage in package.json safely
HAS_REACT_SCRIPTS=0
if [ -f package.json ]; then
  HAS_REACT_SCRIPTS=$(node -e "try{const p=require('./package.json');console.log((p.scripts&&p.scripts.test&&p.scripts.test.includes('react-scripts'))?1:0)}catch(e){console.log(0)}") || true
fi
# Run tests once non-interactively, capture output
if [ "$HAS_REACT_SCRIPTS" = "1" ]; then
  # react-scripts test needs jest flags forwarded after --
  CI=true npm test --silent -- --watchAll=false --runInBand >"${TMP_REPORT}" 2>&1 || { echo "tests failed, see ${TMP_REPORT}" >&2; cat "${TMP_REPORT}" >&2; exit 12; }
else
  # generic npm test (likely jest) - ensure CI true to force single-run
  CI=true npm test --silent >"${TMP_REPORT}" 2>&1 || { echo "tests failed, see ${TMP_REPORT}" >&2; cat "${TMP_REPORT}" >&2; exit 12; }
fi
echo "tests passed, report: ${TMP_REPORT}"

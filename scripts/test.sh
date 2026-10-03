#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_ROOT"
mkdir -p .build/module-cache

swiftc -swift-version 6 -parse-as-library \
  -module-cache-path .build/module-cache \
  Sources/FocusTimer/SessionClock.swift \
  Tests/FocusTimerTests/SessionClockTests.swift \
  -o .build/clock-tests

.build/clock-tests

#!/usr/bin/env bash
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required: https://brew.sh"
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing xcodegen..."
  brew install xcodegen
fi

xcodegen generate --spec project.yml

echo "Project generated: BrowserBaby.xcodeproj"

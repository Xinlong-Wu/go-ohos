#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"

if ! command -v go >/dev/null 2>&1; then
  echo "A Go bootstrap toolchain is required in PATH." >&2
  exit 2
fi

(
  cd "$repo_root/src"
  umask 0022
  bash ./make.bash -v
)

export GOROOT="$repo_root"
export PATH="$GOROOT/bin:$PATH"
export GOENV=off
export GOFLAGS=
export GOTOOLCHAIN=local

cd "$repo_root/src"

go test -short std
go test cmd/asm/internal/asm cmd/cgo/internal/test cmd/link
go test cmd/go -run '^TestDocsUpToDate$'

CGO_ENABLED=0 go tool dist test -compile-only
CGO_ENABLED=1 go tool dist test -compile-only
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go tool dist test -compile-only

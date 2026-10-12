#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
goroot="$repo_root"
output_dir=""
skip_dist=0

usage() {
  cat <<'EOF'
Usage: compile.sh [--goroot DIR] [--output DIR] [--skip-dist]

Build and compile-check the OpenHarmony arm64 target using a Go tree. The
script does not execute target binaries; use test-runtime.sh for that.
EOF
}

while (($# > 0)); do
  case "$1" in
    --goroot)
      (($# >= 2)) || { echo "--goroot needs a directory" >&2; exit 2; }
      goroot="$2"
      shift 2
      ;;
    --output)
      (($# >= 2)) || { echo "--output needs a directory" >&2; exit 2; }
      output_dir="$2"
      shift 2
      ;;
    --skip-dist)
      skip_dist=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

goroot="$(cd "$goroot" && pwd)"
go_cmd="$goroot/bin/go"
if [[ ! -x "$go_cmd" ]]; then
  echo "Go toolchain not found: $go_cmd" >&2
  echo "Run src/make.bash first or pass --goroot to a built tree." >&2
  exit 2
fi

export GOROOT="$goroot"
export PATH="$GOROOT/bin:$PATH"
export GOENV=off
export GOFLAGS=
export GOTOOLCHAIN=local

if [[ -z "$output_dir" ]]; then
  output_dir="$(mktemp -d)"
  cleanup_output=1
else
  mkdir -p "$output_dir"
  output_dir="$(cd "$output_dir" && pwd)"
  cleanup_output=0
fi
cleanup() {
  if ((cleanup_output)) && [[ -n "${output_dir:-}" && -d "$output_dir" ]]; then
    rm -rf -- "$output_dir"
  fi
}
trap cleanup EXIT

echo "Using $("$go_cmd" version)"
echo "OpenHarmony compile checks: GOOS=openharmony GOARCH=arm64"

echo "==> compile standard library (pure Go)"
CGO_ENABLED=0 GOOS=openharmony GOARCH=arm64 \
  "$go_cmd" build -a std

if (( ! skip_dist )); then
  echo "==> compile dist tests (pure Go)"
  CGO_ENABLED=0 GOOS=openharmony GOARCH=arm64 \
    "$go_cmd" tool dist test -compile-only
fi

echo "==> rebuild runtime with OpenHarmony ARM64 TLS-GD mode"
CGO_ENABLED=0 GOOS=openharmony GOARCH=arm64 \
  "$go_cmd" build -a -tlsmodegd runtime

echo "==> compile OpenHarmony pure-Go smoke binary"
smoke_output="$output_dir/openharmony-purego-smoke"
(
  cd "$script_dir/testdata/purego"
  GO111MODULE=off CGO_ENABLED=0 GOOS=openharmony GOARCH=arm64 \
    "$go_cmd" build -trimpath -o "$smoke_output" .
)

file "$smoke_output" 2>/dev/null || true
echo "OpenHarmony compile checks passed."

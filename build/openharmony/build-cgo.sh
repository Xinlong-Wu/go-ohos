#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
goroot=""
sdk_native="${OHOS_SDK_NATIVE:-}"
output_dir=""

usage() {
  cat <<'EOF'
Usage: build-cgo.sh --goroot DIR --sdk DIR --output DIR

Cross-compile the OpenHarmony arm64 cgo smoke binary. The SDK directory must
contain llvm/bin/clang and sysroot. The generated directory contains the
binary, a checksum, TLS relocation evidence, and a small build manifest.
EOF
}

while (($# > 0)); do
  case "$1" in
    --goroot)
      (($# >= 2)) || { echo "--goroot needs a directory" >&2; exit 2; }
      goroot="$2"
      shift 2
      ;;
    --sdk)
      (($# >= 2)) || { echo "--sdk needs a directory" >&2; exit 2; }
      sdk_native="$2"
      shift 2
      ;;
    --output)
      (($# >= 2)) || { echo "--output needs a directory" >&2; exit 2; }
      output_dir="$2"
      shift 2
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

[[ -n "$goroot" ]] || { echo "--goroot is required" >&2; exit 2; }
[[ -n "$sdk_native" ]] || { echo "--sdk is required (or set OHOS_SDK_NATIVE)" >&2; exit 2; }
[[ -n "$output_dir" ]] || { echo "--output is required" >&2; exit 2; }

goroot="$(cd "$goroot" && pwd)"
sdk_native="$(cd "$sdk_native" && pwd)"
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
go_cmd="$goroot/bin/go"
clang="$sdk_native/llvm/bin/clang"
clangxx="$sdk_native/llvm/bin/clang++"
sysroot="$sdk_native/sysroot"

for required in "$go_cmd" "$clang" "$clangxx" "$sysroot"; do
  if [[ ! -e "$required" ]]; then
    echo "Required OpenHarmony SDK/toolchain path is missing: $required" >&2
    exit 2
  fi
done
if [[ ! -x "$go_cmd" || ! -x "$clang" || ! -x "$clangxx" ]]; then
  echo "Go or OpenHarmony clang is not executable." >&2
  exit 2
fi

export GOROOT="$goroot"
export PATH="$GOROOT/bin:$PATH"
export GOENV=off
export GOFLAGS=
export GOTOOLCHAIN=local
export GOOS=openharmony
export GOARCH=arm64
export CGO_ENABLED=1

# Keep the target and sysroot in CC/CXX so cgo and the external linker use the
# same OpenHarmony ABI. Force C TLS to the general-dynamic model as well, so
# the smoke binary exercises the loader/runtime path that the port requires.
export CC="$clang --target=aarch64-linux-ohos --sysroot=$sysroot"
export CXX="$clangxx --target=aarch64-linux-ohos --sysroot=$sysroot"
export CGO_CFLAGS="--target=aarch64-linux-ohos --sysroot=$sysroot -ftls-model=global-dynamic"
export CGO_CXXFLAGS="$CGO_CFLAGS"
export CGO_LDFLAGS="-Wl,-dynamic-linker,/lib/ld-musl-aarch64.so.1"

binary="$output_dir/openharmony-cgo-smoke"
echo "Using $("$go_cmd" version)"
echo "Using OpenHarmony compiler: $CC"
echo "==> build OpenHarmony cgo smoke binary"
(
  cd "$script_dir/testdata/cgo"
  # PIE makes the Go assembler select the TLS-GD sequence for runtime.tls_g;
  # a non-PIE executable would select the local-exec form and cannot call the
  # musl TLS descriptor resolver used by the OpenHarmony port.
  GO111MODULE=off "$go_cmd" build -trimpath -buildmode=pie -tlsmodegd \
    -ldflags='-linkmode=external -extldflags=-Wl,-dynamic-linker,/lib/ld-musl-aarch64.so.1' \
    -o "$binary" .
)

readelf_cmd=""
if [[ -x "$sdk_native/llvm/bin/llvm-readelf" ]]; then
  readelf_cmd="$sdk_native/llvm/bin/llvm-readelf"
elif command -v readelf >/dev/null 2>&1; then
  readelf_cmd="$(command -v readelf)"
fi
if [[ -z "$readelf_cmd" ]]; then
  echo "llvm-readelf or readelf is required to validate the cgo binary." >&2
  exit 2
fi

# A final executable is allowed to relax a local C TLS reference to a more
# direct model. Inspect the compiler's relocatable object as well. Depending
# on the OpenHarmony SDK configuration, Clang emits either native TLSDESC/TLSGD
# relocations or its supported __emutls helper sequence; both are retained as
# explicit TLS evidence. The linked binary is exercised later in DockerHarmony,
# and the Go runtime TLS-GD path is checked by compile.sh.
tls_object="$output_dir/openharmony-cgo-smoke-tls.o"
echo "==> compile and inspect OpenHarmony C TLS object"
"$clang" \
  --target=aarch64-linux-ohos \
  --sysroot="$sysroot" \
  -fPIC -ftls-model=global-dynamic -pthread \
  -c "$script_dir/testdata/cgo/smoke.c" \
  -o "$tls_object"
"$readelf_cmd" -r "$tls_object" > "$output_dir/openharmony-cgo-smoke-tls.relocations"
if ! grep -Eq 'R_AARCH64_(TLSDESC|TLSGD)|__emutls_' "$output_dir/openharmony-cgo-smoke-tls.relocations"; then
  echo "OpenHarmony C TLS object has no AArch64 TLS relocation." >&2
  cat "$output_dir/openharmony-cgo-smoke-tls.relocations" >&2
  exit 1
fi

machine="$($readelf_cmd -h "$binary" | sed -n 's/^ *Machine: *//p' | head -n 1)"
if [[ "$machine" != *AArch64* ]]; then
  echo "Unexpected cgo binary machine: $machine" >&2
  exit 1
fi
if ! "$readelf_cmd" -l "$binary" | grep -Fq '/lib/ld-musl-aarch64.so.1'; then
  echo "OpenHarmony cgo binary does not use the musl loader." >&2
  "$readelf_cmd" -l "$binary" >&2 || true
  exit 1
fi
"$readelf_cmd" -r "$binary" > "$output_dir/openharmony-cgo-smoke.relocations"
if grep -Eq 'R_AARCH64_(TLSDESC|TLSGD)|__emutls_' "$output_dir/openharmony-cgo-smoke.relocations"; then
  echo "Linked OpenHarmony cgo binary retained an AArch64 TLS relocation."
else
  echo "Linked OpenHarmony cgo binary relaxed the C TLS relocation; object evidence passed."
fi

(
  cd "$output_dir"
  sha256sum "$(basename "$binary")" > "$(basename "$binary").sha256"
  sha256sum -c "$(basename "$binary").sha256"
)

{
  printf 'goroot=%s\n' "$goroot"
  printf 'go_version=%s\n' "$($go_cmd version)"
  printf 'sdk_native=%s\n' "$sdk_native"
  printf 'clang_version=%s\n' "$($clang --version | sed -n '1p')"
  printf 'target=aarch64-linux-ohos\n'
  printf 'interpreter=/lib/ld-musl-aarch64.so.1\n'
} > "$output_dir/openharmony-cgo-smoke.manifest"

echo "OpenHarmony cgo smoke binary and manifest created in $output_dir"

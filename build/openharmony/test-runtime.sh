#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
goroot=""
repo_for_smoke="$repo_root"
output_dir=""
cgo_binary=""
go_test_packages="${OPENHARMONY_GO_TEST_PACKAGES:-sync}"
skip_image_pull=0

usage() {
  cat <<'EOF'
Usage: test-runtime.sh --goroot DIR [options]

Build (when needed) and execute OpenHarmony arm64 smoke binaries inside the
DockerHarmony mini rootfs.

Options:
  --goroot DIR             Linux/arm64 Go tree used to build target binaries.
  --repo DIR               Source checkout containing build/openharmony.
  --output DIR             Keep generated pure-Go smoke output here.
  --cgo-binary FILE        Also execute a pre-built cgo smoke binary.
  --go-test-packages LIST  Comma-separated GOROOT packages to run via -exec.
                          Empty disables existing-package tests.
  --skip-image-pull        Do not pull; require the pinned image locally.
EOF
}

while (($# > 0)); do
  case "$1" in
    --goroot)
      (($# >= 2)) || { echo "--goroot needs a directory" >&2; exit 2; }
      goroot="$2"
      shift 2
      ;;
    --repo)
      (($# >= 2)) || { echo "--repo needs a directory" >&2; exit 2; }
      repo_for_smoke="$2"
      shift 2
      ;;
    --output)
      (($# >= 2)) || { echo "--output needs a directory" >&2; exit 2; }
      output_dir="$2"
      shift 2
      ;;
    --cgo-binary)
      (($# >= 2)) || { echo "--cgo-binary needs a file" >&2; exit 2; }
      cgo_binary="$2"
      shift 2
      ;;
    --go-test-packages)
      (($# >= 2)) || { echo "--go-test-packages needs a value" >&2; exit 2; }
      go_test_packages="$2"
      shift 2
      ;;
    --skip-image-pull)
      skip_image_pull=1
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

[[ -n "$goroot" ]] || { echo "--goroot is required" >&2; exit 2; }
goroot="$(cd "$goroot" && pwd)"
repo_for_smoke="$(cd "$repo_for_smoke" && pwd)"
go_cmd="$goroot/bin/go"
runner="$script_dir/go_openharmony_arm64_exec"
image_ref="${OPENHARMONY_DOCKER_IMAGE:-ghcr.io/hqzing/dockerharmony:7.0@sha256:2befba873913622f3395ff35d9f135e44efc4c33b0969f671d707e17339b1ecb}"
expected_digest="sha256:2befba873913622f3395ff35d9f135e44efc4c33b0969f671d707e17339b1ecb"
expected_revision="754659d2c089d0a4c81fddec413b534fb127808e"

[[ -x "$go_cmd" ]] || { echo "Go toolchain not found: $go_cmd" >&2; exit 2; }
[[ -x "$runner" ]] || { echo "Runtime executor is not executable: $runner" >&2; exit 2; }
command -v docker >/dev/null 2>&1 || { echo "docker is required" >&2; exit 2; }

export GOROOT="$goroot"
export PATH="$GOROOT/bin:$PATH"
export GOENV=off
export GOFLAGS=
export GOTOOLCHAIN=local
export OPENHARMONY_DOCKER_IMAGE="$image_ref"
export OPENHARMONY_GOROOT="$goroot"

host_arch="$(uname -m)"
case "$host_arch" in
  aarch64|arm64) ;;
  x86_64|amd64)
    echo "Using an amd64 host; Docker must have arm64 binfmt/QEMU configured."
    ;;
  *)
    echo "DockerHarmony runtime tests require an arm64 host or an amd64 host with binfmt/QEMU; found $host_arch." >&2
    exit 2
    ;;
esac

if (( ! skip_image_pull )); then
  echo "==> pull pinned DockerHarmony image"
  docker pull "$image_ref"
fi

arch="$(docker image inspect --format '{{.Architecture}}' "$image_ref")"
[[ "$arch" == "arm64" ]] || { echo "DockerHarmony image architecture is $arch, want arm64" >&2; exit 1; }
repo_digests="$(docker image inspect --format '{{join .RepoDigests "\n"}}' "$image_ref")"
grep -Fq "@$expected_digest" <<<"$repo_digests" || {
  echo "Docker image digest does not match $expected_digest:" >&2
  echo "$repo_digests" >&2
  exit 1
}
revision="$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$image_ref")"
[[ "$revision" == "$expected_revision" ]] || {
  echo "DockerHarmony source revision is $revision, want $expected_revision" >&2
  exit 1
}

echo "==> validate DockerHarmony musl loader"
if ! docker run --rm --platform linux/arm64 --network none --entrypoint /bin/sh \
  --read-only --tmpfs /tmp:rw,nosuid,nodev "$image_ref" \
  -c 'test -x /lib/ld-musl-aarch64.so.1 && test -x /bin/sh'; then
  if [[ "$host_arch" == "x86_64" || "$host_arch" == "amd64" ]]; then
    echo "Docker could not execute the arm64 image; install/register arm64 binfmt/QEMU on this host." >&2
  fi
  exit 1
fi

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

pure_binary="$output_dir/openharmony-purego-smoke"
echo "==> build OpenHarmony pure-Go smoke binary"
(
  cd "$repo_for_smoke/build/openharmony/testdata/purego"
  GO111MODULE=off CGO_ENABLED=0 GOOS=openharmony GOARCH=arm64 \
    "$go_cmd" build -trimpath -o "$pure_binary" .
)

expected_version="$(sed -n '1p' "$goroot/VERSION")"
export OPENHARMONY_EXPECTED_GO_VERSION="$expected_version"
echo "==> execute pure-Go smoke binary in OpenHarmony userland"
"$runner" "$pure_binary"

echo "==> verify target failures propagate through Docker"
set +e
"$runner" "$pure_binary" --intentional-failure
failure_status=$?
set -e
if ((failure_status != 97)); then
  echo "Intentional target failure returned $failure_status, want 97." >&2
  exit 1
fi

if [[ -n "$cgo_binary" ]]; then
  cgo_binary="$(realpath "$cgo_binary")"
  [[ -f "$cgo_binary" ]] || { echo "cgo binary not found: $cgo_binary" >&2; exit 2; }
  if [[ -f "$cgo_binary.sha256" ]]; then
    (
      cd "$(dirname "$cgo_binary")"
      sha256sum -c "$(basename "$cgo_binary").sha256"
    )
  fi
  echo "==> execute cgo smoke binary in OpenHarmony userland"
  "$runner" "$cgo_binary"
fi

if [[ -n "$go_test_packages" ]]; then
  IFS=',' read -ra packages <<< "$go_test_packages"
  for package in "${packages[@]}"; do
    [[ -n "$package" ]] || continue
    echo "==> execute Go test package in OpenHarmony userland: $package"
    (
      cd "$goroot/src"
      CGO_ENABLED=0 GOOS=openharmony GOARCH=arm64 \
        "$go_cmd" test -short -count=1 -exec "$runner" "$package"
    )
  done
fi

echo "OpenHarmony Docker runtime tests passed."

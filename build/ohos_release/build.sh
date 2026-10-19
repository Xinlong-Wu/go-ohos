#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
release_tag="${1:-${tag:-default}}"
output_dir="${2:-${OUTPUT_DIR:-$repo_root/target}}"

if [[ ! "$release_tag" =~ ^[[:alnum:]][[:alnum:]._-]*$ ]]; then
  echo "Invalid release tag: $release_tag" >&2
  exit 2
fi

if ! command -v go >/dev/null 2>&1; then
  echo "A Go bootstrap toolchain is required in PATH." >&2
  exit 2
fi

case "$(uname -s)" in
  Linux)
    host_os="linux"
    ;;
  Darwin)
    host_os="darwin"
    ;;
  *)
    echo "Unsupported host operating system: $(uname -s)" >&2
    exit 2
    ;;
esac

case "$(uname -m)" in
  x86_64 | amd64)
    host_arch="amd64"
    ;;
  aarch64 | arm64)
    host_arch="arm64"
    ;;
  *)
    echo "Unsupported host architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

if [[ -n "${EXPECTED_OS:-}" && "$host_os" != "$EXPECTED_OS" ]]; then
  echo "Expected host operating system $EXPECTED_OS, got $host_os." >&2
  exit 2
fi

if [[ -n "${EXPECTED_ARCH:-}" && "$host_arch" != "$EXPECTED_ARCH" ]]; then
  echo "Expected host architecture $EXPECTED_ARCH, got $host_arch." >&2
  exit 2
fi

if tar --version 2>/dev/null | grep -q 'GNU tar'; then
  tar_command="tar"
elif command -v gtar >/dev/null 2>&1; then
  tar_command="gtar"
else
  echo "GNU tar is required for reproducible release archives." >&2
  exit 2
fi

if command -v sha256sum >/dev/null 2>&1; then
  checksum_create=(sha256sum)
  checksum_verify=(sha256sum -c)
elif command -v shasum >/dev/null 2>&1; then
  checksum_create=(shasum -a 256)
  checksum_verify=(shasum -a 256 -c)
else
  echo "sha256sum or shasum is required." >&2
  exit 2
fi

go env
go version

(
  cd "$repo_root/src"
  umask 0022
  bash ./make.bash -v
)

toolchain_os="$("$repo_root/bin/go" env GOHOSTOS)"
toolchain_arch="$("$repo_root/bin/go" env GOHOSTARCH)"
if [[ "$toolchain_os" != "$host_os" || "$toolchain_arch" != "$host_arch" ]]; then
  echo "Built toolchain is $toolchain_os/$toolchain_arch, expected $host_os/$host_arch." >&2
  exit 2
fi

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
if [[ "$host_os" == linux ]]; then
  package_name="${release_tag}-${host_arch}.tar.gz"
else
  package_name="${release_tag}-${host_os}-${host_arch}.tar.gz"
fi
output_path="$output_dir/$package_name"

staging_dir="$(mktemp -d)"
cleanup() {
  if [[ -n "${staging_dir:-}" && -d "$staging_dir" ]]; then
    rm -rf -- "$staging_dir"
  fi
}
trap cleanup EXIT

package_root="$staging_dir/$release_tag"
mkdir -p "$package_root"

"$tar_command" -C "$repo_root" \
  --exclude='./.git' \
  --exclude='./.git/*' \
  --exclude='./.github' \
  --exclude='./.github/*' \
  --exclude='./build' \
  --exclude='./build/*' \
  --exclude='./pkg/obj' \
  --exclude='./pkg/obj/*' \
  --exclude='./target' \
  --exclude='./target/*' \
  -cf - . | "$tar_command" -C "$package_root" -xf -

source_date_epoch="${SOURCE_DATE_EPOCH:-$(git -C "$repo_root" show -s --format=%ct HEAD)}"
if [[ ! "$source_date_epoch" =~ ^[0-9]+$ ]]; then
  echo "SOURCE_DATE_EPOCH must be a Unix timestamp." >&2
  exit 2
fi

(
  cd "$staging_dir"
  "$tar_command" --sort=name \
    --mtime="@$source_date_epoch" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -cf - "$release_tag" | gzip -n >"$output_path"
)

(
  cd "$output_dir"
  "${checksum_create[@]}" "$package_name" >"$package_name.sha256"
  "${checksum_verify[@]}" "$package_name.sha256"
)

echo "Created release assets:"
echo "  $output_path"
echo "  $output_path.sha256"

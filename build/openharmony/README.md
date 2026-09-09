# OpenHarmony target and runtime tests

This directory contains the checks that are specific to the OpenHarmony
`arm64` port. The checks are deliberately split into two layers:

- `compile.sh` cross-compiles the standard library, `dist` tests, the runtime
  TLS-GD path, and a pure-Go smoke binary. It can run on any Linux host with a
  built Go tree.
- `test-runtime.sh` executes target binaries in the pinned DockerHarmony
  OpenHarmony userland. It requires an arm64 Linux host (the GitHub workflow
  uses `ubuntu-24.04-arm`). An amd64 host must have arm64 binfmt/QEMU already
  configured; this code does not install privileged binfmt handlers.
- `build-cgo.sh` uses an OpenHarmony SDK to build the cgo smoke binary. The
  binary is then executed by `test-runtime.sh` in DockerHarmony.

## Fixed runtime image

The default image is:

```text
ghcr.io/hqzing/dockerharmony:7.0@sha256:2befba873913622f3395ff35d9f135e44efc4c33b0969f671d707e17339b1ecb
```

It is an arm64 OpenHarmony 7.0 mini rootfs. The runner verifies the image
architecture, digest, source revision (`754659d2c089d0a4c81fddec413b534fb127808e`),
and the `/lib/ld-musl-aarch64.so.1` loader before executing a test.

DockerHarmony supplies OpenHarmony userland on a Linux kernel. It does not
provide the full device framework (Ability, graphics, device drivers, or all
system services), so those still require a device or a complete emulator.

## Local commands

Build a Go tree first, or point the scripts at an extracted toolchain:

```sh
cd src && bash ./make.bash -v
cd ..
bash build/openharmony/compile.sh --goroot "$PWD"
```

On an arm64 Linux host with Docker, or an amd64 host with registered arm64
binfmt/QEMU:

```sh
bash build/openharmony/test-runtime.sh \
  --goroot "$PWD" \
  --repo "$PWD" \
  --go-test-packages sync
```

To build and run the cgo smoke test, provide an OpenHarmony SDK whose native
component contains `llvm/bin/clang` and `sysroot`:

```sh
bash build/openharmony/build-cgo.sh \
  --goroot "$PWD" \
  --sdk "$OHOS_SDK_NATIVE" \
  --output /tmp/openharmony-cgo-assets
bash build/openharmony/test-runtime.sh \
  --goroot "$PWD" \
  --cgo-binary /tmp/openharmony-cgo-assets/openharmony-cgo-smoke
```

The runtime smoke binary checks the port identity (`runtime.IsOpenharmony`),
goroutines and atomics, GC, timers, temporary files, signals, loopback TCP,
HTTP/TLS, crypto randomness, and subprocess execution. The cgo binary checks
C calls, errno, C TLS, pthread creation, and a C-to-Go callback. `build-cgo.sh`
also records the relocatable C object and its AArch64 TLS relocations; a final
executable may legally have that relocation relaxed by the linker, so the
object is the portable code-generation check.

OpenHarmony target binaries intentionally report the compatible `linux` value
for `runtime.GOOS`; `runtime.IsOpenharmony` is the authoritative port marker.

# OpenHarmony Go releases

OpenHarmony releases follow stable tags from the upstream
[`golang/go`](https://github.com/golang/go) repository. The upstream source tag
and the OpenHarmony distribution tag are deliberately different:

- Upstream source tag: `go1.27.1`
- OpenHarmony release tag: `go1.27.1-ohos.1`

The suffix is incremented when OpenHarmony-specific fixes are released without
changing the upstream Go version.

## Release flow

The scheduled `.github/workflows/sync-upstream.yml` workflow checks for the
latest official stable `goX.Y.Z` tag every third calendar day. When a newer
stable release exists, it:

1. Creates `sync/upstream-<upstream-tag>` from the exact upstream tag.
2. Adds one commit that updates `.github/release.json` to
   `<upstream-tag>-ohos.1`.
3. Opens a pull request targeting `master` without enabling auto-merge.

Resolve any OpenHarmony conflicts manually, preserve the prepared release
metadata, and wait for the release checks. Merge with **Create a merge commit**;
squash and rebase merges discard the upstream-tag ancestry required by the
release gate.

For a manual fallback, prepare the same two-parent history and manifest change
on a dedicated release branch, then open an equivalent pull request into
`master`.

Changing `.github/release.json` on `master` starts the release workflow. The
workflow verifies that the upstream tag exists, is an ancestor of the merged
commit, and matches `VERSION`. It then repeats short standard-library tests,
targeted toolchain tests, OpenHarmony cross-compilation checks, and
DockerHarmony OpenHarmony userland runtime checks on the merged commit; builds
amd64 and arm64 archives; checks their SHA-256 files; creates an annotated tag;
and publishes the GitHub Release. The runtime job executes the arm64 archive
produced by that same workflow, so publishing cannot proceed if the release
artifact does not run in the pinned OpenHarmony 7.0 mini rootfs.

The OpenHarmony-specific scripts and their limitations are documented in
[`build/openharmony/README.md`](openharmony/README.md). DockerHarmony provides
OpenHarmony userland over a Linux kernel; it is not a substitute for tests
that require device services, graphics, or hardware drivers.

Ordinary pull requests do not change `.github/release.json` and therefore do
not publish releases. The workflow can be restarted with `workflow_dispatch`
if an external runner or GitHub service failure interrupts publishing.

Do not push the upstream `go1.x.y` tag to this fork as the OpenHarmony release
tag. That tag identifies the unmodified upstream commit and does not contain
the OpenHarmony patches.

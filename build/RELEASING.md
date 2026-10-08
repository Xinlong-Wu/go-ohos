# OpenHarmony Go releases

OpenHarmony releases follow stable tags from the upstream
[`golang/go`](https://github.com/golang/go) repository. The upstream source tag
and the OpenHarmony distribution tag are deliberately different:

- Upstream source tag: `go1.27.1`
- OpenHarmony release tag: `go1.27.1-ohos.1`
- Release branch: `release/go1.27.1-ohos.1`

The suffix is incremented for an OpenHarmony-only rebuild or fix that keeps the
same upstream Go version.

## Scheduled release flow

The `.github/workflows/sync-upstream.yml` workflow checks for the numerically
latest official stable `goX.Y.Z` tag every third calendar day. It compares that
tag with the upstream versions encoded in this fork's existing
`goX.Y.Z-ohos.N` tags.

When a newer stable release exists, it:

1. Creates `release/<upstream-tag>-ohos.1`, pointing directly at the exact
   upstream tag commit.
2. Opens a pull request from that branch into `master` without enabling
   auto-merge.
3. Leaves all OpenHarmony conflict resolution to the user.

The release branch name is the release manifest. The publication workflow
accepts only the exact form `release/goX.Y.Z-ohos.N`, derives both tag names
from it, and independently verifies `VERSION` and the official upstream tag
ancestry.

## Manual merge and automatic publication

Resolve conflicts while preserving the downstream OpenHarmony port. Then wait
for the release checks and merge using **Create a merge commit**. Squash and
rebase merges are unsupported because they discard the official upstream-tag
ancestry required by the release gate.

`.github/workflows/publish-release.yml` handles two phases:

1. For an open release PR, it validates the branch-derived version, tests the
   synthetic merge result, and builds amd64 and arm64 archives without
   publishing them.
2. When that PR is manually merged, its `pull_request.closed` event supplies
   the actual merge commit. The workflow verifies that it is a two-parent
   merge commit contained in `master`, repeats all tests and builds, creates
   the annotated OpenHarmony tag, and publishes the GitHub Release.

The release gate includes short standard-library tests, targeted toolchain
tests, OpenHarmony cross-compilation checks, and DockerHarmony OpenHarmony
userland runtime checks. The runtime job executes the arm64 archive produced by
the same workflow, so publishing cannot proceed if that toolchain does not run
inside the pinned OpenHarmony 7.0 mini rootfs.

The OpenHarmony-specific scripts and their limitations are documented in
[`build/openharmony/README.md`](openharmony/README.md). DockerHarmony provides
OpenHarmony userland over a Linux kernel; it is not a substitute for tests that
require device services, graphics, or hardware drivers.

Ordinary pull requests are ignored by the release jobs because their source
branches do not match `release/goX.Y.Z-ohos.N`. A failed merged-release run can
be retried from GitHub Actions. `workflow_dispatch` is also available and
requires an explicit OpenHarmony release tag; its optional source commit must
already be contained in `master`.

For a manual fallback, create the correctly named release branch from the
official upstream tag, open an equivalent PR into `master`, and follow the same
conflict-resolution and merge-commit process.

Do not push the plain upstream `go1.x.y` tag to this fork as an OpenHarmony
release tag. That tag identifies the unmodified upstream commit and does not
contain the OpenHarmony patches.

# OpenHarmony Go releases

OpenHarmony releases follow stable tags from the upstream
[`golang/go`](https://github.com/golang/go) repository. The upstream source tag
and the OpenHarmony distribution tag are deliberately different:

- Upstream source tag: `go1.26.5`
- OpenHarmony release tag: `go1.26.5-ohos.1`

The suffix is incremented when OpenHarmony-specific fixes are released without
changing the upstream Go version.

## Release flow

1. Fetch the new stable tag from `golang/go`.
2. Create a release branch from `origin/master`.
3. Merge the upstream tag and resolve any OpenHarmony conflicts on that branch.
4. Update `.github/release.json` with the upstream and OpenHarmony tags.
5. Open a pull request targeting `master`. The release workflow validates the
   metadata, runs the release tests, and builds both archives without
   publishing them.
6. Merge the pull request manually.

Changing `.github/release.json` on `master` starts the release workflow. The
workflow verifies that the upstream tag exists, is an ancestor of the merged
commit, and matches `VERSION`. It then repeats short standard-library tests,
targeted toolchain tests, and compile-only checks on the merged commit; builds
amd64 and arm64 archives; checks their SHA-256 files; creates an annotated tag;
and publishes the GitHub Release.

Ordinary pull requests do not change `.github/release.json` and therefore do
not publish releases. The workflow can be restarted with `workflow_dispatch`
if an external runner or GitHub service failure interrupts publishing.

Do not push the upstream `go1.x.y` tag to this fork as the OpenHarmony release
tag. That tag identifies the unmodified upstream commit and does not contain
the OpenHarmony patches.

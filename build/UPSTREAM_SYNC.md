# Scheduled upstream release synchronization

The `Sync upstream stable release` workflow periodically checks the official
Go repository for a newer stable release and prepares one pull request that
can be merged into this fork's release line.

## Release selection

- Workflow: `.github/workflows/sync-upstream.yml`
- Upstream source: stable `goX.Y.Z` tags in `golang/go`
- Excluded sources: `master`, untagged release branches, beta tags, and RC tags
- Downstream target: `Xinlong-Wu/go-ohos:master`
- Schedule: 03:17 UTC on every third calendar day of the month
- Sync branch: `sync/upstream-<upstream-tag>`, for example
  `sync/upstream-go1.27.2`

GitHub Actions cron syntax cannot express a persistent 72-hour interval across
month boundaries. The configured calendar schedule is the closest native
three-day schedule. `workflow_dispatch` is available for an immediate check.

The workflow compares `.github/release.json` with all official stable tags and
selects the numerically latest stable version. A tag is eligible only when it
is newer than the manifest's current `upstream_tag`. This repository has one
`master` release line, so maintenance releases from an older Go series are not
prepared after `master` has advanced to a newer series. Supporting multiple Go
series concurrently requires a downstream maintenance branch per series.

Only one release-integration pull request may be open at a time. A later
release is prepared only after the earlier pull request has been merged or
closed, so every release is based on the current downstream `master` state.

## Pull request and manual conflict resolution

The generated branch contains:

1. the exact upstream stable-tag commit and its history; and
2. one generated commit that prepares `.github/release.json` with
   `<upstream-tag>-ohos.1`.

The branch deliberately does not choose automatic `ours` or `theirs` conflict
resolutions. GitHub combines the upstream history with the downstream
OpenHarmony changes when the pull request is resolved and merged. Preserve the
OpenHarmony port and the generated release metadata while resolving conflicts.

After the release checks pass, merge with **Create a merge commit**. Squash and
rebase merges are not supported because the release gate verifies that the
official upstream tag is an ancestor of the merged source commit. Auto-merge
is never enabled by the synchronization workflow.

The workflow does not overwrite an existing generated branch. If a run pushed
the branch but failed before opening its pull request, a later run may reuse it
only when it is still exactly one generated metadata commit above the expected
upstream tag. Any other branch history is treated as possible manual work and
left untouched.

## Automatic publication after the manual merge

The generated `.github/release.json` change connects the synchronization PR to
`.github/workflows/publish-release.yml`:

1. On the pull request, the release workflow validates the metadata, tests the
   merged source, and builds amd64 and arm64 archives without publishing.
2. The user resolves conflicts, waits for checks, and manually creates a merge
   commit into `master`.
3. The manifest change on `master` starts the release workflow again.
4. After tests, OpenHarmony runtime coverage, and both archive builds pass, the
   workflow creates the annotated OpenHarmony tag and GitHub Release.

No automatic merge is performed. The release itself is automatic only after
the user has manually merged the prepared pull request.

## Authentication

By default the synchronization workflow uses `GITHUB_TOKEN` with
`contents: write` and `pull-requests: write`. The repository must allow GitHub
Actions to create pull requests.

GitHub suppresses `pull_request` workflow runs caused by a pull request created
with `GITHUB_TOKEN`. Configure the optional repository secret
`UPSTREAM_SYNC_TOKEN` so the release checks start immediately when the bot
opens a conflict-free pull request. Use a fine-grained token restricted to this
repository with Contents and Pull requests read/write permissions. If the user
later pushes a manual conflict-resolution commit, that human-authored update
also triggers the pull-request checks. The post-merge release run is triggered
by the user's merge into `master` and does not depend on this optional token.

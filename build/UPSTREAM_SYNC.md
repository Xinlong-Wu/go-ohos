# Scheduled upstream release synchronization

The `Sync upstream stable release` workflow periodically checks the official
Go repository for a newer stable release and prepares one release pull request
for this fork.

## Release selection and branch naming

- Workflow: `.github/workflows/sync-upstream.yml`
- Upstream source: stable `goX.Y.Z` tags in `golang/go`
- Excluded sources: `master`, untagged release branches, beta tags, and RC tags
- Downstream target: `Xinlong-Wu/go-ohos:master`
- Schedule: 03:17 UTC on every third calendar day of the month
- Release branch: `release/<upstream-tag>-ohos.1`, for example
  `release/go1.27.2-ohos.1`

GitHub Actions cron syntax cannot express a persistent 72-hour interval across
month boundaries. The configured calendar schedule is the closest native
three-day schedule. `workflow_dispatch` is available for an immediate check.

The workflow lists this fork's existing `goX.Y.Z-ohos.N` tags to determine the
latest upstream version already released. It then selects the numerically
latest official stable upstream tag. A new branch is created only when the
upstream tag is newer.

This repository has one `master` release line, so maintenance releases from an
older Go series are not prepared after `master` has advanced to a newer series.
Supporting multiple Go series concurrently requires a downstream maintenance
branch and publication workflow per series.

Only one `release/go*` pull request may be open at a time. A later release is
prepared only after the earlier PR has been merged or closed, so every release
integrates with the current downstream state.

## Manual conflict resolution

The generated branch points directly at the exact upstream stable-tag commit.
It contains no automatically chosen `ours` or `theirs` conflict resolutions
and no generated metadata file. The release version is encoded entirely in the
branch name.

Resolve conflicts while preserving the OpenHarmony port, then merge with
**Create a merge commit**. Squash and rebase merges are rejected by the release
gate because they do not preserve the official upstream tag as an ancestor of
the released source. Auto-merge is never enabled.

The workflow does not overwrite an existing release branch. If a run pushed
the upstream commit but failed before opening its PR, a later run may reuse the
branch only while it still points exactly at that commit. Any other branch tip
is treated as possible manual conflict-resolution work and left untouched.

## Automatic publication after the manual merge

`.github/workflows/publish-release.yml` recognizes source branches matching
`release/goX.Y.Z-ohos.N`:

1. It parses the upstream and OpenHarmony tags from the branch name.
2. On PR updates, it validates and builds the synthetic merge result without
   publishing.
3. On a manually merged PR, it uses the actual merge commit supplied by the
   `pull_request.closed` event.
4. After validating the merge method, `VERSION`, upstream ancestry, and
   containment in `master`, it tests and builds both architectures, creates the
   annotated tag, and publishes the GitHub Release.

There is no release-manifest conflict to resolve. The only recurring manual
actions are resolving source conflicts, reviewing the checks, and creating the
merge commit.

## Authentication

By default the synchronization workflow uses `GITHUB_TOKEN` with
`contents: write` and `pull-requests: write`. The repository must allow GitHub
Actions to create pull requests.

GitHub suppresses `pull_request` workflow runs caused by a PR created with
`GITHUB_TOKEN`. Configure the optional repository secret `UPSTREAM_SYNC_TOKEN`
so pre-merge release checks start immediately for a conflict-free PR. Use a
fine-grained token restricted to this repository with Contents and Pull
requests read/write permissions. A human-authored conflict-resolution push also
starts the checks. The merged-PR publication event is caused by the user's
manual merge and does not depend on the optional token.

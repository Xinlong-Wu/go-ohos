# Scheduled upstream synchronization

The `Sync upstream development branch` workflow periodically prepares a pull
request from the Go development branch into this fork.

## Schedule and branches

- Workflow: `.github/workflows/sync-upstream.yml`
- Upstream source: `golang/go:master`
- Downstream target: `Xinlong-Wu/go-ohos:master`
- Schedule: 03:17 UTC on every third calendar day of the month
- Sync branch: `sync/upstream-YYYY-MM-DD`, using the UTC run date

GitHub Actions cron syntax cannot express a persistent 72-hour interval across
month boundaries. The configured calendar schedule is the closest native
three-day schedule. `workflow_dispatch` is available for an immediate manual
run.

The sync branch points directly at the selected upstream commit. It is not an
automatically conflict-resolved merge commit. This allows the workflow to open
the pull request even when upstream and the OpenHarmony port modify the same
files, without silently choosing either side. Conflicts, compatibility work,
tests, and the final merge remain manual.

The workflow skips creating a pull request when:

- `master` already contains the current upstream commit;
- another sync PR already points at the same upstream commit; or
- a same-day sync PR was manually closed or merged.

A same-day rerun may update its remote branch only when the existing branch is
still an ancestor of the current upstream branch. It refuses to overwrite a
branch containing manual conflict-resolution commits. The workflow never
enables auto-merge.

## Authentication

By default the workflow uses `GITHUB_TOKEN` with `contents: write` and
`pull-requests: write`. The repository must allow GitHub Actions to create
pull requests.

Pull requests created with `GITHUB_TOKEN` do not trigger another workflow run
from their `pull_request` event. To have the normal PR checks start
automatically, configure an optional repository secret named
`UPSTREAM_SYNC_TOKEN`. Use a fine-grained token restricted to this repository
with Contents and Pull requests read/write permissions. The workflow uses
that token for checkout, branch push, and PR creation when it is present.

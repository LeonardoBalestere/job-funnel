# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues in `LeonardoBalestere/job-funnel`.

## Access

Use the session's GitHub tools when it has them. Otherwise call the GitHub REST API (`/repos/LeonardoBalestere/job-funnel/...`) through whichever authenticated client the environment provides.

Claude Code cloud sessions block GitHub's GraphQL API. There, `gh issue`, `gh pr` and `gh label` subcommands fail with HTTP 403; `gh api repos/...` is the route that works.

## Operations

| Operation | REST endpoint |
| --- | --- |
| Create an issue | `POST /issues` |
| Read an issue with its labels | `GET /issues/{number}` |
| Read an issue's comments | `GET /issues/{number}/comments` |
| List issues | `GET /issues?state=open&labels=...` (also returns PRs: keep entries without a `pull_request` key) |
| Comment on an issue | `POST /issues/{number}/comments` |
| Apply labels | `POST /issues/{number}/labels` |
| Remove a label | `DELETE /issues/{number}/labels/{name}` |
| Close | comment first, then `PATCH /issues/{number}` with `state: closed` |

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues:

- **Read a PR**: `GET /pulls/{number}`, its comments via `GET /issues/{number}/comments`, its diff via `GET /pulls/{number}` with the `application/vnd.github.diff` media type.
- **List external PRs for triage**: `GET /pulls?state=open`, keeping only `author_association` of `CONTRIBUTOR`, `FIRST_TIME_CONTRIBUTOR`, or `NONE`.
- **Comment / label / close**: the issue endpoints above, with the PR's number.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: `GET /issues/42` answers for both, and the entry is a PR when it has a `pull_request` key.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Read the issue and its comments.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (`POST /issues/{map}/sub_issues` with the child's database id). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `POST /issues/{child}/dependencies/blocked_by` and `issue_id` set to the blocker's numeric **database id** (the `id` field of `GET /issues/{n}`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children, drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: assign the issue to the driving dev (`POST /issues/{n}/assignees`), the session's first write.
- **Resolve**: comment the answer, close the issue, then append a context pointer (gist + link) to the map's Decisions-so-far.

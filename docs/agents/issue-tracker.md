# Issue tracker: GitHub

Issues and specs for this repo live as GitHub issues in `LeonardoBalestere/job-funnel`.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, external PRs run through the same labels and states as issues. A PR is external when its author is not an owner, member or collaborator of the repo.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Read the issue with its labels and comments.

## Wayfinding

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue, labelled `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Where sub-issues aren't enabled, the child sits in a task list in the map body and carries `Part of #<map>` at the top of its own body.
- **Blocking**: GitHub's native issue dependencies. Where they aren't available, a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier**: the map's open children with no open blocker and no assignee; first in map order wins.
- **Claim**: the ticket is assigned to the driving dev, as the session's first write.
- **Resolve**: the answer is posted as a comment, the issue is closed, and a context pointer (gist + link) is appended to the map's Decisions-so-far.

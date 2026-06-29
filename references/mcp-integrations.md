# MCP integrations — Jira, GitHub Issues, GitHub PRs, Linear, Slack

The plugin **does not bundle its own MCP servers**. It consumes whatever the user has connected to Claude Code. This document describes:

1. How the plugin discovers available MCPs (via `ToolSearch`).
2. How it adapts to different vendor patterns (Atlassian Jira, Linear, GitHub Issues, GitLab Issues, Slack, Teams).
3. Graceful fallback to manual ticket text when no MCP is available.

## Three integration points

### 1. Ticket source — read the ticket by ID

When the user invokes `do TKT-123` (or `do #456`), the plugin tries to fetch the full ticket text from the configured ticket source. Without an MCP, the user is asked to paste the ticket text manually.

**Detection patterns** (the plugin runs `ToolSearch` with these queries):

| Source | Search terms | Expected tool names |
|---|---|---|
| Jira (Atlassian Remote MCP) | `jira issue get` | `mcp__atlassian__getJiraIssue`, `mcp__atlassian__searchJiraIssuesUsingJql`, `mcp__jira__*`, `mcp__atlassian_remote__*` |
| Linear | `linear issue get` | `mcp__linear__get_issue`, `mcp__linear__list_issues` |
| GitHub Issues | `github issue get` | `mcp__github__get_issue`, `mcp__github__search_issues` |
| GitLab Issues | `gitlab issue get` | `mcp__gitlab__get_issue` |

If multiple match (e.g. user has Jira AND Linear), the plugin uses the one declared in `mcp_integrations.ticket_source.type` in config.yaml. If none declared, prompts once: "Encontré Jira and Linear — ¿cuál usás para este proyecto?" (saves the answer to config.yaml).

### 2. PR / branch operations — create branch, push, open PR

After Phase 2 (self-healing) finishes green and Phase 3 (PR description) is composed, the plugin can optionally **create the PR** via the configured Git host MCP. Gated behind `gates.pr_creation_gate`.

**Detection patterns:**

| Host | Search terms | Expected tool names |
|---|---|---|
| GitHub | `github create pull request` | `mcp__github__create_pull_request`, `mcp__github__create_branch` |
| GitLab | `gitlab create merge request` | `mcp__gitlab__create_merge_request` |

**Safety floor (non-configurable):**
- Branch name ALWAYS `loop/<ticket_id>` (never `main` / `master` / protected branches)
- PR is opened in DRAFT state by default (user upgrades to "ready for review" manually)
- NEVER `merge`, `squash`, or `--auto-merge`. The plugin produces; humans merge.

### 3. Notifications — Slack, Teams, etc.

Optional. After a successful run, the plugin can post a summary to a channel. Gated behind `gates.notification_gate` (defaults to `disabled`).

**Detection patterns:**

| Channel | Search terms | Expected tool names |
|---|---|---|
| Slack | `slack send message` | `mcp__slack__send_message`, `mcp__slack__post_message` |
| Microsoft Teams | `teams send message` | `mcp__teams__send_message` |
| Discord | `discord send message` | `mcp__discord__send_message` |

## How the plugin discovers MCPs at runtime

In Phase -1 (after reading `.loop/config.yaml`):

```
1. Read mcp_integrations.* sections from config.yaml.
2. For each declared integration (type != "none"):
   a. Run ToolSearch with the matching query.
   b. Cache the discovered tool names in memory as <mcp_tools>.
   c. If no tools found:
      - If integration was "required: true" in config → abort with clear message
      - Otherwise → log a warning and fall back to manual mode for that integration
3. Pass <mcp_tools> to every sub-agent that may need them (triage, adr-author, spec-writer).
```

This means: the plugin works WITHOUT any MCP (manual ticket text + WebFetch for conflict detection), works WITH whatever MCPs the user has connected, and never crashes when an MCP is offline.

## Vendor adaptation — Jira/Atlassian Remote example

Atlassian's official Remote MCP exposes:
- `mcp__atlassian__getAccessibleAtlassianResources` — list available sites + their cloud IDs
- `mcp__atlassian__getJiraIssue(cloudId, issueIdOrKey)` — fetch one issue
- `mcp__atlassian__searchJiraIssuesUsingJql(cloudId, jql)` — JQL search
- `mcp__atlassian__editJiraIssue(cloudId, issueIdOrKey, fields)` — update status / fields
- `mcp__atlassian__addCommentToJiraIssue(cloudId, issueIdOrKey, body)` — comment

**Plugin's ticket-fetch flow with Atlassian Remote:**

```
1. Call getAccessibleAtlassianResources() → cache cloudId
2. Call getJiraIssue(cloudId, "TKT-123") → returns issue with summary, description, customfields
3. Parse:
   - summary → ticket title
   - description → ticket body
   - customfield_*X* → acceptance criteria (if configured)
   - assignee → STATE Watch List owner
   - labels → archetype hints (e.g. "frontend", "ADR-needed")
4. Synthesize into a single ticket_text string the same way the user would paste it manually
```

**Status update at end of run** (gated):

```
1. After Phase 7 (STATE update), check config.mcp_integrations.ticket_source.update_status_on_complete
2. If true AND a PR was created → call editJiraIssue to set status to config.status_in_review
3. Add a comment via addCommentToJiraIssue with:
   - Run summary (executive bullets)
   - Per-agent consumption table
   - Link to PR
   - Link to ADR if created
4. Failure to update status is NOT fatal — log warning, continue
```

## Vendor adaptation — GitHub Issues + PRs example

For GitHub MCP (community implementations vary; plugin uses `ToolSearch` for resilience):

**Ticket fetch:**
- `mcp__github__get_issue(owner, repo, issue_number)` — fetch issue
- Parse title + body + labels + milestones into ticket_text

**PR creation:**
- Workers wrote code in worktrees, runtime merged to branch `loop/<ticket_id>`
- Spec-writer dev-mode composed `PR_DESCRIPTION.md`
- `mcp__github__create_pull_request(owner, repo, title, body, head, base, draft=true)`
- Returns PR URL → printed in chat resumen

**ADR conflict detection upgrade:**
- v0.3+: ADR Step 9 used raw WebFetch on `/repos/{owner}/{repo}/pulls?state=open`
- v0.6.0: prefer `mcp__github__list_pull_requests` if available (better rate limits + proper auth)
- Fallback to WebFetch if MCP not configured

## Vendor adaptation — Linear example

Linear MCP (Linear's own implementation):
- `mcp__linear__get_issue(id)` — fetch issue
- `mcp__linear__update_issue(id, fields)` — update state, labels
- `mcp__linear__create_comment(issueId, body)` — comment

Same flow as Jira: fetch on Phase -1, optional status update post-run.

## What lives in `.loop/config.yaml`

```yaml
mcp_integrations:
  ticket_source:
    type: jira | linear | github_issues | gitlab_issues | none
    cloud_id: "abc-123-..."          # Jira only — discovered automatically if blank
    project_key: "PROJ"              # for filtering and ID parsing
    required: false                  # if true: abort if MCP unavailable
    update_status_on_complete: true
    status_in_progress: "In Progress"
    status_in_review: "In Review"
    custom_field_acceptance_criteria: "customfield_10001"  # Jira-specific
    comment_template: "default"      # or path to .md template

  pr_target:
    type: github | gitlab | none
    owner: "myorg"
    repo: "myrepo"
    base_branch: "main"              # default merge target
    draft_default: true
    pr_template_path: ".github/pull_request_template.md"

  notification:
    type: slack | teams | discord | none
    channel: "#dev-loops"
    notify_on: [completed, partial, aborted]
    summary_template: "default"

gates:
  # ... existing gates ...

  ticket_status_update_gate:
    enabled: true
    on_complete: ask | proceed | proceed_with_record | skip
    # ask: AskUserQuestion confirming the status change
    # proceed: apply without asking (good with autonomy: minimal)
    # skip: never update status, just log

  pr_creation_gate:
    enabled: true
    on_ready: ask | proceed | skip
    # Note: even with proceed, PR is always opened as DRAFT
    # User must manually mark "ready for review"

  notification_gate:
    enabled: false
    on_complete: proceed | skip
```

## Preset behavior

| Preset | ticket_status_update | pr_creation | notification |
|---|---|---|---|
| `minimal` | proceed | proceed (draft PR) | proceed if enabled |
| `balanced` | ask | ask | skip (off by default) |
| `high` | ask | ask + always draft | ask before notifying |

## Hard rules (safety floor — non-negotiable)

1. **PR always DRAFT by default.** Users mark ready manually.
2. **Never `--auto-merge`, `gh pr merge`, or equivalent.**
3. **Never push to `main`, `master`, `production`, or anything matching `release/*`.**
4. **Never delete branches.** Cleanup is opt-in via post-merge hooks the user controls.
5. **Never update ticket status to "Done" automatically.** "In Review" max — humans verify.
6. **Ticket fetch failures are logged but not fatal** unless `required: true`. The user can always paste manually as fallback.

## Migration

If `.loop/config.yaml` doesn't have an `mcp_integrations` section, the plugin treats it as `type: none` for all three integrations. Manual mode = identical to v0.5.0 behavior. Zero breakage.

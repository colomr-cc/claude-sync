# claude-sync

> **Spanish version:** [README_ES.md](README_ES.md)

## Multi-Device Claude Code Synchronizer

The **work contract** that every AI session must follow, the **shared policy**, and the **orchestrator** that keeps all machines synchronized.

**Design principle:** instructions are ink (the model follows them probabilistically);
gates are cement (the program enforces them). This repo provides both layers:
the contract as versioned ink, hooks and CI as cement.

## Anatomy

| File | What it is | Who reads it | Who writes it |
|---|---|---|---|
| `CLAUDE.md` | The work contract (how I work, authorship, git, communication) | Claude Code at each session start, from the copy in `~/.claude/CLAUDE.md` | Only me, via PR |
| `settings.shared.json` | Shared policy: no attribution + sync hook. **Never** contains per-machine state (`model`, `effortLevel`) — CI prevents it | `merge_settings.py` | Only me, via PR |
| `sync.sh` | Orchestrator: runs at each session start (hook `SessionStart`). Fetches `origin/main`, keeps local `main` in sync, and materializes the contract and policy from there. Always speaks, on both channels — never dies silently | The SessionStart hook | Only me, via PR |
| `merge_settings.py` | The merge logic: the repo WINS on keys it manages, unmanaged local state is preserved. Shallow merge by design. Reads policy from history (`git show origin/main:…`) and doesn't accept paths as arguments | `sync.sh` | Only me, via PR |
| `install.sh` | Machine bootstrap: runs sync once, which materializes the contract and registers the hook. Idempotent | Me, once per machine | Only me, via PR |
| `verify-cache.sh` | Cache verification: checks that the MANDATORY block in `~/.claude/CLAUDE.md` matches its stored hash in `~/.claude/MANDATORY.cache`. Used for cache validation at session start | The SessionStart hook, model initialization | Only `sync.sh` |
| `~/.claude/MANDATORY.cache` | SHA256 hash of the MANDATORY CHECKLIST block; ensures the contract's critical rules are locked in and haven't drifted | `verify-cache.sh`, model context via prompt caching | Auto-built by `sync.sh` |
| `tests/` | Unit tests of the merge (the only real logic in the repo) | CI and pre-PR | With code that touches it |

### What rules is what's APPROVED, not what's in the folder

`~/.claude/CLAUDE.md` is a **copy managed by sync**, extracted from `origin/main`
with `git show`. It's not a symlink to the working tree, and that's why:

- It doesn't matter which branch this copy of the repo is on, or if it has uncommitted changes:
  **what governs your session is always what merged to main**. A draft in a branch
  never governs anything.
- No discipline needed ("remember to go back to main"): the machine where the
  configuration is developed behaves the same as the others.
- **Don't edit it by hand**: the next session start will overwrite it. The contract changes
  via PR.

`~/.claude/settings.json`, on the other hand, is **live state** that Claude Code writes (model,
effort level, flags). That's why it's not replaced wholesale, but merged: the repo
wins on keys it manages, and per-machine state never travels between machines.

### MANDATORY Cache: Locking the contract into every session

The MANDATORY CHECKLIST block (the three core rules) is cached at the start of each session
via Anthropic's prompt caching. Here's how it works:

1. **Build time** (`sync.sh` at SessionStart): Extract the MANDATORY block from the approved
   contract, compute its SHA256 hash, and store it in `~/.claude/MANDATORY.cache`.
2. **Verification** (optional `verify-cache.sh`): Check that the hash in the cache still
   matches the current MANDATORY block — ensures no drift between sessions.
3. **Session initialization** (model): Claude reads that the cache is active (via the Contract-Id
   line in `additionalContext`), and the three rules are available in the prompt cache,
   ensuring they're always present and consistent without re-transmitting.

**Why?** The MANDATORY rules are the cement layer — they must not be forgotten, lost,
or compromised by a stale contract. Caching ensures they're locked in, reduces latency,
and saves tokens.

**When the cache refreshes:** New SessionStart (via hook), explicit `/clear` command, or when
the CLAUDE.md contract changes on the approved branch (`origin/main`).

## Onboarding

### New machine (or existing — repo wins on what it manages)

```bash
git clone git@github.com:colomr-cc/claude-sync.git ~/dev/claude-sync
~/dev/claude-sync/install.sh
```

Done. The next Claude Code session on that machine starts with the contract
loaded and sync automatically active. If there was a prior `~/.claude/CLAUDE.md`,
it's replaced with the approved copy; unmanaged local keys in `settings.json` are preserved.

**Requirement:** the path must be `~/dev/claude-sync` (the hook references it).

### Updating the contract or policy

Never by hand in main. Standard E2E flow:

1. Feature branch → change → PR (Claude can create it; I review and merge **myself**).
2. CI validates: shellcheck, ruff, pytest, policy JSON, and zero AI attribution.
3. After merge, each machine updates itself at its next session start.

### Diagnostics

The sync **always speaks**. Important detail of the harness: the `SessionStart` event
only honors `additionalContext`, which goes to the model's context and **is not shown on screen**
(it also emits `systemMessage`, but this event ignores it). That's why rule 11 of the
contract requires Claude to reproduce that line at the start of its first response: it's the
only way the status reaches my eyes. Silence would be indistinguishable from "the
hook didn't run":

- **Success:** `✅ claude-sync · contract in effect: <commit> (<date>)`. The commit
  identifies which version rules this machine: useful when returning to equipment that hasn't
  been used in a while.
- **Contract updated:** the message adds it explicitly, with the command to see
  the diff — `git -C ~/dev/claude-sync log -p -1 origin/main -- CLAUDE.md`. No
  contract change is applied silently.
- **Problem:** `⚠️ claude-sync: ...` with the cause (no access to `origin`, missing reference,
  unreadable policy). The sync doesn't break session startup: it reports and
  continues with the last valid config.
- **No message:** the hook didn't run → check the installation on that machine.

## Quality Gate

CI on GitHub Actions (mandatory via branch protection) + SonarCloud Automatic
Analysis. Same standard as any other repo: nothing reaches main without green.

### Where Sonar configuration lives

In the **SonarCloud UI, inside the project** (`Administration → …`), not in the repo:
Automatic Analysis **ignores `sonar-project.properties` files** — those are only
read by the scanner when analysis runs from CI. Verified in practice:
with the file present, warnings kept appearing.

Current settings, all at project level (not inherited from the organization):

| Setting | Value | Where in UI |
|---|---|---|
| `sonar.python.version` | `3.12` | General Settings → Languages → Python |
| `sonar.test.inclusions` | `tests/**` | Analysis Scope → **Test** File Inclusions |

⚠️ Be careful with scope: `sonar.inclusions` (Source File Inclusions) means
"analyze **only** this" — putting `tests/**` there leaves all production code out
and the gate goes blind in green. The correct field to mark tests is
`sonar.test.inclusions`.

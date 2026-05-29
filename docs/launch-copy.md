# Launch copy — pick & post

Drafts for the announcement surfaces. Edit freely — these are starting points, not gospel.

---

## Twitter / X — single post

```
Pinned: stop your AI coder from quietly breaking the same things twice.

One command — `npx pinnedai init` — and your repo gets:

· regression guards for routes, webhooks, env, auth
· AI-coder rules that Claude / Cursor / Copilot read before edits
· a pre-commit hook that blocks `.skip()` bypass attempts

Free beta. https://pinnedai.dev
```

## Twitter / X — thread version (5 tweets)

```
1/ AI coders are fast. They also re-introduce bugs you already fixed —
   silently, in a PR you're tired of reviewing.

   Pinned makes those bugs permanent CI tests. Once a guard exists,
   future AI edits can't quietly weaken it.

   `npx pinnedai init` →  pinnedai.dev

2/ The core idea: when an AI coder fixes a bug, Pinned writes a test
   that catches the bug. The test lives in tests/pinned/ and joins
   your suite forever.

   Six months later, when a different AI edit breaks the same
   behavior, the test fails. With a back-reference to the original PR.

3/ Pre-commit hook also blocks the obvious bypass attempts:

   · `.skip()` / `.only()` / `xit()`
   · weakened assertions (toBe(401) → toBeTruthy())
   · deleted pinned tests without a retire-with-audit flow

   AI tries it. Pinned says no. Application code gets fixed instead.

4/ Works with every major AI-coder surface:

   · Claude Code (statusline + chat hook)
   · Cursor / Windsurf / Copilot Chat (status bar + rules file)
   · MCP server for Claude Desktop / Cline / Continue

5/ Free beta. No API keys, no signup, no cloud.

   github.com/pinnedai/pinnedai
   pinnedai.dev
   npm i -g pinnedai
```

---

## Show HN — title

```
Show HN: Pinned – turn your AI coder's bug fixes into permanent regression tests
```

## Show HN — body

```
Hi HN! I built Pinned because I kept watching my AI coder re-introduce
bugs I'd already fixed.

The loop was: file a bug, AI fixes it, I merge. Two weeks later AI
makes an unrelated change that quietly reverts the fix. Code review
doesn't catch it because the diff looks fine.

Pinned solves this by turning each fix into a permanent test that
lives in your repo. The test guards the SPECIFIC behavior the fix
restored. Future AI edits that break it fail CI with a back-reference
to the original PR.

What `npx pinnedai init` does in 30 seconds:

  1. Scans your repo for risk surfaces (auth, webhooks, routes,
     env files, client fetch patterns, lockfile drift) and generates
     baseline guards as Vitest files in tests/pinned/.
  2. Installs a pre-commit hook that blocks .skip() / .only() /
     weakened-assertion / deleted-test bypass attempts. (We tested
     this against 17 known AI bypass tactics — 17/17 blocked.)
  3. Writes AI-coder rules to CLAUDE.md and
     .github/copilot-instructions.md so Claude / Cursor / Copilot
     read them before editing.
  4. Generates .github/workflows/pinned.yml so CI also enforces
     guard integrity (catches the case where someone runs
     `git commit --no-verify` to bypass the local hook).

Five-step value loop:
  init → guard → AI lesson learned → siblings audited →
  future edits checked.

What makes it different from a code-review bot:
  · The output of every finding is an executable test, not a
    PR comment.
  · The test stays in YOUR repo. Cancelling Pinned means losing
    nothing.
  · It runs in your existing CI. No cloud, no API key needed
    on the Free tier.

Stack: TypeScript CLI on npm, Vite + React landing, optional MCP
server (pinnedai-mcp) for Claude Desktop / Cursor / Cline / Continue.

Apache 2.0. Free beta.

  · pinnedai.dev
  · github.com/pinnedai/pinnedai
  · npm: pinnedai, pinnedai-mcp

Feedback welcome — especially counterexamples where a guard SHOULD
have fired and didn't, or false-positive cases where a guard fires
on benign edits.
```

---

## r/devsecops — title + body

```
[Show & Tell] Pinned — pre-commit + CI hook that blocks AI from
deleting or weakening tests
```

```
Built this after noticing my AI coder (Claude / Cursor) would
sometimes "fix" a failing test by adding .skip() or replacing
toBe(401) with toBeTruthy(). Code review didn't always catch it.

Pinned is a pre-commit hook + CI step that explicitly looks for
test-weakening attempts in pinned regression tests and blocks
them at commit time. Bypass tactics it currently catches:

  · .skip / .skipIf(true) / xit / xdescribe / .todo
  · weakened assertions (toBe(X) → toBeTruthy() / .anything)
  · `expect(true).toBe(true)` tautologies
  · early `return` in test body
  · commented-out `expect()` calls
  · expect.assertions(0)
  · pin-file deletion without retire-with-audit flow
  · pin-file move-to-retired/ without the matching .audit.json

CI side catches the `git commit --no-verify` bypass by re-running
the same check against origin/<base>...HEAD on every PR.

The pinned regression tests themselves are auto-generated from
fix commits + PR descriptions. Each guards a specific behavior.

Apache 2.0. Works alongside your existing test suite (Vitest).
No API key needed for the free tier.

  · pinnedai.dev
  · github.com/pinnedai/pinnedai
  · npm install -g pinnedai

Feedback welcome.
```

---

## LinkedIn — single post

```
Just shipped: Pinned (pinnedai.dev).

The problem I kept hitting: AI coders fix a bug, then two weeks
later silently re-introduce it. Code review misses it because
the diff looks fine. The bug returns. Trust in the AI erodes.

Pinned turns each fix into a permanent regression test that
guards the SPECIFIC behavior. Future AI edits that break it
fail CI with a back-reference to the original PR.

Works across every major AI-coder surface — Claude Code, Cursor,
Windsurf, GitHub Copilot Chat, and via the pinnedai-mcp Model
Context Protocol server for Claude Desktop / Cline / Continue.

`npx pinnedai init`. Free beta. Apache 2.0.

Built solo with AI tooling. Feedback welcome from anyone shipping
production code with AI coders — would love to hear what you'd
want it to catch.
```

---

## Notes on posting order

1. **Show HN first** — single post, single audience, gives you concentrated feedback signal.
2. **r/devsecops second** — security crowd will dig into the bypass-blocking angle.
3. **Twitter thread + LinkedIn third** — once you have one or two real users to quote.
4. **r/javascript** — only if you've got something specific to add. Generic launches don't perform there.

---

## What to NOT say in marketing

(per the locked memos)

- ❌ "Lifetime unlimited" — not a promise we can keep
- ❌ "AI catches AI's mistakes" — sounds vague and oversold
- ❌ Specific catch-count claims for in-the-wild bug-fix detection (we don't have walk-forward proof yet, only mutation-test 17/17 and replay-15)
- ❌ Anything that implies a hosted service exists (Worker is private / future)

What's safe:
- ✅ "Stops AI from weakening the safety net" — actually demonstrated
- ✅ "17/17 known AI bypass tactics blocked" — verified
- ✅ "Free beta · BYOK · local-first" — accurate
- ✅ "Pre-commit + CI enforcement" — actually wired

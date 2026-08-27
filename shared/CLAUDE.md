# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

**Language:** Match the user's language. If they write in pt-BR, reply in pt-BR; if they write in English, reply in English.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

**Comments: only when the code can't speak for itself.**

- Don't comment line by line — most comments just restate the code.
- Prefer a better name: extract a well-named variable or function instead of explaining with a comment.
- Comment only when the *why* isn't visible in the code (non-obvious rationale, tradeoff, gotcha).

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

## 5. Consolidation Pass

**Before calling a feature done, re-read the whole diff cold — as if reviewing someone else's PR.**

Work built up across several steps accumulates cruft the incremental view hides. The final pass catches what a senior reviewer would otherwise flag:
- A redundancy or smell you *noticed* gets removed now — "harmless" is never a reason to keep dead code.
- When an assumption changed mid-build (e.g. N=2 → N=many), revisit the helpers/types/abstractions built under the old assumption; they're often now redundant or single-use.
- If you had to add a special-case to make new code work, treat it as a red flag that you're colliding with something existing — question it instead of patching around it.
- Reuse the helpers you just introduced everywhere they apply, including pre-existing duplicates right next to them.

The bar: would the maintainer have to clean this up before merging? If yes, do it first.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

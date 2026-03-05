---
name: review-branch
description: Deep review of all changes on the current branch using scaled finder agents with deduplication, falsification, and intent verification.
---

# Branch Review with Falsification

> **Cost guidance**: Small diffs → 3 finders + 1 intent = 4 agents. Medium → 5 + 1 = 6. Large → 7 + 1 = 8. Plus 1 falsification agent per unique finding. For trivial changes (< 50 lines, 1–2 files), skip this skill and review manually.

Three phases:
1. **Prepare**: Generate diff, detect stack, size the review, spawn intent verification.
2. **Find**: Scaled finder agents (3/5/7) each own a category and approach. Deduplicate findings by structured keys.
3. **Falsify**: One agent per unique finding tries to disprove it. Only survivors make the final report.

---

## Step 1: Generate the diff and detect context

### 1a. Detect the default branch and generate the diff

```bash
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@') || DEFAULT_BRANCH="main"
git fetch origin "$DEFAULT_BRANCH"
DIFF_FILE=$(mktemp /tmp/branch-review-XXXXXXXX)
git diff $(git merge-base HEAD "origin/$DEFAULT_BRANCH")..HEAD > "$DIFF_FILE"
git diff --stat $(git merge-base HEAD "origin/$DEFAULT_BRANCH")..HEAD
```

Save `$DIFF_FILE` path — pass it to every agent prompt.

### 1b. Detect the stack

Check for framework/language markers in the repo root:

| File | Stack |
|---|---|
| `Gemfile` | Ruby / Rails |
| `package.json` | JavaScript / TypeScript (check for React, Next, Express, etc.) |
| `go.mod` | Go |
| `requirements.txt` / `pyproject.toml` | Python (check for Django, FastAPI, Flask, etc.) |
| `Cargo.toml` | Rust |
| `pom.xml` / `build.gradle` | Java / Kotlin |
| `mix.exs` | Elixir / Phoenix |

Note the detected stack. Reference it when writing agent prompts so they use the correct framework terminology.

### 1c. Read the diff and write a branch summary

Read the full diff. Write a short summary (5–10 sentences) covering:
- What the branch does (feature, bugfix, refactor, etc.)
- Which areas of the codebase it touches
- The apparent intent and scope
- Key files changed

This summary is injected into every agent prompt as `## Branch Context`.

### 1d. Size the review

Count lines changed and files touched from `git diff --stat`.

| Tier | Lines changed | Files touched | Finder agents |
|---|---|---|---|
| **Small** | < 200 | ≤ 3 | 3 |
| **Medium** | 200–1000 | 4–15 | 5 |
| **Large** | > 1000 | > 15 | 7 |

Use the higher tier if either threshold is met.

---

## Step 2: Intent verification + choose categories

Run these in parallel:

### 2a. Spawn intent verification agent

Spawn one agent using the Agent tool with `subagent_type: "general-purpose"` and `run_in_background: true`:

```
You are verifying that a code branch achieves its intended purpose.

## Branch Context
[INSERT BRANCH SUMMARY FROM STEP 1c]

## Diff file
[INSERT DIFF_FILE PATH]

## Detected stack
[INSERT STACK FROM STEP 1b]

Instructions:
1. Read the full diff at the path above
2. Read the actual source files that were changed
3. Infer what this branch is trying to accomplish
4. Evaluate:
   - Does the code actually achieve the stated/inferred goal?
   - Are there gaps where the intent is clear but the implementation is incomplete?
   - Are there missing edge cases for the happy path?
   - Are there obvious omissions (e.g., added a new field but didn't update the serializer, added a route but no handler)?
5. Produce a report with:
   - **Inferred intent**: 1–2 sentence summary of what the branch is trying to do
   - **Completeness**: Does the implementation fully cover the intent? List any gaps.
   - **Happy path gaps**: Edge cases on the main flow that aren't handled
   - **Omissions**: Things that are clearly missing given the intent

If the implementation looks complete and correct, say so explicitly. Do not invent issues.
```

### 2b. Choose categories and assign approaches

Pick categories based on what the diff touches. Choose the number determined by the tier in Step 1d.

Default category pool (adapt terminology to the detected stack):

1. **Security & Authorization** — authn/authz gaps, privilege escalation, injection, input validation
2. **Data Integrity & Race Conditions** — state inconsistencies, ordering issues, race conditions, orphaned data
3. **Business Logic Correctness** — semantic bugs, incorrect branching, missing edge cases, behavioral regressions
4. **Backward Compatibility & Migration Safety** — breaking changes, removed interfaces with remaining callers, migration locking, deploy ordering
5. **Performance** — N+1 queries, missing caching/memoization, unnecessary work, hot path regressions
6. **Error Handling & Resilience** — uncaught exceptions, missing retries, partial failure states, silent swallowing
7. **API Contract & Type Safety** — response shape changes, missing validations on boundaries, type mismatches, schema drift

For frontend-heavy diffs, swap in: Accessibility, State Management, Rendering Performance, etc.

Alternate approaches across agents to maximize coverage diversity:
- **Odd-numbered agents** (1st, 3rd, 5th, 7th) use the **top-down** approach
- **Even-numbered agents** (2nd, 4th, 6th) use the **bottom-up** approach

### 2c. Assign files to categories

For each category, list the files from the diff that are relevant to it. A file can appear in multiple categories. Include the file paths in each category's agent prompts as `## Relevant Files`.

---

## Step 3: Spawn finder agents

Spawn all finder agents in a single message using the Agent tool with `subagent_type: "general-purpose"` and `run_in_background: true`.

Each agent gets one category and one approach (top-down or bottom-up, as assigned in Step 2b).

### Top-down finder prompt

```
You are reviewing a code branch. Your focus area is: [CATEGORY NAME].

[CATEGORY DESCRIPTION]

## Branch Context
[INSERT BRANCH SUMMARY FROM STEP 1c]

## Detected stack
[INSERT STACK FROM STEP 1b]

## Diff file
[INSERT DIFF_FILE PATH]

## Relevant Files
[LIST OF FILES ASSIGNED TO THIS CATEGORY]

## Your approach: Top-down
Start from entry points (routes, API endpoints, event handlers, CLI commands, public methods) and trace FORWARD through the changed code. Follow the execution path and find where things break.

Instructions:
1. Read the full diff at the path above
2. Start with the relevant files listed above. You may read other files for context, but focus your review here.
3. For each potential issue in your focus area, read the ACTUAL source files (not just the diff) to verify it
4. For each finding, you MUST provide:
   - A structured key in the format: `file_path:start_line-end_line:issue_type`
     Issue types: auth_bypass, race_condition, data_loss, null_reference, missing_validation, n_plus_one, breaking_change, logic_error, perf_regression, other
   - A concrete trigger path:
     - Name the entry point
     - Trace the execution order (middleware, hooks, call chain — use the correct terms for the detected stack)
     - Identify the exact state/preconditions required to reach the buggy code
     - If you cannot construct a concrete trigger path, do NOT report it
5. Produce a numbered list of findings. Each finding must have ALL of these fields:
   - Key: structured key (file_path:line_range:issue_type)
   - File: path and line numbers
   - Severity: Critical / High / Medium / Low
   - Trigger: the concrete step-by-step sequence that causes the bug
   - Description: what is wrong and what is the impact
   - Fix: recommended fix
6. Also list things you investigated and confirmed are NOT bugs (with brief explanation why they are safe)

IMPORTANT: Do NOT report theoretical issues. If you cannot describe a concrete, reachable trigger path, it is not an issue.
```

### Bottom-up finder prompt

```
You are reviewing a code branch. Your focus area is: [CATEGORY NAME].

[CATEGORY DESCRIPTION]

## Branch Context
[INSERT BRANCH SUMMARY FROM STEP 1c]

## Detected stack
[INSERT STACK FROM STEP 1b]

## Diff file
[INSERT DIFF_FILE PATH]

## Relevant Files
[LIST OF FILES ASSIGNED TO THIS CATEGORY]

## Your approach: Bottom-up
Start from data mutations, state changes, and side effects in the changed code. Trace BACKWARD to find what callers or preconditions could lead to bad state. Focus on: What does this code write/mutate/delete? Who calls it? Under what conditions? Can those conditions create problems?

Instructions:
1. Read the full diff at the path above
2. Start with the relevant files listed above. You may read other files for context, but focus your review here.
3. Identify all state mutations in the changed code (DB writes, variable assignments, cache updates, file writes, API calls with side effects)
4. For each mutation, trace backward: who calls this? What preconditions exist? Can the caller reach this code with state that causes problems?
5. For each finding, you MUST provide:
   - A structured key in the format: `file_path:start_line-end_line:issue_type`
     Issue types: auth_bypass, race_condition, data_loss, null_reference, missing_validation, n_plus_one, breaking_change, logic_error, perf_regression, other
   - A concrete trigger path (same requirements as above)
6. Produce a numbered list of findings. Each finding must have ALL of these fields:
   - Key: structured key (file_path:line_range:issue_type)
   - File: path and line numbers
   - Severity: Critical / High / Medium / Low
   - Trigger: the concrete step-by-step sequence that causes the bug
   - Description: what is wrong and what is the impact
   - Fix: recommended fix
7. Also list things you investigated and confirmed are NOT bugs (with brief explanation why they are safe)

IMPORTANT: Do NOT report theoretical issues. If you cannot describe a concrete, reachable trigger path, it is not an issue.
```

---

## Step 4: Collect and deduplicate findings

Wait for all finder agents and the intent verification agent to complete.

### Deduplication

Collect all findings from all agents. Deduplicate using structured keys:

1. **Exact match**: Same file, overlapping line range, same issue_type → merge into one finding, keep the most detailed trigger path
2. **Partial match**: Same file, overlapping line range, different issue_type → review manually; merge if same root cause
3. **Semantic match** (for `other` type only): Same file region + same root cause described differently → merge

After deduplication, you have the unique findings list. All of these go to falsification.

---

## Step 5: Falsification round

For each unique finding from Step 4, spawn exactly one falsification agent. **Spawn all falsification agents in parallel** using `run_in_background: true`.

Use the Agent tool with `subagent_type: "general-purpose"`.

### Falsification prompt

```
You are a falsification agent. Your job is to DISPROVE the following finding from a code review. You succeed if you can show the issue is not real.

## Branch Context
[INSERT BRANCH SUMMARY FROM STEP 1c]

## Detected stack
[INSERT STACK FROM STEP 1b]

Finding: [TITLE]
Key: [STRUCTURED KEY]
Claimed trigger: [TRIGGER PATH — copy from the finder agent's output]
Files: [FILE PATHS AND LINE NUMBERS]
Description: [DESCRIPTION — copy from the finder agent's output]

## Diff file
[INSERT DIFF_FILE PATH]

Instructions:
1. Read the full diff at the path above
2. Read ALL relevant source files end-to-end (not just the lines mentioned)
3. Trace the exact execution path from entry point to the alleged bug:
   - What is the entry point?
   - What middleware, hooks, or guards run first? In what order? Read the source files to check.
   - What state exists at each step? Has the problematic precondition actually been set?
   - Is the precondition for this bug actually reachable given the execution order?
4. Check for existing guards: validations, uniqueness checks, scope filters, early returns, error handling
5. Check callers: does any code actually invoke the problematic path with the problematic state?
6. Check if the claimed trigger path is actually possible end-to-end
7. Check test coverage: search for test files that exercise the entry point and the specific conditions described in the trigger path. Note whether existing tests cover this scenario.

You MUST pick exactly one verdict:

DISPROVED — The issue cannot occur. State the specific reason: name the guard, the execution order, or the condition that prevents it.

CONFIRMED — You tried to disprove it and failed. The trigger path is valid. No existing code prevents it.

DOWNGRADED — The issue is technically possible but requires an extremely narrow edge case that is not worth fixing. Describe the edge case.

You MUST also provide:
test_coverage: covered | not_covered | partial
(Whether existing tests exercise the trigger path described in this finding.)
```

### How to apply falsification verdicts

- **DISPROVED** → Remove from the final report.
- **CONFIRMED** → Include in the final report.
- **DOWNGRADED** → Move to "Track as tech debt" unless the original severity was Critical or High, in which case keep it in the report with a note.

---

## Step 6: Compile the final report

### Correctness Assessment

Include the intent verification agent's output from Step 2a:
- **Inferred intent**: What the branch is trying to do
- **Completeness**: Whether the implementation fully covers the intent
- **Gaps**: Any missing pieces or happy-path edge cases

### Confirmed Issues (survived falsification)

Group by severity (Critical → High → Medium → Low). For each issue include:
- **Title** — short description
- **Key** — structured key (file_path:line_range:issue_type)
- **Falsification verdict** — CONFIRMED
- **Test coverage** — covered / not_covered / partial
- **Files** — paths and line numbers
- **Trigger path** — concrete steps to reproduce
- **Description** — what's wrong and why
- **Fix** — recommended fix

### Disproved Findings

List every finding that was disproved in the falsification round. For each:
- **Title** — what was claimed
- **Why it was disproved** — the specific guard or condition that prevents it

This section helps calibrate the review process over time.

### Priority Recommendations

- **Fix before merge** — real bugs with confirmed trigger paths and no test coverage
- **Fix before deploy** — issues that need verification or coordination
- **Fix soon after** — performance issues, confirmed but low-impact, or issues with existing test coverage
- **Track as tech debt** — downgraded findings, low-severity, cosmetic

---

## Notes

- The diff file path is generated by `mktemp` and is unique per review. Clean it up after the review completes.
- For very large diffs (> 5000 lines), consider splitting into sub-diffs by directory and assigning agents to specific areas.
- Agents should read actual source files, not just the diff. The diff shows what changed; the source files show the full context needed to determine if something is actually broken.
- The base branch is auto-detected from `origin/HEAD`. If detection fails, it defaults to `main`.

---
name: review-skill
description: Review a SKILL.md file for quality, correctness, and adherence to best practices. Use when evaluating or improving a Claude Code skill.
argument-hint: [path-to-skill-directory]
---

# Skill Review

Review a SKILL.md file and produce an actionable report on its effectiveness.

If `$ARGUMENTS` is provided, review the skill at that path. If it's a directory, look for `SKILL.md` inside it. Otherwise, ask which skill to review.

## Step 1: Load the skill

Read the SKILL.md file and all other files in the skill directory. Note the total line count of SKILL.md. If the file doesn't exist or has no valid YAML frontmatter, report that and stop.

## Step 2: Simulate execution

This is the most important step. Walk through the skill as if you were Claude executing it for the first time.

For each step in the skill:
1. **What would Claude do here?** Trace the exact actions. If the instruction is ambiguous, note where Claude could go off-rails.
2. **Does this step have enough context?** Check whether information from earlier steps that this step depends on is explicitly passed forward or left implicit.
3. **What could go wrong?** For each shell command, trace what it does and verify it produces the output the skill assumes. For each agent prompt (if any), check whether the agent receives enough context to do its job without re-deriving information.
4. **What's missing between steps?** Identify gaps where the skill assumes Claude will infer a connection that isn't stated.

Note every ambiguity, missing handoff, incorrect command, or point where Claude would have to guess.

## Step 3: Evaluate token efficiency

Go through the body paragraph by paragraph. For each one, answer: "What does this add that Claude doesn't already know?" Flag paragraphs that:
- Explain concepts Claude already understands (e.g., explaining what a REST API is)
- Restate the same instruction in different words
- Add caveats or edge cases that are vanishingly unlikely

## Step 4: Evaluate freedom calibration

For each instruction in the skill, classify it:
- **Rigid** (exact command, exact format, no deviation): Appropriate when the operation is fragile or the output must match a specific schema.
- **Guided** (approach specified, details flexible): Appropriate for most instructions.
- **Open** (goal stated, method left to Claude): Appropriate for creative or context-dependent tasks.

Flag mismatches: rigid instructions on flexible tasks (overconstraining), or open instructions on fragile tasks (underconstraining).

## Step 5: Check correctness

For each shell command in the skill:
- Trace what it does step by step. Verify the output matches what the skill assumes.
- Check platform compatibility — does the skill state its platform requirements?
- Check for hardcoded paths, missing error handling on commands that can fail, and pipe chains where an early failure would silently produce wrong output.

For each agent prompt (if the skill spawns agents):
- Does the agent receive the diff/file/context it needs, or does it have to re-read everything?
- Are structured output requirements clear enough that you could parse the agent's response programmatically?
- Could two agents produce findings in incompatible formats?

## Step 6: Produce the report

```
## Skill Review: <name>

### Summary
<1-2 sentence overall assessment focused on whether the skill will work effectively at runtime>

### Simulation Findings
<Walk through the execution and describe what happens at each step. Call out:>
- Steps where Claude would be confused or guess wrong
- Missing context handoffs between steps
- Commands that don't do what the skill assumes
- Agent prompts that lack sufficient context

### Token Efficiency
<List paragraphs/sections that should be cut or condensed, with reasoning>

### Freedom Calibration
<List any mismatches between instruction rigidity and task flexibility>

### Correctness Issues
<Numbered list of concrete bugs:>
1. **<location>**: <what's wrong> → <fix>

### Suggestions
<Optional improvements>
```

Do NOT make changes to the skill. Only report findings.

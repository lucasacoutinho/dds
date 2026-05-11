---
name: excavate
description: Phase 2 of DDS reverse-engineering. Performs deep, line-by-line excavation of a single module (or all modules) from a legacy codebase, extracting business rules, SQL queries, integrations, and dead code, with mandatory file:line citations and LLM-as-Judge fidelity verification on every claim.
argument-hint: Module name from survey, or --all. Optional flags such as --target-fidelity 4.0 --sample-rate 0.1
---

# DDS Phase 2: Module Excavation

## Role

You are an excavation orchestrator. For each requested module you dispatch a fleet of specialized sub-agents in coordinated phases, each grounding their findings in file:line citations, and then dispatch the fidelity-judge sub-agent to verify those citations against actual source code.

## Goal

For each excavated module produce:

- `spec/modules/<module-name>.md` — the module deep-dive, with every claim cited
- Appends to global registries:
  - `spec/business-rules.md`
  - `spec/sql-inventory.md`
  - `spec/data-dictionary.md`
  - `spec/integrations.md`
  - `spec/dead-code.md`
- Update `spec/.dds-state.json` marking the module as `excavated` with its fidelity score

## User Input

```text
$ARGUMENTS
```

## Command Arguments

| Argument | Format | Default | Description |
|---|---|---|---|
| `<module-name>` or `--all` | Module identifier | **Required** | Module to excavate (matching name from survey) or `--all` for every surveyed module |
| `--target-fidelity` | `--target-fidelity X.X` | `4.0` | Fidelity-judge pass threshold (out of 5.0) |
| `--max-iterations` | `--max-iterations N` | `3` | Max excavate+judge retries per module |
| `--sample-rate` | `--sample-rate F` | `0.10` | Fraction of citations the fidelity-judge verifies |
| `--continue` | `--continue` | None | Resume from last in-progress module (uses `spec/.dds-state.json`) |
| `--skip-judges` | `--skip-judges` | `false` | Skip fidelity verification entirely (NOT recommended) |
| `--human-in-the-loop` | `--human-in-the-loop` | `false` | Pause after each module for review |

Parse `$ARGUMENTS`:

```
TARGET = first positional argument (module-name) or --all flag (required)
TARGET_FIDELITY = --target-fidelity value, default 4.0
MAX_ITERATIONS = --max-iterations value, default 3
SAMPLE_RATE = --sample-rate value, default 0.10
SKIP_JUDGES = --skip-judges flag, default false
HUMAN_IN_THE_LOOP = --human-in-the-loop flag, default false
CONTINUE = --continue flag, default false
```

## Pre-Flight Checks

1. **Survey must exist**: Verify `spec/00-survey.md` exists. If not, instruct user to run `/dds:survey` first and exit.

2. **Resolve module list**:
   - If `TARGET == --all`: read `spec/.dds-state.json`, take every module with status `surveyed`. If `--continue`, include also `excavating` modules.
   - Otherwise: validate `TARGET` exists in the state manifest.

3. **Folder setup**:

   ```bash
   bash <plugin-root>/scripts/create-spec-folders.sh
   ```

4. Track progress internally with one set of phases per module:
   - dispatch module-excavator
   - dispatch data-archaeologist, integration-mapper, business-rule-extractor, dead-code-detector (in parallel)
   - dispatch fidelity-judge
   - update state manifest

## CRITICAL Rules

- **Cite or fail**: Every claim about behavior in `spec/modules/<name>.md` MUST cite a source file:line. Uncited claims cause automatic fidelity-judge failure.
- **One excavation per module**: Do not interleave modules. Finish all sub-phases + judge for one module before starting the next.
- **Foreground sub-agents only**: Run the four specialist sub-agents (data/integration/rules/dead-code) **in parallel** after the module-excavator returns — dispatch them in a single batch.
- **Judge retries**: If fidelity-judge returns FAIL, re-dispatch module-excavator with the judge's feedback. Up to MAX_ITERATIONS.
- **Judge 5.0 = hallucination**: Reject and re-dispatch.
- **DO NOT** read the legacy source files yourself — your job is to orchestrate, not excavate.

## Workflow Per Module

For each module M:

### Step 1: Dispatch the Module Excavator

Dispatch a sub-agent using the `dds:module-excavator` agent definition. This one benefits from a model that's strong at thorough reading and structured output:

```text
Plugin root: <plugin-root>

Module Name: <M>
Module Path: <path from survey, e.g., src/Billing/>
Survey File: spec/00-survey.md

Your job is to produce spec/modules/<M>.md by reading every non-trivial source
file in the module path line by line. NO skimming. NO summaries from filenames.
Read the actual code.

Output structure for spec/modules/<M>.md:

# Module: <M>

## Purpose
<one paragraph, cited>

## Files
<table: file | role | LOC | citation>

## Public API
<every public function/class with signature and citation>

## Internal Flow
<key flows with sequence-diagram-style steps, each step cited>

## Dependencies
<other modules, external libs, with citation of import statement>

## Data Access
<table: query/orm-call | purpose | citation>

## Side Effects
<file I/O, network calls, env access, with citations>

## Open Questions
<things unclear that need human follow-up>

CRITICAL:
- Use scratchpad: bash <plugin-root>/scripts/create-scratchpad.sh
- Dump raw findings to scratchpad first; only synthesize verified claims into spec.
- EVERY sentence describing behavior MUST end with [file:line] or [file:start-end].
- DO NOT output findings inline in your response.
```

**Capture**: scratchpad path, file count read, claim count, citation count.

### Step 2: Dispatch Four Parallel Specialist Sub-Agents

After module-excavator completes, dispatch these four in parallel (single batch):

**2a. Data archaeology** — `dds:data-archaeologist`:

```text
Plugin root: <plugin-root>
Module: <M>
Module Path: <path>
Module Spec: spec/modules/<M>.md

Extract every database interaction in this module:
- Inline SQL strings
- Stored procedure calls
- ORM/EF/Hibernate/ActiveRecord mappings
- Migration files referenced

Append findings to:
- spec/sql-inventory.md (every query with purpose + citation)
- spec/data-dictionary.md (every table/column referenced)

CRITICAL: cite file:line for every query.
Use scratchpad first (<plugin-root>/scripts/create-scratchpad.sh).
```

Recommend a model with strong SQL/database comprehension — this is the heaviest analytical sub-agent.

**2b. Integration mapping** — `dds:integration-mapper`:

```text
Plugin root: <plugin-root>
Module: <M>
Module Path: <path>
Module Spec: spec/modules/<M>.md

Find every external boundary crossed by this module:
- HTTP/REST/SOAP/gRPC calls outbound
- HTTP routes served inbound
- Message queue producers/consumers
- File system reads/writes
- Scheduled jobs / cron triggers
- FFI / shell-out / process spawn

Append to spec/integrations.md.
CRITICAL: cite file:line. Use scratchpad first.
```

**2c. Business rule extraction** — `dds:business-rule-extractor`:

```text
Plugin root: <plugin-root>
Module: <M>
Module Path: <path>
Module Spec: spec/modules/<M>.md

Extract every business rule embedded in code:
- Validations (input checks, regex, length, range)
- Calculations (pricing, tax, discount, prorate)
- Workflows (state transitions, multi-step branches)
- Authorization rules (who can do what when)

For each rule, write:
- Rule statement (plain English)
- Citation (file:line)
- Conflicts (if same rule exists elsewhere — e.g., client-side JS and server-side, OR code and stored proc)

Append to spec/business-rules.md grouped by module.
CRITICAL: every rule MUST cite source. Use scratchpad first.
```

Recommend a model with strong reasoning — this is where domain knowledge matters most.

**2d. Dead-code detection** — `dds:dead-code-detector`:

```text
Plugin root: <plugin-root>
Module: <M>
Module Path: <path>

Find code that appears unused:
- Public functions never called within or outside module
- Files not imported anywhere
- Commented-out code blocks (> 5 lines)
- Config blocks with no consumer

Mark every finding as "orphaned (verify)" not "dead" — reflection
and dynamic dispatch can cause false positives.

Append to spec/dead-code.md.
CRITICAL: cite file:line. Use scratchpad first.
```

A lighter model suffices here — the work is mostly pattern-matching, not reasoning.

### Step 3: Dispatch the Fidelity Judge

If SKIP_JUDGES is false, dispatch a sub-agent using `dds:fidelity-judge`:

```text
Plugin root: <plugin-root>

Read <plugin-root>/prompts/fidelity-judge.md for evaluation methodology.

Module spec path: spec/modules/<M>.md
Source root: <module-path>
Sample rate: <SAMPLE_RATE>
Threshold: <TARGET_FIDELITY>

Verify citations as instructed.
```

The fidelity-judge must use a capable model — it is doing the most precise reasoning in the entire pipeline (verifying that prose claims literally match code lines).

**Decision logic**:
- PASS (score >= TARGET_FIDELITY, no HALLUCINATION, < 3 uncited): mark module as `excavated` in `spec/.dds-state.json`.
- FAIL: re-dispatch module-excavator with the judge's feedback. Up to MAX_ITERATIONS.
- After MAX_ITERATIONS: mark as `excavated_with_warnings` and continue to next module. Log the warning prominently.

### Step 4: Update State Manifest

After each module completes, update `spec/.dds-state.json`:

```json
{
  "modules": {
    "<M>": "excavated"
  },
  "last_phase": "excavate",
  "fidelity_scores": {
    "<M>": <score>
  }
}
```

### Step 5: Optional Human Checkpoint

If HUMAN_IN_THE_LOOP is true, after each module pause and show:

```markdown
## Module <M> Excavation Complete

| Metric | Value |
|---|---|
| Files read | <N> |
| Claims | <N> |
| Citations | <N> |
| Fidelity score | <X.X>/<TARGET_FIDELITY> |
| Status | <PASS / WARN> |
| Spec | spec/modules/<M>.md |

Continue to next module? [Y/n/feedback]
```

## Completion Summary

After all modules processed:

```markdown
## Excavation Complete

| Module | Files | Citations | Fidelity | Status |
|---|---|---|---|---|
| billing | 47 | 312 | 4.4 | ✅ |
| auth | 12 | 89 | 4.1 | ✅ |
| reports | 213 | 1041 | 3.2 | ⚠️ WARN |

### Next Steps

Run `/dds:assemble` to synthesize per-module specs into the unified Arc42 spec tree.
```

## Constraints

- **NEVER** modify legacy source files.
- **NEVER** mark a module as `excavated` if fidelity-judge FAILed and MAX_ITERATIONS not yet reached — retry.
- **NEVER** read the legacy code yourself — delegate to sub-agents.
- **DO** check that every spec/modules/<M>.md file exists after the excavator returns; if missing, re-dispatch with the same prompt.

## Platform Notes

This skill was designed for Claude Code's slash-command + sub-agent model but uses platform-agnostic language. The `<plugin-root>` placeholder corresponds to your platform's plugin-directory variable (in Claude Code: `${CLAUDE_PLUGIN_ROOT}`). "Dispatch a sub-agent" maps to whatever sub-agent mechanism your host platform provides.

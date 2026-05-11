---
name: survey
description: Phase 1 of DDS reverse-engineering. Performs lightweight reconnaissance of a legacy codebase to detect the tech stack, enumerate entry points, build a module map, and estimate the cost of full excavation. Output is spec/00-survey.md.
argument-hint: Optional path to the codebase root (default ".") and flags such as --depth 4
---

# DDS Phase 1: Codebase Reconnaissance

## Role

You are a reconnaissance orchestrator. Your job is to dispatch the `surveyor` sub-agent against the target codebase, capture its output, and present a clean summary so the user can decide which modules to excavate next.

## Goal

Produce `spec/00-survey.md` containing:

1. **Tech stack** — languages, frameworks, runtimes, build systems, deployment hints
2. **Module map** — top-level packages/namespaces/folders with one-line role descriptions
3. **Entry points** — web routes, CLI commands, scheduled jobs, message consumers, batch entry points
4. **Deployment topology** — Dockerfiles, IIS configs, web.config, IaC observed
5. **Excavation cost estimate** — rough effort per module (S/M/L/XL) so the user knows what they're signing up for

This is a fast, breadth-first pass. NO line-by-line analysis happens here. That's `/dds:excavate`'s job.

## User Input

```text
$ARGUMENTS
```

## Command Arguments

| Argument | Format | Default | Description |
|---|---|---|---|
| `path` | Path to codebase root | `.` | Where to start reconnaissance |
| `--depth` | `--depth N` | `3` | Folder-traversal depth for module discovery |
| `--include-pattern` | `--include-pattern <glob>` | None | Only scan files matching glob (e.g., `*.cs`) |
| `--exclude-pattern` | `--exclude-pattern <glob>` | `node_modules,vendor,bin,obj,dist,build` | Skip matching paths |

Parse `$ARGUMENTS`:

```
PATH = first positional argument, default "."
DEPTH = --depth value, default 3
INCLUDE = --include-pattern value, default null
EXCLUDE = --exclude-pattern value, default "node_modules,vendor,bin,obj,dist,build,.git,target,packages"
```

## Pre-Flight Checks

1. Verify `PATH` exists and is a directory.
2. Run the folder setup script (path is supplied by the host platform's plugin-root variable):

   ```bash
   bash <plugin-root>/scripts/create-spec-folders.sh
   ```

3. Check whether `spec/00-survey.md` already exists. If so, ask the user whether to overwrite or append.

4. Track these phases internally so the user can see progress: directory setup → dispatch surveyor → summarize output.

## Workflow

### Step 1: Dispatch the Surveyor Sub-Agent

Dispatch a sub-agent using the `dds:surveyor` agent definition. Pass it the configuration via prompt:

```text
Plugin root: <plugin-root>

Target Path: <PATH>
Traversal Depth: <DEPTH>
Include Pattern: <INCLUDE or "none">
Exclude Pattern: <EXCLUDE>

Your job is to produce spec/00-survey.md. Read README.md and CLAUDE.md
if they exist, for context. Use the available file-listing and file-search
mechanisms to discover:

- Tech stack (language, framework, runtime, build system, package manager)
- Module map (top-level folders/namespaces, with one-line descriptions)
- Entry points (controllers, main(), CLI entry points, scheduled jobs, queue consumers)
- Deployment hints (Dockerfile, IaC, IIS configs, app.config, web.config)
- Excavation cost estimate (S/M/L/XL per module based on file count and complexity heuristics)

CRITICAL:
- This is RECONNAISSANCE only. No line-by-line analysis. No business-rule extraction.
- DO NOT output your findings inline. Create a scratchpad with
  <plugin-root>/scripts/create-scratchpad.sh, dump all raw findings there,
  then synthesize the polished spec/00-survey.md.
- Every module-map entry MUST cite the source folder path (e.g., [src/Billing/]).
- Every entry-point MUST cite a file (e.g., [src/Controllers/OrderController.cs:42]).
```

A model with strong breadth-first reading and decent pattern-recognition is sufficient — this is reconnaissance, not deep reasoning.

**Capture from the sub-agent's response**:
- Survey file path (must be `spec/00-survey.md`)
- Scratchpad file path
- Number of modules discovered
- Number of entry points found
- Detected tech stack summary

### Step 2: Summarize for the User

Present a concise summary so the user can plan excavation:

```markdown
## Survey Complete

| Field | Value |
|---|---|
| **Target** | <PATH> |
| **Tech stack** | <languages, frameworks> |
| **Modules discovered** | <N> |
| **Entry points** | <N> |
| **Survey file** | spec/00-survey.md |
| **Scratchpad** | .specs/scratchpad/<hex>.md |

### Modules (by estimated excavation cost)

| Module | Files | Cost | Folder |
|---|---|---|---|
| billing | 47 | M | src/Billing/ |
| auth | 12 | S | src/Auth/ |
| reports | 213 | XL | src/Reports/ |
| ... |

### Next Steps

1. Review `spec/00-survey.md`
2. Run `/dds:excavate <module-name>` to deep-dive a single module
3. Or run `/dds:excavate --all` to excavate everything (long-running)
4. Once all modules excavated, run `/dds:assemble` to produce the unified Arc42 spec
```

## Constraints

- **Do NOT** perform deep code analysis yourself — delegate to the surveyor sub-agent.
- **Do NOT** read source files line-by-line in this phase — surveyor uses breadth-first listing and pattern search only.
- **Do NOT** create `spec/modules/<name>.md` files — that's the excavator's job.
- **DO** verify the spec file was actually created before reporting success. If missing, re-dispatch the sub-agent.

## Success Criteria

- [ ] `spec/00-survey.md` exists and is non-empty
- [ ] File contains all five required sections (tech stack, module map, entry points, deployment, cost estimate)
- [ ] Every entry-point row has a citation
- [ ] Module map has at least one entry
- [ ] State manifest `spec/.dds-state.json` updated with all discovered modules marked as `surveyed`

## Platform Notes

This skill was designed for Claude Code's slash-command + sub-agent model but uses platform-agnostic language where practical. Concrete tool names referenced in agent prompts (file-listing, file-search, file-read) map to whatever your host platform provides — Claude Code's Glob/Grep/Read, OpenCode's equivalents, Cursor's, etc. The `<plugin-root>` placeholder corresponds to your platform's plugin-directory variable (in Claude Code: `${CLAUDE_PLUGIN_ROOT}`).

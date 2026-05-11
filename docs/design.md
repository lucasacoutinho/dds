# DDS: Development Driven Spec — Design Spec

**Date:** 2026-05-11
**Status:** Approved, ready for implementation
**Related plugins:** `sdd` (forward direction), `docs` (overlapping concerns)

---

## 1. Problem & Goals

### Problem

Legacy codebases (.NET Framework, classic PHP, Delphi, COBOL, old Java EE, legacy Ruby on Rails) accumulate undocumented business knowledge across decades. Teams are afraid to touch them because:

- **Business rules are encoded but not documented** — validation logic, calculations, workflows live inside controllers, stored procedures, and triggers.
- **The data layer is the de-facto spec** — schema, foreign keys, and SQL queries describe behavior more accurately than any README.
- **No one understands the whole system anymore** — original developers left; institutional memory is gone.
- **Modernization stalls** — without an executable spec, rewrites either ship missing rules or get cancelled.

### Goals

DDS turns an existing codebase into an Arc42-informed specification that is **detailed enough to recreate the system**. It does this through:

1. **Bottom-up excavation** — Start from artifacts (SQL, handlers, modules), synthesize upward to architecture.
2. **Citation-first claims** — Every rule, decision, and entry in the spec MUST cite source `file:line`.
3. **Fidelity verification** — An LLM-as-Judge randomly samples claims and verifies them against actual code.

If users want to use the produced spec to drive a rewrite, they invoke SDD manually with the spec as input — DDS does not own the bridge.

### Non-Goals

- Not a static analyzer or AST tool. DDS does not run code; it reads it and reasons about it.
- Not a test generator. (That's TDD's job; DDS produces specs that TDD/SDD can implement against.)
- Not a refactoring tool. DDS observes, it does not edit source files.
- Not a "modernize my code" button. The output is a spec; the rewrite is a separate SDD-driven workflow.

---

## 2. Relationship to SDD

DDS and SDD are **conceptually complementary** but **operationally decoupled**. DDS produces a spec; users may then manually use SDD (or any other forward-engineering process) to rewrite the system.

```
        Legacy code  ──►  DDS (this plugin)  ──►  spec/  (human-readable, committed)
                                                    │
                                                    │ (user manually invokes SDD if a rewrite is desired)
                                                    ▼
                                                  SDD
                                                    │
                                                    ▼
                                             Modern rewrite
```

| Axis | SDD (forward) | DDS (reverse) |
|---|---|---|
| **Direction** | spec → code | code → spec |
| **Flow** | top-down design | bottom-up excavation |
| **Business analyst** | invents acceptance criteria | extracts rules from code |
| **Codebase analysis** | "what files will change" | "what files DO" |
| **Architecture phase** | synthesizes design | reconstructs design |
| **Decomposition** | breaks work into steps | inventories existing modules |
| **Judges** | evaluate plan quality | evaluate spec fidelity |
| **State machine** | `draft → todo → in-progress → done` | `unexplored → surveyed → excavated → assembled` |

### Out of scope (v1)

An automated `--bridge-sdd` flag that emits `.specs/tasks/draft/*.md` task files from DDS's output is **explicitly deferred**. Users can drive SDD by hand using the produced spec as input — pointing SDD agents at `spec/modules/<name>.md` as context yields the same result without coupling the two plugins. May be revisited if manual workflow proves repetitive.

---

## 3. Pipeline

```
Phase 1: Reconnaissance (top-down, breadth-first, fast)
  └─ surveyor agent
     ▸ detects tech stack, build system, deployment
     ▸ enumerates entry points (controllers, main(), web routes, CLI commands, cron jobs)
     ▸ builds module map (top-level packages, namespaces, folders)
     ▸ output: spec/00-survey.md
                                  │
                                  ▼  (Judge: Survey Fidelity)
                                  │
Phase 2: Parallel Excavation (bottom-up, depth-first, heavy)
  Per module from survey, in parallel:
    ├─ module-excavator      → spec/modules/<name>.md
    ├─ data-archaeologist    → spec/data-dictionary.md, spec/sql-inventory.md
    ├─ integration-mapper    → spec/integrations.md
    ├─ business-rule-extractor → spec/business-rules.md
    └─ dead-code-detector    → spec/dead-code.md
                                  │
                                  ▼  (Judge: Fidelity per module)
                                  │
Phase 3: Cross-Reference Synthesis
  └─ resolve conflicts between agents (e.g., business rule found in code
     and in stored proc → reconcile and cite both)
                                  │
                                  ▼
Phase 4: Arc42 Spec Assembly
  └─ spec-assembler
     ▸ produces spec/01-introduction-goals.md through spec/12-glossary.md
                                  │
                                  ▼  (Judge: Arc42 Coverage)
```

---

## 4. Commands

DDS exposes **three commands**, matching SDD's "Simple" philosophy. The heavy work is delegated to specialized agents.

### `/dds:survey [path]`

**Purpose:** Phase 1 reconnaissance.
**Cost:** Fast (~30 min on a medium codebase).
**Output:** `spec/00-survey.md` containing:

- Detected tech stack (language, framework, runtime, build system)
- Module map (folder/namespace tree with one-line descriptions)
- Entry points (web routes, CLI commands, scheduled jobs, message consumers)
- Deployment hints (Dockerfile, IIS configs, web.config, app.config, IaC)
- Estimated excavation cost (modules × complexity)

**Optional args:**

- `path` (default `.`) — root of the codebase to survey.
- `--depth N` (default 3) — folder traversal depth for module discovery.

### `/dds:excavate <module-name | --all>`

**Purpose:** Phase 2 + 3 deep dive on one or all modules.
**Cost:** Heavy. Per-module agent runs sequentially within a module; modules run in parallel.
**Output:** `spec/modules/<name>.md` + appends to global registries (`business-rules.md`, `sql-inventory.md`, `data-dictionary.md`, `integrations.md`, `dead-code.md`).

**Per-module sub-phases (with judge after each):**

1. Module-excavator reads the module **line by line** (literally — the agent's prompt enforces full-file Read of every non-trivial file).
2. Data-archaeologist extracts every SQL query, schema reference, and ORM mapping.
3. Integration-mapper finds every external call (HTTP, queue, file I/O, FFI).
4. Business-rule-extractor identifies validations, calculations, branching workflows.
5. Dead-code-detector marks unreachable functions and orphaned files.
6. Fidelity-judge samples 10% of claims in the module spec and verifies file:line citations.

**Args:**

- `<module-name>` or `--all` (required, mutually exclusive)
- `--target-fidelity X.X` (default 4.0) — judge threshold
- `--max-iterations N` (default 3)
- `--sample-rate F` (default 0.10) — fraction of claims to verify
- `--continue` — resume from last completed module
- `--skip-judges` — fast pass, no fidelity verification (NOT recommended)

### `/dds:assemble`

**Purpose:** Phase 4 — synthesize all excavated module specs into the unified Arc42 spec tree.
**Cost:** Medium.
**Output:** Full Arc42 spec tree under `spec/` (sections 01 through 12, plus global registries).

**Args:**

- `--target-quality X.X` (default 3.5) — judge threshold for arc42 coverage.

---

## 5. Output Structure

DDS writes its primary output to `spec/` (visible, intended for humans to read and commit alongside the legacy code). This contrasts with SDD's `.specs/` (hidden, agent workflow state). The two coexist cleanly:

- `spec/` — DDS output, human-readable, source-of-truth for the legacy system, committed
- `.specs/` — SDD workflow state, optionally populated by DDS's `--bridge-sdd` flag

```
spec/                              # DDS primary output (project root, visible)
├── 00-survey.md                  # Phase 1 output
├── 01-introduction-goals.md      # Arc42 §1
├── 02-constraints.md             # Arc42 §2 — tech/legal/ops observed
├── 03-context-scope.md           # Arc42 §3
├── 04-solution-strategy.md       # Arc42 §4 — reconstructed key decisions
├── 05-building-blocks.md         # Arc42 §5 — module map with deep links
├── 06-runtime.md                 # Arc42 §6 — key flows (request, batch, etc.)
├── 07-deployment.md              # Arc42 §7
├── 08-concepts.md                # Arc42 §8 — auth, logging, error handling
├── 09-decisions.md               # Arc42 §9 — ADRs reconstructed from code
├── 10-quality.md                 # Arc42 §10 — observed quality attributes
├── 11-risks-debt.md              # Arc42 §11 — technical debt inventory
├── 12-glossary.md                # Arc42 §12 — domain terms
├── modules/
│   ├── <module-1>.md
│   ├── <module-2>.md
│   └── ...
├── data-dictionary.md            # Tables, columns, types, relationships
├── sql-inventory.md              # Every query, where used, purpose
├── business-rules.md             # Rules registry with file:line citations
├── integrations.md               # External systems, protocols, contracts
└── dead-code.md                  # Orphaned / unreachable code inventory
```

State management mirrors SDD via a sidecar manifest `spec/.dds-state.json`:

```json
{
  "modules": {
    "billing": "excavated",
    "auth": "surveyed",
    "reports": "unexplored"
  },
  "last_phase": "excavate",
  "fidelity_scores": { "billing": 4.3 }
}
```

---

## 6. Agents

Eight specialized agents, each with isolated context and a focused responsibility. Agents are **model-agnostic** — frontmatter does not pin a specific model. SKILL.md files recommend capability tiers (fast / strong / lightweight) when dispatching, leaving the concrete model choice to the host platform and user.

| Agent | Suggested capability | Purpose |
|---|---|---|
| `surveyor` | Fast, breadth-first | Detect stack, modules, entry points (Phase 1) |
| `module-excavator` | Strong reading, structured output | One agent dispatched per module, reads files line-by-line, produces module spec |
| `data-archaeologist` | Strong SQL/database reasoning | Extract DB schemas (DDL, migrations, ORM), inventory all SQL queries with purposes |
| `business-rule-extractor` | Strong reasoning | Identify validations, calculations, workflows; emit citation-grounded rule registry |
| `integration-mapper` | Fast pattern recognition | Find every external boundary: HTTP, gRPC, SOAP, queues, file I/O, FFI, scheduled jobs |
| `dead-code-detector` | Lightweight | Find unreachable functions, orphaned files, dead config blocks |
| `spec-assembler` | Strong synthesis | Synthesize all per-module outputs into Arc42 sections (Phase 4) |
| `fidelity-judge` | Strong precise reasoning | LLM-as-Judge — randomly sample claims, verify file:line, score module fidelity |

### Agent file structure

Following SDD's pattern (`plugins/sdd/agents/<name>.md`):

```markdown
---
name: <agent-name>
description: <when-to-use>
model: <sonnet|opus|haiku>
color: <color>
---

# <Title> Agent

You are <persona>.

## Identity
## Goal
## Input
## CRITICAL: Load Context
## Reasoning Framework
## Core Responsibilities
## Process
## Output Format
## Constraints
```

Agents reuse SDD's persuasion patterns (`"If you do not perform well enough YOU will be KILLED"`) and scratchpad-first discipline.

---

## 7. Citation-First Spec (Critical Invariant)

**Every claim about behavior in the spec MUST carry a source citation.**

### Citation format

```markdown
- Orders cannot be cancelled after they ship. [src/services/OrderService.cs:142-156]
- Discount caps at 50% unless customer is in "VIP" tier. [src/pricing/discount.php:88, sql/sp_apply_discount.sql:23]
- Email validation rejects + addresses. [src/validators/EmailValidator.cs:34] ⚠️ ditto regex applied client-side: [wwwroot/js/validate.js:67]
```

### Why this matters

The #1 risk in legacy archaeology is **hallucinated business rules**. An LLM that reads thousands of lines of code can confidently invent a rule that doesn't exist, or miss a rule because the rule is in a stored procedure the agent didn't read. Citations force agents to ground every claim, and let the fidelity-judge verify them mechanically.

### Fidelity judge enforcement

For each module spec, the fidelity-judge:

1. Parses all bracketed citations `[path:line]` or `[path:line-line]`.
2. Randomly samples `sample-rate` (default 10%) of citations.
3. For each sampled citation, uses Read tool to fetch the cited lines.
4. Asks itself: "Does the text at this location actually support the claim?"
5. Scores fidelity 1-5 per the rubric in `prompts/fidelity-judge.md`.
6. Any sample that fails fidelity triggers re-excavation of the source file with feedback.

---

## 8. Inherited Patterns from SDD

DDS reuses these proven SDD patterns:

| Pattern | How DDS uses it |
|---|---|
| **Multi-agent context isolation** | One agent per module + one per concern (data, integrations, rules). No agent holds the whole codebase in context. |
| **LLM-as-Judge** | Fidelity-judge after every excavation; arc42-coverage judge after assembly. |
| **Scratchpad-first** | Each agent writes raw findings to `.specs/scratchpad/<hex>.md` before synthesizing into the spec — same script `${CLAUDE_PLUGIN_ROOT}/scripts/create-scratchpad.sh`. |
| **Configurable judge thresholds** | `--target-fidelity` and `--target-quality` flags mirror SDD's. |
| **Continue / skip / refine flags** | Same UX as SDD's `--continue`, `--skip`, `--max-iterations`. |
| **Foreground agents only** | Parallel where independent (modules, concerns); never background. |
| **Sub-3.5 score = retry** | Same default thresholds as SDD. |

DDS does **not** reuse:

- SDD's `business-analyst` agent (DDS extracts from code, not from user prompts)
- SDD's `tech-lead`, `team-lead`, `qa-engineer` (DDS does not decompose new work; it inventories existing work)

---

## 9. New Patterns Introduced by DDS

| Pattern | Description | Inspiration |
|---|---|---|
| **Citation-first claims** | Every spec line must cite source `file:line`. Hallucination mitigation. | Code review tools, RAG citations |
| **Random-sample fidelity** | Judge verifies a random N% of claims rather than all (cost control). | Software inspection sampling, statistical QA |
| **Line-by-line read enforcement** | Module-excavator prompt requires full Read on every non-trivial file in the module (no skimming). | Reverse engineering best practice |
| **State machine on disk** | `spec/.dds-state.json` tracks per-module excavation state, mirroring SDD's folder-based state. | SDD's `draft/todo/in-progress/done` pattern |

---

## 10. Risks and Open Questions

| Risk | Mitigation |
|---|---|
| Module-excavator hits context limits on large modules | Sub-divide module by file groups (controllers, services, models); excavate each sub-group separately, then synthesize. |
| Citations point to refactored code after spec is written | Spec embeds git commit SHA in frontmatter. Re-excavation flag detects stale citations via `git diff`. |
| SQL extracted but business rule lives in stored procedure not in repo | Data-archaeologist explicitly looks for `*.sql`, `migrations/*`, `db/*`, and emits warnings when ORM models reference DB objects not found in the repo. |
| Dead-code-detector false positives (reflection, dynamic dispatch) | Marks findings as "orphaned (verify)" not "dead". Human review required before deletion. |
| Spec drift from code over time | Out of scope for v1. Future: `/dds:reconcile` command to diff spec against current code. |

### Resolved during brainstorming

- **Output format**: Arc42-informed spec tree (extensive enough for legacy archaeology).
- **Granularity**: Per-module decomposition (`spec/modules/<name>.md`) plus global registries (data, SQL, rules, integrations, dead code).
- **Commands**: Three — `/dds:survey`, `/dds:excavate`, `/dds:assemble`.
- **Citation-first**: Non-negotiable hard constraint enforced by fidelity-judge.
- **SDD bridge**: Deferred (v1) — users invoke SDD manually if they want a rewrite, pointing it at DDS's spec output.

---

## 11. Implementation Plan (high-level)

The implementation plan will be written as a follow-up document. High-level order:

1. Scaffold `plugins/dds/` with `plugin.json`, `README.md`, directory tree.
2. Write three commands as skill files under `plugins/dds/skills/<command>/SKILL.md`.
3. Write nine agents under `plugins/dds/agents/<agent>.md`.
4. Write shared script `plugins/dds/scripts/create-spec-folders.sh` and prompt `plugins/dds/prompts/fidelity-judge.md`.
5. Add `dds` entry to `.claude-plugin/marketplace.json`.
6. Add docs at `docs/plugins/dds/README.md`, update root `README.md` and `docs/reference/commands.md`.
7. Bump versions via `just set-version dds 1.0.0` and `just set-marketplace-version <next>`.
8. Run plugin-validator.

---

## 12. References

### Standards & methodologies

- **Arc42** — https://arc42.org/ — the architecture documentation standard DDS's spec tree is informed by.
- **C4 model** (Brown) — referenced for runtime/component diagrams in `spec/06-runtime.md` and `spec/05-building-blocks.md`.
- **GitHub Spec Kit** — already used by SDD; DDS bridges into its format.

### Research

- **LLM-as-a-Judge** (arxiv 2306.05685) — reused from SDD for fidelity verification.
- **Chain-of-Verification** (arxiv 2309.11495) — informs citation-then-verify pattern.
- **Reverse Engineering Strategies for Legacy Modernization** — general practice literature, no single citation.

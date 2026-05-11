# Development Driven Spec (DDS): Reverse-Engineer Legacy Codebases into Arc42 Specs

DDS is the inverse of SDD. SDD turns a spec into code; DDS turns code into a spec. Use it on legacy codebases — old PHP, .NET Framework, Delphi, classic Java EE, untouchable Rails monoliths — to produce an Arc42-informed specification detailed enough to **recreate the system** in a modern stack.

## Why this exists

Legacy codebases accumulate undocumented business knowledge across decades. Validations live in controllers. Calculations live in stored procedures. Workflows live in `IF` statements no one has read since 2012. Modernization stalls because no one can answer "what does this system actually DO?"

DDS answers that question. It produces a citation-grounded specification where every behavioral claim points back to a `file:line` in the legacy source. A fidelity-judge agent then random-samples those citations and verifies them against the actual code, catching hallucinated rules before they reach the spec.

## Key Features

- **Citation-first** — Every claim about behavior carries a `[file:line]` citation. Uncited claims fail the fidelity-judge.
- **Bottom-up excavation** — Starts from artifacts (SQL, handlers, modules) and synthesizes upward to architecture. Inverts SDD's top-down flow.
- **LLM-as-Judge fidelity verification** — Random-samples claimed rules and verifies them line-by-line in the source. Catches the #1 risk in reverse engineering: hallucinated business rules.
- **Multi-agent context isolation** — 8 specialized agents, each with a focused responsibility (surveyor, module-excavator, data-archaeologist, business-rule-extractor, integration-mapper, dead-code-detector, spec-assembler, fidelity-judge). No agent holds the whole codebase in context.
- **Per-module decomposition + global registries** — `spec/modules/<name>.md` per module, plus global `spec/business-rules.md`, `spec/sql-inventory.md`, `spec/data-dictionary.md`, `spec/integrations.md`, `spec/dead-code.md`.
- **Arc42-informed output** — The unified spec follows the arc42 12-section template (introduction, constraints, context, solution strategy, building blocks, runtime, deployment, concepts, decisions, quality, risks, glossary), reconstructed from observed code patterns.

## Quick Start

Install directly from this GitHub repo via Claude Code's plugin system:

```bash
/plugin install lucasacoutinho/dds
```

Or, if you maintain your own marketplace file, add this repo as a source. Once enabled, run in order:

```bash
# Phase 1: Fast reconnaissance — detect stack, modules, entry points
/dds:survey

# Phase 2: Deep excavation per module (heavy; pick one to start)
/dds:excavate <module-name>
# Or all modules at once:
/dds:excavate --all

# Phase 4: Assemble the unified Arc42 spec
/dds:assemble
```

Output goes to `spec/` (visible, committed) alongside `.specs/scratchpad/` (gitignored sub-agent workspace).

## Overall Flow

```
Phase 1: Reconnaissance (top-down, fast)
  └─ /dds:survey
     surveyor agent → spec/00-survey.md

Phase 2: Excavation (bottom-up, heavy)
  └─ /dds:excavate <module>
     ├─ module-excavator      → spec/modules/<name>.md   (line-by-line)
     ├─ data-archaeologist    → spec/sql-inventory.md + spec/data-dictionary.md
     ├─ integration-mapper    → spec/integrations.md
     ├─ business-rule-extractor → spec/business-rules.md
     ├─ dead-code-detector    → spec/dead-code.md
     └─ fidelity-judge        → verifies sampled citations against source

Phase 4: Arc42 Assembly
  └─ /dds:assemble
     spec-assembler → spec/01-introduction-goals.md ... spec/12-glossary.md
```

## Commands

| Command | Purpose | Cost |
|---|---|---|
| [`/dds:survey`](skills/survey/SKILL.md) | Phase 1 — detect stack, modules, entry points, deployment topology, excavation cost | Fast (~30 min) |
| [`/dds:excavate`](skills/excavate/SKILL.md) | Phase 2 — deep dive per module with citation-first claims and fidelity verification | Heavy (hours/days) |
| [`/dds:assemble`](skills/assemble/SKILL.md) | Phase 4 — synthesize per-module specs into Arc42 12-section spec | Medium |

## Agents

The agents below are model-agnostic — agent frontmatter does not pin a specific model. Each SKILL.md recommends an appropriate capability tier (fast/strong) when dispatching the sub-agent, but the final choice is up to the host platform and user.

| Agent | Suggested capability | Use when |
|---|---|---|
| [`dds:surveyor`](agents/surveyor.md) | Fast, breadth-first | Phase 1 reconnaissance — tech stack, module map, entry points |
| [`dds:module-excavator`](agents/module-excavator.md) | Strong reading, structured output | One per module — line-by-line reading, produces module spec |
| [`dds:data-archaeologist`](agents/data-archaeologist.md) | Strong SQL/database reasoning | Extract DB schemas, SQL queries, stored procs, ORM mappings |
| [`dds:business-rule-extractor`](agents/business-rule-extractor.md) | Strong reasoning | Find validations, calculations, workflows, authz rules; cite all sources |
| [`dds:integration-mapper`](agents/integration-mapper.md) | Fast pattern recognition | External boundaries — HTTP, queues, file I/O, scheduled jobs, FFI |
| [`dds:dead-code-detector`](agents/dead-code-detector.md) | Lightweight | Find apparently-unused code with confidence levels |
| [`dds:spec-assembler`](agents/spec-assembler.md) | Strong synthesis | Synthesize per-module specs into Arc42 sections |
| [`dds:fidelity-judge`](agents/fidelity-judge.md) | Strong precise reasoning | Random-sample citations and verify against source code |

## Output Structure

```
spec/                              # DDS primary output — visible, committed
├── 00-survey.md                  # Phase 1: stack, module map, entry points
├── 01-introduction-goals.md      # Arc42 §1
├── 02-constraints.md             # Arc42 §2
├── 03-context-scope.md           # Arc42 §3
├── 04-solution-strategy.md       # Arc42 §4
├── 05-building-blocks.md         # Arc42 §5
├── 06-runtime.md                 # Arc42 §6
├── 07-deployment.md              # Arc42 §7
├── 08-concepts.md                # Arc42 §8
├── 09-decisions.md               # Arc42 §9 — reconstructed ADRs
├── 10-quality.md                 # Arc42 §10
├── 11-risks-debt.md              # Arc42 §11
├── 12-glossary.md                # Arc42 §12
├── modules/<module>.md           # Per-module deep dive
├── data-dictionary.md            # Tables, columns, types, constraints
├── sql-inventory.md              # Every query + stored proc with purpose
├── business-rules.md             # Validations, calculations, workflows, authz
├── integrations.md               # External system boundaries
├── dead-code.md                  # Orphaned code with verification flags
└── .dds-state.json               # Per-module excavation state
```

## Patterns

Key patterns implemented in this plugin:

- **Citation-first claims** — Every behavioral claim cites `[file:line]`. Uncited claims auto-fail the fidelity-judge. Mitigates hallucinated business rules.
- **Random-sample fidelity verification** — LLM-as-Judge samples 10% of citations (configurable), reads the cited lines, and scores fidelity. Catches WRONG_LINES, WRONG_FILE, and HALLUCINATION verdicts before they reach the spec.
- **Line-by-line read enforcement** — Module-excavator's prompt requires Read on every non-trivial file (no skimming from filenames or comments).
- **Multi-agent context isolation** — One agent per module + one per concern (data, integrations, rules, dead code). No agent holds the whole codebase in context.
- **Scratchpad-first synthesis** — Each agent dumps raw findings to `.specs/scratchpad/<hex>.md`, then synthesizes verified claims into the spec.
- **State machine on disk** — `spec/.dds-state.json` tracks per-module state: `unexplored → surveyed → excavated → excavated_with_warnings`.

## Relationship to SDD

DDS and SDD are conceptually complementary but operationally decoupled. DDS produces a spec; if you want to drive a rewrite, manually invoke SDD's `/plan-task` and `/implement-task` pointing at the relevant `spec/modules/<name>.md` files. There is no automated bridge in v1.

| Axis | SDD (forward) | DDS (reverse) |
|---|---|---|
| Direction | spec → code | code → spec |
| Flow | top-down design | bottom-up excavation |
| Business analyst | invents acceptance criteria | extracts rules from code |
| Architecture phase | synthesizes design | reconstructs design |
| Judges | evaluate plan quality | evaluate spec fidelity |

## Vibe Reverse-Engineering vs. Faithful Reverse-Engineering

The fidelity-judge is what separates DDS from a "let me read the code and write a markdown summary" approach. Without it, an LLM will confidently fabricate plausible-sounding business rules that don't actually exist. With it, every claim is grounded.

You can run with `--skip-judges` for speed, but the resulting spec is no more trustworthy than a single-pass LLM summary.

To improve fidelity further, you can raise the sample rate (`--sample-rate 0.25`) or the threshold (`--target-fidelity 4.5`), at the cost of token spend.

## Theoretical Foundation

- **Arc42** ([arc42.org](https://arc42.org)) — the architecture documentation standard the spec tree is informed by
- **Chain-of-Verification** ([arXiv:2309.11495](https://arxiv.org/abs/2309.11495)) — informs the citation-then-verify pattern
- **LLM-as-a-Judge** ([arXiv:2306.05685](https://arxiv.org/abs/2306.05685)) — reused for fidelity verification
- **Software inspection sampling** — random-sample claim verification, classic SE QA technique
- General reverse-engineering practice from legacy modernization literature

## Design

For the full architectural rationale, see [docs/design.md](docs/design.md) — covers pipeline phases, the citation-first invariant, the fidelity-judge methodology, and trade-offs explored during design.

## License

MIT — see [LICENSE](LICENSE).

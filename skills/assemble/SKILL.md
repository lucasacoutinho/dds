---
name: assemble
description: Final phase of DDS reverse-engineering. Synthesizes all per-module specs and global registries into the unified Arc42 specification tree (sections 01-12), producing a human-readable, citation-grounded specification of the legacy system suitable for understanding, audit, or driving a rewrite.
argument-hint: Optional flags such as --target-quality 4.0
---

# DDS Final Phase: Arc42 Spec Assembly

## Role

You are an assembly orchestrator. You dispatch the `dds:spec-assembler` sub-agent to read every excavated module spec and every global registry, then synthesize the Arc42-section files under `spec/` (sections 01 through 12). After assembly, an arc42-coverage judge validates the synthesis quality.

## Goal

Produce a complete, human-readable, citation-grounded Arc42 specification:

```
spec/
├── 00-survey.md                 (from /dds:survey)
├── 01-introduction-goals.md     ← assembled
├── 02-constraints.md            ← assembled
├── 03-context-scope.md          ← assembled
├── 04-solution-strategy.md      ← assembled
├── 05-building-blocks.md        ← assembled
├── 06-runtime.md                ← assembled
├── 07-deployment.md             ← assembled
├── 08-concepts.md               ← assembled
├── 09-decisions.md              ← assembled
├── 10-quality.md                ← assembled
├── 11-risks-debt.md             ← assembled
├── 12-glossary.md               ← assembled
├── modules/                     (from /dds:excavate)
├── business-rules.md            (from /dds:excavate)
├── sql-inventory.md             (from /dds:excavate)
├── data-dictionary.md           (from /dds:excavate)
├── integrations.md              (from /dds:excavate)
└── dead-code.md                 (from /dds:excavate)
```

## User Input

```text
$ARGUMENTS
```

## Command Arguments

| Argument | Format | Default | Description |
|---|---|---|---|
| `--target-quality` | `--target-quality X.X` | `3.5` | Arc42 coverage judge threshold |
| `--max-iterations` | `--max-iterations N` | `3` | Max assembler retries |
| `--sections` | `--sections 01,03,05` | All | Comma-separated section numbers to (re)generate |
| `--skip-judges` | `--skip-judges` | `false` | Skip arc42 coverage judge |

## Pre-Flight Checks

1. **Survey must exist**: Verify `spec/00-survey.md` exists.

2. **At least one module excavated**: Read `spec/.dds-state.json`. If no module has status `excavated` or `excavated_with_warnings`, instruct user to run `/dds:excavate <module>` first and exit.

3. **Detect under-excavation**: If only some modules are excavated, warn user that the resulting spec will be partial. Ask for confirmation to proceed.

4. **Folder setup**:

   ```bash
   bash <plugin-root>/scripts/create-spec-folders.sh
   ```

5. Track progress internally: verify excavation completeness → dispatch assembler → run arc42 coverage judge → summarize.

## Workflow

### Step 1: Dispatch the Spec Assembler

Dispatch a sub-agent using the `dds:spec-assembler` agent definition. Recommend a strong-reasoning model — this sub-agent does the most synthesis work, cross-referencing many module specs into coherent architectural sections:

```text
Plugin root: <plugin-root>

Your job is to produce these files (or only those listed in <sections>):

  spec/01-introduction-goals.md
  spec/02-constraints.md
  spec/03-context-scope.md
  spec/04-solution-strategy.md
  spec/05-building-blocks.md
  spec/06-runtime.md
  spec/07-deployment.md
  spec/08-concepts.md
  spec/09-decisions.md
  spec/10-quality.md
  spec/11-risks-debt.md
  spec/12-glossary.md

Sections to (re)generate: <SECTIONS or "all">

Sources you MUST read:
- spec/00-survey.md                  (stack, module map, entry points)
- spec/modules/*.md                  (every per-module deep dive)
- spec/business-rules.md             (citation-grounded rule registry)
- spec/sql-inventory.md              (every query with purpose)
- spec/data-dictionary.md            (schemas, columns, relationships)
- spec/integrations.md               (external boundaries)
- spec/dead-code.md                  (orphaned code)
- README.md, CLAUDE.md if present

CRITICAL:
- Use scratchpad first: bash <plugin-root>/scripts/create-scratchpad.sh
- DO NOT invent claims. Every architectural claim MUST be supported by a citation
  inherited from a per-module spec or registry.
- For each Arc42 section, follow the standard arc42 template guidance.
- DO NOT output content inline. Write to files.
```

**Capture**: scratchpad path, sections written, ADRs reconstructed count, total citations.

### Step 2: Run the Arc42 Coverage Judge

If SKIP_JUDGES is false, dispatch a sub-agent using the `dds:spec-assembler` agent definition again, this time in judge mode:

```text
Plugin root: <plugin-root>

Read <plugin-root>/prompts/fidelity-judge.md for general evaluation methodology
(adapt: instead of citation sampling, evaluate arc42 coverage).

Evaluate the assembled spec/01-*.md through spec/12-*.md against this rubric:

### Rubric (weights sum to 1.0)

1. **Section Completeness** (weight 0.30)
   - Every arc42 section present and non-trivial?
   - 1=missing sections, 3=all present but thin, 5=all present and substantive

2. **Citation Inheritance** (weight 0.30)
   - Are architectural claims grounded in citations from per-module specs?
   - Or fabricated synthesis without traceable evidence?
   - 1=mostly fabricated, 5=every claim traceable to a per-module citation

3. **Cross-Module Coherence** (weight 0.20)
   - Does §5 (building blocks) reference every module from spec/modules/?
   - Does §6 (runtime) describe flows that span module boundaries?
   - 1=modules orphaned, 5=fully cross-referenced

4. **Reconstructed ADRs Quality** (weight 0.10)
   - Does §9 (decisions) contain plausible ADRs reconstructed from observed code patterns?
   - Or is it empty/generic?
   - 1=empty/generic, 5=substantive reconstructed ADRs each citing source

5. **Glossary Completeness** (weight 0.10)
   - Does §12 contain the domain terms used throughout the spec?
   - 1=missing, 5=comprehensive

### Decision Logic
- PASS (score >= TARGET_QUALITY): proceed
- FAIL: re-dispatch assembler with feedback, up to MAX_ITERATIONS
- Score 5.0 = hallucination; reject and re-judge.
```

### Step 3: Summarize the Spec

```markdown
## Arc42 Spec Assembled

| Section | File | Status |
|---|---|---|
| §1 Introduction & Goals | spec/01-introduction-goals.md | ✅ |
| §2 Constraints | spec/02-constraints.md | ✅ |
| ... |

**Coverage score**: <X.X>/<TARGET_QUALITY>

### Spec Tree

(tree listing of spec/)

### Next Steps

- Read `spec/` end-to-end as the source of truth for the legacy system.
- If you want to drive a rewrite, manually invoke SDD with relevant module specs
  as input context — DDS does not automate this bridge.
- If you discover gaps, edit the affected spec/modules/<name>.md file and re-run
  `/dds:assemble --sections <N>` to regenerate the affected arc42 section.
```

## Constraints

- **NEVER** invent architectural decisions. Every claim in §4 (Solution Strategy) and §9 (Decisions) must be derivable from per-module evidence.
- **NEVER** skip the citation-inheritance check unless `--skip-judges` is explicit.
- **DO** preserve per-module specs unchanged. The assembler reads them, does not edit them.
- **DO** include source citations in arc42 sections wherever they trace back to specific code (especially in §5, §6, §9).

## Platform Notes

The `<plugin-root>` placeholder corresponds to your platform's plugin-directory variable (in Claude Code: `${CLAUDE_PLUGIN_ROOT}`). "Dispatch a sub-agent" maps to whatever sub-agent mechanism your host platform provides.

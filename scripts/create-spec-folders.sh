#!/usr/bin/env bash
#
# create-spec-folders.sh
#
# Prepares the directory layout DDS writes into:
#
#   spec/                    primary output, human-readable, COMMITTED
#   spec/modules/            per-module deep-dives, committed
#   spec/.dds-state.json     workflow state machine for /dds:excavate
#   .specs/scratchpad/       sub-agent workspace, GITIGNORED
#   .specs/analysis/         supporting analysis artifacts
#
# The scratchpad directory is added to .gitignore on first invocation so
# raw sub-agent dumps never leak into commits.

set -euo pipefail

if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'create-spec-folders.sh: not inside a git work tree\n' >&2
    exit 1
fi

gitignore="${repo_root}/.gitignore"
ignore_line=".specs/scratchpad/"

# DDS output (visible, committed)
mkdir -p "${repo_root}/spec/modules"
: > "${repo_root}/spec/.gitkeep"
: > "${repo_root}/spec/modules/.gitkeep"

# Sub-agent workspace
mkdir -p "${repo_root}/.specs/scratchpad"
mkdir -p "${repo_root}/.specs/analysis"
: > "${repo_root}/.specs/analysis/.gitkeep"

# Make sure the scratchpad is gitignored. Use grep -qxF for whole-line match.
if [[ -f "${gitignore}" ]]; then
    if ! grep -qxF "${ignore_line}" "${gitignore}"; then
        if [[ -s "${gitignore}" ]] && [[ "$(tail -c 1 "${gitignore}")" != $'\n' ]]; then
            printf '\n' >> "${gitignore}"
        fi
        printf '%s\n' "${ignore_line}" >> "${gitignore}"
    fi
else
    printf '%s\n' "${ignore_line}" > "${gitignore}"
fi

# Initialise the state manifest if absent. Keep this as a one-line JSON so
# it merges cleanly across concurrent module-excavator runs that may rewrite
# their own slice — full pretty-print only happens after Phase 4.
state_file="${repo_root}/spec/.dds-state.json"
if [[ ! -f "${state_file}" ]]; then
    printf '{"modules":{},"last_phase":null,"fidelity_scores":{}}\n' > "${state_file}"
fi

printf 'Created folders:\n'
printf '  spec/                committed DDS output\n'
printf '  spec/modules/        per-module deep dives\n'
printf '  .specs/scratchpad/   agent workspace (gitignored)\n'
printf '  .specs/analysis/     analysis artifacts\n'
printf '\n'
printf 'State manifest: spec/.dds-state.json\n'
printf 'Added to .gitignore: %s\n' "${ignore_line}"

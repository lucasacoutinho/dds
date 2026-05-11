#!/usr/bin/env bash
#
# create-scratchpad.sh
#
# Allocates a fresh scratchpad markdown file for a DDS sub-agent to dump
# raw, unfiltered findings into. The scratchpad lives under .specs/scratchpad/
# (gitignored) and uses a short random hex ID to avoid collisions when
# multiple sub-agents are dispatched in parallel.
#
# Prints two lines on success:
#   1. The repo-relative path to the new scratchpad
#   2. The absolute path to the new scratchpad
#
# Plus a CRITICAL reminder to the agent: scratchpads are markdown files,
# work with them via the file-read/file-write tools, not bash one-liners.

set -euo pipefail

# Resolve repo root via git. If we are not in a git checkout, bail loudly:
# DDS spec output needs to be tracked, and a scratchpad without a known
# location is a footgun.
if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
    printf 'create-scratchpad.sh: not inside a git work tree\n' >&2
    exit 1
fi

scratchpad_dir="${repo_root}/.specs/scratchpad"
gitignore="${repo_root}/.gitignore"
ignore_line=".specs/scratchpad/"

mkdir -p "${scratchpad_dir}"

# Append the ignore rule if .gitignore exists and is missing it; otherwise
# create .gitignore with just that rule. grep -qxF matches the whole line so
# we do not get fooled by a partial substring elsewhere in the file.
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

# Generate an 8-hex-char ID. Prefer /dev/urandom for portability; fall back
# to openssl if the random device is unavailable.
if [[ -r /dev/urandom ]]; then
    hex_id="$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
else
    hex_id="$(openssl rand -hex 4)"
fi

scratchpad_file="${scratchpad_dir}/${hex_id}.md"
: > "${scratchpad_file}"

printf 'Scratchpad file: %s\n' "${scratchpad_file#"${repo_root}/"}"
printf 'Absolute path:   %s\n' "${scratchpad_file}"
printf 'CRITICAL: work on this scratchpad via the file-read/file-write tools only. Do not pipe content into it from bash, cat, echo, or python.\n'

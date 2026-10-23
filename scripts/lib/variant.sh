#!/bin/bash
# Shared helpers for randomized CKA lab variants.
#
# This file is meant to be sourced, not executed. The selected variant is
# recorded per question under .cka-state/ in the repository root so that
# validate.bash and cleanup.bash can determine which preset is active.

cka_variant_root() {
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$lib_dir/../.." && pwd
}

cka_variant_state_file() {
  local question_dir="$1"
  local dir_name
  dir_name="$(basename "${question_dir%/}")"
  printf '%s/.cka-state/%s.variant\n' "$(cka_variant_root)" "$dir_name"
}

# cka_variant_select <question-dir> <count> [requested]
# Prints the selected variant number and records it. With no requested value,
# a preset is chosen randomly. Invalid requests fail instead of falling back.
cka_variant_select() {
  local question_dir="$1"
  local count="$2"
  local requested="${3:-}"
  local selected state_file state_dir

  if ! [[ "$count" =~ ^[0-9]+$ ]] || (( 10#$count < 1 )); then
    echo "Error: invalid variant count '$count'" >&2
    return 1
  fi

  if [[ -n "$requested" ]]; then
    if ! [[ "$requested" =~ ^[0-9]+$ ]] || (( ${#requested} > 9 )); then
      echo "Error: variant must be a number between 1 and $count (got '$requested')" >&2
      return 1
    fi
    selected=$((10#$requested))
    if (( selected < 1 || selected > 10#$count )); then
      echo "Error: variant must be a number between 1 and $count (got '$requested')" >&2
      return 1
    fi
  else
    selected=$(( (RANDOM % 10#$count) + 1 ))
  fi

  state_file="$(cka_variant_state_file "$question_dir")"
  state_dir="$(dirname "$state_file")"
  mkdir -p "$state_dir"
  printf '%s\n' "$selected" > "$state_file"
  printf '%s\n' "$selected"
}

# cka_variant_read <question-dir> <count>
# Prints the recorded variant number. Missing or invalid state is a hard
# failure: validation must never silently assume a particular variant.
cka_variant_read() {
  local question_dir="$1"
  local count="$2"
  local state_file value dir_name

  dir_name="$(basename "${question_dir%/}")"
  state_file="$(cka_variant_state_file "$question_dir")"

  if [[ ! -f "$state_file" ]]; then
    echo "Error: no variant recorded for $dir_name. Run setup first (scripts/run-question.sh <N>)." >&2
    return 1
  fi

  value="$(<"$state_file")"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || (( ${#value} > 9 )); then
    echo "Error: invalid recorded variant '$value' for $dir_name. Re-run setup." >&2
    return 1
  fi

  value=$((10#$value))
  if (( value < 1 || value > 10#$count )); then
    echo "Error: recorded variant '$value' is outside 1..$count for $dir_name. Re-run setup." >&2
    return 1
  fi

  printf '%s\n' "$value"
}

# cka_variant_clear <question-dir>
cka_variant_clear() {
  local question_dir="$1"
  local state_file
  state_file="$(cka_variant_state_file "$question_dir")"
  rm -f "$state_file"
  rmdir "$(dirname "$state_file")" 2>/dev/null || true
}

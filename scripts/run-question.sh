#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: scripts/run-question.sh <question-number|question-dir> [variant]" >&2
  echo "Examples:" >&2
  echo "  scripts/run-question.sh 5" >&2
  echo "  scripts/run-question.sh Question-5-HPA" >&2
  echo "  scripts/run-question.sh 1 2" >&2
  exit 1
fi

QUESTION_INPUT="$1"
VARIANT_ARG="${2:-}"

if [[ -n "$VARIANT_ARG" ]] && ! [[ "$VARIANT_ARG" =~ ^[0-9]+$ ]]; then
  echo "Error: variant must be a positive number (got '$VARIANT_ARG')" >&2
  exit 1
fi

# If input is just a number, find the matching Question-N- directory
if [[ "$QUESTION_INPUT" =~ ^[0-9]+$ ]]; then
  QUESTION_DIR=$(find "$BASE_DIR" -maxdepth 1 -type d -name "Question-$QUESTION_INPUT-*" | head -1)
  if [[ -z "$QUESTION_DIR" ]]; then
    echo "Error: Question directory for Question-$QUESTION_INPUT not found" >&2
    exit 1
  fi
else
  # Accept either an absolute path or a name relative to the repo root
  if [[ -d "$BASE_DIR/$QUESTION_INPUT" ]]; then
    QUESTION_DIR="$BASE_DIR/$QUESTION_INPUT"
  else
    QUESTION_DIR="$QUESTION_INPUT"
  fi
fi

if [[ ! -d "$QUESTION_DIR" ]]; then
  echo "Question directory '$QUESTION_DIR' not found" >&2
  exit 1
fi

SETUP="$QUESTION_DIR/LabSetUp.bash"
QUESTION_TEXT="$QUESTION_DIR/Questions.bash"
SOLUTION="$QUESTION_DIR/SolutionNotes.bash"

[[ -f "$SETUP" ]] || { echo "Missing $SETUP" >&2; exit 1; }
[[ -f "$QUESTION_TEXT" ]] || { echo "Missing $QUESTION_TEXT" >&2; exit 1; }

if [[ -n "$VARIANT_ARG" && ! -f "$QUESTION_DIR/variants.bash" ]]; then
  echo "Error: $(basename "$QUESTION_DIR") does not support variants (no variants.bash found)" >&2
  exit 1
fi

chmod +x "$SETUP"

echo "==> Running lab setup for $QUESTION_DIR"
if [[ -n "$VARIANT_ARG" ]]; then
  "$SETUP" "$VARIANT_ARG"
else
  "$SETUP"
fi

# Variant-enabled setups print the full question for the selected preset.
# Only print the static Questions.bash for single-variant labs.
if [[ ! -f "$QUESTION_DIR/variants.bash" ]]; then
  echo
  echo "==> Question"
  cat "$QUESTION_TEXT"
fi

echo
if [[ -f "$SOLUTION" ]]; then
  echo "Hints: see $SOLUTION"
fi

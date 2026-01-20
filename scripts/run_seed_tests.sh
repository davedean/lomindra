#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${ROOT}/reports"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_PATH="${REPORT_DIR}/seed_report_${TIMESTAMP}.txt"
SYNC_DB_PATH="$(mktemp "/tmp/vikunja_seed_sync_${TIMESTAMP}_XXXX.db")"
STATE_PATH="$(mktemp "/tmp/vikunja_seed_env_${TIMESTAMP}_XXXX.json")"

mkdir -p "${REPORT_DIR}"
cd "${ROOT}"

run_step() {
  echo "\n$ $*" | tee -a "${REPORT_PATH}"
  "$@" 2>&1 | tee -a "${REPORT_PATH}"
}

FORCE=0
KEEP=0
COUNT=2
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1 ;;
    --keep) KEEP=1 ;;
    --count) COUNT="${2:-2}"; shift ;;
  esac
  shift
done

echo "Seed test report: ${REPORT_PATH}" | tee "${REPORT_PATH}"
echo "Started: $(date)" | tee -a "${REPORT_PATH}"
echo "Temp sync db: ${SYNC_DB_PATH}" | tee -a "${REPORT_PATH}"
echo "Temp state: ${STATE_PATH}" | tee -a "${REPORT_PATH}"

run_step swiftc -o /tmp/seed_test_data scripts/seed_test_data.swift
run_step /tmp/seed_test_data --setup-env --count "${COUNT}" --state-path "${STATE_PATH}"
if [[ "${FORCE}" == "1" ]]; then
  run_step /tmp/seed_test_data --force --state-path "${STATE_PATH}"
else
  run_step /tmp/seed_test_data --reset --state-path "${STATE_PATH}"
fi
LIST_MAP_PATH="$(STATE_PATH="${STATE_PATH}" python3 -c 'import json,os; path=os.environ.get("STATE_PATH"); print(json.load(open(path)).get("listMapPath",""))')"
echo "List map path: ${LIST_MAP_PATH}" | tee -a "${REPORT_PATH}"
echo "\n=== Dry run: initial ===" | tee -a "${REPORT_PATH}"
run_step env SYNC_DB_PATH="${SYNC_DB_PATH}" LIST_MAP_PATH="${LIST_MAP_PATH}" swift run mvp_sync
echo "\n=== Apply ===" | tee -a "${REPORT_PATH}"
run_step env SYNC_DB_PATH="${SYNC_DB_PATH}" LIST_MAP_PATH="${LIST_MAP_PATH}" swift run mvp_sync --apply
echo "\n=== Dry run: post-apply (expect 0 changes) ===" | tee -a "${REPORT_PATH}"
run_step env SYNC_DB_PATH="${SYNC_DB_PATH}" LIST_MAP_PATH="${LIST_MAP_PATH}" swift run mvp_sync
echo "\n=== Mutate conflicts ===" | tee -a "${REPORT_PATH}"
run_step /tmp/seed_test_data --mutate-conflicts --state-path "${STATE_PATH}"
echo "\n=== Dry run: conflicts ===" | tee -a "${REPORT_PATH}"
run_step env SYNC_DB_PATH="${SYNC_DB_PATH}" LIST_MAP_PATH="${LIST_MAP_PATH}" swift run mvp_sync

echo "Completed: $(date)" | tee -a "${REPORT_PATH}"
echo "\n=== Summary ===" | tee -a "${REPORT_PATH}"
rg -n "Dry-run diff summary|Create in Vikunja:|Create in Reminders:|Update Vikunja:|Update Reminders:|Delete in Vikunja:|Delete in Reminders:|Ignored missing|Conflicts:|Unknown direction:" "${REPORT_PATH}" | tee -a "${REPORT_PATH}"
echo "\n=== Expectations ===" | tee -a "${REPORT_PATH}"
COUNT="${COUNT}" REPORT_PATH="${REPORT_PATH}" python3 - <<'PY' | tee -a "${REPORT_PATH}"
import os
import re

count = int(os.environ.get("COUNT", "2"))
report_path = os.environ["REPORT_PATH"]

sections = {
    "initial": "=== Dry run: initial ===",
    "post_apply": "=== Dry run: post-apply (expect 0 changes) ===",
    "conflicts": "=== Dry run: conflicts ===",
}

key_map = {
    "create_vikunja": re.compile(r"Create in Vikunja: (\d+)"),
    "create_reminders": re.compile(r"Create in Reminders: (\d+)"),
    "update_vikunja": re.compile(r"Update Vikunja: (\d+)"),
    "update_reminders": re.compile(r"Update Reminders: (\d+)"),
    "delete_vikunja": re.compile(r"Delete in Vikunja: (\d+)"),
    "delete_reminders": re.compile(r"Delete in Reminders: (\d+)"),
    "conflicts": re.compile(r"Conflicts: (\d+)"),
    "ambiguous": re.compile(r"Ambiguous matches: (\d+)"),
}

def parse_section(lines):
    values = {key: 0 for key in key_map.keys()}
    for line in lines:
        for key, pattern in key_map.items():
            m = pattern.search(line)
            if m:
                values[key] += int(m.group(1))
    return values

with open(report_path, "r", encoding="utf-8") as f:
    text = f.read()

results = {}
for key, marker in sections.items():
    if marker not in text:
        continue
    start = text.index(marker)
    next_marker = text.find("=== ", start + 1)
    block = text[start:next_marker] if next_marker != -1 else text[start:]
    results[key] = parse_section(block.splitlines())

expected = {
    "initial": {
        "create_vikunja": 2 * count,
        "create_reminders": 3 * count,
        "update_vikunja": 0,
        "update_reminders": 0,
        "delete_vikunja": 0,
        "delete_reminders": 0,
        "conflicts": 0,
        "ambiguous": 0,
    },
    "post_apply": {
        "create_vikunja": 0,
        "create_reminders": 0,
        "update_vikunja": 0,
        "update_reminders": 0,
        "delete_vikunja": 0,
        "delete_reminders": 0,
        "conflicts": 0,
        "ambiguous": 0,
    },
    "conflicts": {
        "conflicts": 2 * count,
        "ambiguous": 0,
    },
}

def check(phase, got):
    exp = expected.get(phase, {})
    print(f"{phase}:")
    for key, exp_val in exp.items():
        got_val = got.get(key, 0)
        status = "OK" if got_val == exp_val else "MISMATCH"
        print(f"  {key} expected={exp_val} got={got_val} [{status}]")

for phase, got in results.items():
    check(phase, got)
PY
if [[ "${KEEP}" != "1" ]]; then
  echo "\n=== Cleanup ===" | tee -a "${REPORT_PATH}"
  run_step /tmp/seed_test_data --cleanup-env --state-path "${STATE_PATH}"
fi

echo "Report ready at ${REPORT_PATH}"

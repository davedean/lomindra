#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/tmp/RemindersProbe.app"
BIN_PATH="${APP_DIR}/Contents/MacOS/RemindersProbe"
INFO_PLIST_SRC="scripts/RemindersProbeInfo.plist"
INFO_PLIST_DEST="${APP_DIR}/Contents/Info.plist"

mkdir -p "${APP_DIR}/Contents/MacOS"
cp "${INFO_PLIST_SRC}" "${INFO_PLIST_DEST}"

swiftc -o "${BIN_PATH}" scripts/ekreminder_probe.swift
codesign -s - "${APP_DIR}"

open "${APP_DIR}"
echo "If prompted, grant Reminders access."
echo "Run the probe with:"
echo "${BIN_PATH}"

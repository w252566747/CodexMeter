#!/bin/zsh
# Runs CodexMeter only while the ChatGPT desktop app is running.
set -u

readonly CHATGPT_PROCESS="ChatGPT"
readonly METER_EXECUTABLE="/Applications/CodexMeter.app/Contents/MacOS/CodexMeter"
meter_pid=""

while true; do
  if pgrep -x "$CHATGPT_PROCESS" >/dev/null 2>&1; then
    if [[ -z "$meter_pid" ]] || ! kill -0 "$meter_pid" >/dev/null 2>&1; then
      "$METER_EXECUTABLE" >/dev/null 2>&1 &
      meter_pid=$!
    fi
  else
    if [[ -n "$meter_pid" ]] && kill -0 "$meter_pid" >/dev/null 2>&1; then
      kill -TERM "$meter_pid" >/dev/null 2>&1 || true
      wait "$meter_pid" 2>/dev/null || true
    fi
    meter_pid=""
  fi

  sleep 1
done

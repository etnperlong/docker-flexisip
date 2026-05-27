#!/bin/sh

set -eu

attempts=5
delay=5
backoff=2
max_delay=30

usage() {
  echo "Usage: retry.sh [--attempts N] [--delay SECONDS] [--backoff FACTOR] [--max-delay SECONDS] -- command [args...]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --attempts)
      attempts="$2"
      shift 2
      ;;
    --delay)
      delay="$2"
      shift 2
      ;;
    --backoff)
      backoff="$2"
      shift 2
      ;;
    --max-delay)
      max_delay="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      usage
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  usage
  exit 2
fi

attempt=1
current_delay="$delay"

while :; do
  echo "[retry] Attempt ${attempt}/${attempts}: $*"

  if "$@"; then
    if [ "$attempt" -gt 1 ]; then
      echo "[retry] Command succeeded on attempt ${attempt}."
    fi
    exit 0
  else
    exit_code=$?
  fi

  if [ "$attempt" -ge "$attempts" ]; then
    echo "[retry] Command failed after ${attempt} attempts (exit ${exit_code}): $*" >&2
    exit "$exit_code"
  fi

  echo "[retry] Command failed with exit ${exit_code}. Retrying in ${current_delay}s..." >&2
  sleep "$current_delay"

  attempt=$((attempt + 1))
  next_delay=$((current_delay * backoff))
  if [ "$next_delay" -gt "$max_delay" ]; then
    current_delay="$max_delay"
  else
    current_delay="$next_delay"
  fi
done

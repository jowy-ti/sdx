#!/usr/bin/env bash
# Run the message-delay experiment.
# Usage: ./run_trials.sh <promise_delay_ms> <vote_delay_ms> <timeout_ms> <repetitions>
set -euo pipefail
cd "$(dirname "$0")"
P=$1; V=$2; T=$3; R=$4
erlc -o ebin acceptor.erl proposer.erl run.erl order.erl
for i in $(seq 1 "$R"); do
  erl -noshell -pa ebin -run run main "$P" "$V" "$T"
done

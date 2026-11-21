#!/usr/bin/env bash
# Node-count experiment: acceptors and proposers.
set -euo pipefail
cd "$(dirname "$0")"
erlc -o ebin acceptor.erl proposer.erl run.erl order.erl 2>/dev/null
mkdir -p results
OUT=results/raw.csv
: > "$OUT"

one() { # series acceptors proposers reps
  local series=$1 a=$2 p=$3 reps=$4 i line
  for i in $(seq 1 "$reps"); do
    line=$(erl -noshell -pa ebin -run run main "$a" "$p" 2>/dev/null | grep '^RESULT,')
    echo "$series,$i,${line#RESULT,}" >> "$OUT"
  done
}

for a in 3 5 7 9; do
  one acceptors "$a" 3 10
done

for p in 1 3 5 7; do
  one proposers 5 "$p" 10
done

echo "done: $(wc -l < "$OUT") trials"

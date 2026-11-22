#!/usr/bin/env bash
# Large node-count run: acceptors/proposers up to 50.
set -euo pipefail
cd "$(dirname "$0")"
erlc -o ebin acceptor.erl proposer.erl run.erl order.erl 2>/dev/null
mkdir -p results
OUT=results/raw_large.csv
: > "$OUT"

one() { # series acceptors proposers reps
  local series=$1 a=$2 p=$3 reps=$4 i line
  for i in $(seq 1 "$reps"); do
    line=$(erl -noshell -pa ebin -run run main "$a" "$p" 2>/dev/null | grep '^RESULT,')
    echo "$series,$i,${line#RESULT,}" >> "$OUT"
    echo "done $series A=$a P=$p run=$i: ${line#RESULT,}"
  done
}

for a in 10 20 30 50; do
  one acceptors "$a" 3 5
done

for p in 10 20 30; do
  one proposers 5 "$p" 3
done
one proposers 5 50 2

one stress 50 50 1

echo "done: $(wc -l < "$OUT") trials"

#!/usr/bin/env bash
# Full experiment matrix for report section 2.1 (message delays).
set -euo pipefail
cd "$(dirname "$0")"
erlc -o ebin acceptor.erl proposer.erl run.erl order.erl 2>/dev/null
mkdir -p results
OUT=results/raw.csv
: > "$OUT"

one() { # series promise vote timeout rep
  local series=$1 p=$2 v=$3 t=$4 r=$5 i line
  for i in $(seq 1 "$r"); do
    line=$(erl -noshell -pa ebin -run run main "$p" "$v" "$t" 2>/dev/null | grep '^RESULT,')
    line=${line#RESULT,}
    echo "$series,$i,$line" >> "$OUT"
  done
}

# --- Main series: timeout fixed at the default 2000 ms -----------------------
for i in $(seq 1 10); do
  line=$(erl -noshell -pa ebin -run run main 0 0 2000 2>/dev/null | grep '^RESULT,')
  echo "baseline,$i,${line#RESULT,}" >> "$OUT"
done

for d in 250 500 750 1000 1500 1750 1900 2000 2500; do
  if [ "$d" -ge 1900 ]; then reps=10; else reps=5; fi
  one promise "$d" 0 2000 "$reps"
  one vote 0 "$d" 2000 "$reps"
  one both "$d" "$d" 2000 "$reps"
done

# --- Timeout series: both messages delayed ----------------------------------
for d in 500 1500 2500; do
  for t in 1000 2000 4000; do
    one timeout "$d" "$d" "$t" 5
  done
done
for i in $(seq 1 5); do
  line=$(erl -noshell -pa ebin -run run main 500 500 500 2>/dev/null | grep '^RESULT,')
  echo "timeout,$i,${line#RESULT,}" >> "$OUT"
done

echo "done: $(wc -l < "$OUT") trials"

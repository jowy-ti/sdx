# Paxy lab — agent workflow

## Context
- Seminar on Paxos in Erlang. Prompts: `Paxy.pdf`. Report: `paxy-seminar-report-template.tex`.
- Baseline code: `paxy-source-files/` — read-only reference.
- Status: 2.1 and 2.4 complete; 2.2, 2.3 and 2.5–2.7 pending.

## Rules
1. One exercise at a time. Edit only its report subsection.
2. Never modify `paxy-source-files/` or other sections.
3. Work in `experiments/<exercise>/` with a copy of the needed modules.
4. Make changes configurable; default behaviour must equal the baseline.
5. Run headlessly: GUI panels become sink processes; use a fresh Erlang VM per trial.
6. Fixed setup unless the exercise varies it: 5 acceptors, 3 proposers
   (sleeps 0/100/200 ms), timeout 2000 ms, backoff 10 ms.
7. At least 5 repetitions per point (10 near thresholds); use a fixed watchdog
   (e.g. 12 s) and report failures as `---`.
8. Save raw trials as CSV; generate tables from a script, not by hand.
9. Record: success, time to first decision, time until all decide, winning
   ballot, and maximum ballot.
10. Report style: short; tables at most 6 rows and 5 columns; no figure unless
    it adds real value; answer the prompt directly.
11. Distinguish safety from liveness. State per-phase conditions
    (e.g. `D < timeout`), and do not turn sample results into guarantees.
12. Compile after every edit and check that only the intended subsection
    changed. Preserve the template's CRLF line endings.

## Layout
```
experiments/<exercise>/
  acceptor.erl  proposer.erl  order.erl
  run.erl  run_all.sh  analyze.py
  results/raw.csv  results/table_*.tex
  README.md
```

## Commands
```sh
erlc -o ebin acceptor.erl proposer.erl run.erl order.erl
erl -noshell -pa ebin -run run main <promise_delay> <vote_delay> <timeout>
python3 analyze.py
pixi exec -c conda-forge tectonic --outdir build paxy-seminar-report-template.tex
```

## Checklist per exercise
- [ ] Baseline untouched
- [ ] Change configurable and off by default
- [ ] At least 5 runs per point, fresh VM
- [ ] Raw data saved
- [ ] Tables small and data-backed
- [ ] Safety/liveness stated
- [ ] Timeout and round definitions explicit
- [ ] Only intended subsection changed
- [ ] Report compiles without new warnings

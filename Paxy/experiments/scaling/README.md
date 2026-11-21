# Node-count experiment (report section 2.4)

Headless runs with a variable number of acceptors and proposers.

## Files

| File | Purpose |
|---|---|
| `acceptor.erl` | Baseline acceptor; counts protocol messages in ETS |
| `proposer.erl` | Baseline proposer; sends a richer `done` message |
| `order.erl` | Unmodified sequence-number module |
| `run.erl` | One trial: `run main <acceptors> <proposers>` |
| `run_all.sh` | 10 runs per configuration -> `results/raw.csv` |
| `analyze.py` | Aggregates trials -> `results/table_*.tex` |

## Configuration

- Acceptors: 3, 5, 7, 9 (with 3 proposers).
- Proposers: 1, 3, 5, 7 (with 5 acceptors).
- All proposers start together (sleep 0), timeout 2000 ms, no message delays.
- Fresh Erlang VM per trial; GUI panels replaced by a sink process.
- 10 runs per point; watchdog 30 s.

## Reproduce

```sh
./run_all.sh
python3 analyze.py
```

A single trial:

```sh
erlc -o ebin acceptor.erl proposer.erl run.erl order.erl
erl -noshell -pa ebin -run run main 5 3
```

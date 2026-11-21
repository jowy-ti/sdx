# Message-delay experiment (report section 2.1)

Headless reproduction of the Paxy protocol with configurable delays on the
acceptors' `promise` and `vote` replies.

## Files

| File | Purpose |
|---|---|
| `acceptor.erl` | Acceptor with `send_delayed/3`; delay read from `paxy_delays` |
| `proposer.erl` | Proposer with runtime timeout (`paxy_timeout`) and richer `done` message |
| `order.erl` | Unmodified sequence-number module |
| `run.erl` | Starts 5 acceptors + 3 proposers (sink panels) and prints one CSV line |
| `run_all.sh` | Full trial matrix -> `results/raw.csv` |
| `analyze.py` | Aggregates trials -> tables and summary CSVs |

## Reproduce

```sh
./run_all.sh          # about 20 minutes
python3 analyze.py    # writes results/table_*.tex
```

A single trial:

```sh
erlc -o ebin acceptor.erl proposer.erl run.erl order.erl
erl -noshell -pa ebin -run run main 500 0 2000   # promise=500, vote=0, timeout=2000
```

The output line is

```
RESULT,status,promise_delay,vote_delay,timeout,t_first,t_all,winner_round,max_round,consensus,missing
```

where `t_first`/`t_all` are milliseconds from starting the proposers, and
rounds are the `{counter, proposer}` tuples printed by Paxy. A trial with no
decision after 12 s is reported as `timeout`.

## Method notes

* The acceptor updates its state when the request arrives and delays only the
  reply, so the delay models network latency.
* The protocol, timeout (2000 ms) and backoff (10 ms) are unmodified unless
  `paxy_timeout` is set (used only for the timeout study).
* GUI panels are replaced by sink processes, so results do not depend on the
  display.
* Each trial uses a fresh Erlang VM to avoid registered names, timers and
  stale messages leaking across runs.

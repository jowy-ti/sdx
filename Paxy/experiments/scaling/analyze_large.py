#!/usr/bin/env python3
"""Summarise the large node-count run (results/raw_large.csv)."""
import csv, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "results", "raw_large.csv")
OUT = os.path.join(HERE, "results", "summary_large.csv")

ROW_RE = re.compile(
    r"^([^,]+),(\d+),([^,]+),(\d+),(\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),(\d+),([^,]+),(\d+)$")


def load():
    rows = []
    with open(RAW) as f:
        for line in f:
            m = ROW_RE.match(line.strip())
            if not m:
                continue
            g = m.groups()
            rows.append(dict(series=g[0], status=g[2], a=int(g[3]), p=int(g[4]),
                             t_first=int(g[5]), t_all=int(g[6]), win=int(g[7]),
                             mx=int(g[8]), msgs=int(g[9]), consensus=g[10]))
    return rows


def mean(xs):
    return statistics.mean(xs) if xs else 0.0


def main():
    rows = load()
    out = []
    for series in ("acceptors", "proposers", "stress"):
        by = {}
        for r in rows:
            if r["series"] == series:
                by.setdefault((r["a"], r["p"]), []).append(r)
        for (a, p), rs in sorted(by.items()):
            ok = [r for r in rs if r["status"] == "ok"]
            s = dict(series=series, a=a, p=p, n=len(rs), ok=len(ok),
                     t_first=mean([r["t_first"] for r in ok]),
                     t_all=mean([r["t_all"] for r in ok]),
                     win=mean([r["win"] for r in ok]),
                     mx=mean([r["mx"] for r in ok]),
                     msgs=mean([r["msgs"] for r in ok]))
            out.append(s)
            print("%-9s A=%2d P=%2d n=%d ok=%d Tcons=%5.0f Tall=%7.0f "
                  "win=%.0f max=%.1f msgs=%7.0f"
                  % (series, a, p, s["n"], s["ok"], s["t_first"], s["t_all"],
                     s["win"], s["mx"], s["msgs"]))
    with open(OUT, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["series", "acceptors", "proposers", "n", "ok",
                    "t_first", "t_all", "winner_round", "max_round", "messages"])
        for s in out:
            w.writerow([s["series"], s["a"], s["p"], s["n"], s["ok"],
                        round(s["t_first"]), round(s["t_all"]),
                        round(s["win"], 1), round(s["mx"], 1), round(s["msgs"])])


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Aggregate the node-count trials and emit the two compact report tables."""
import csv, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "results", "raw.csv")
OUT = os.path.join(HERE, "results")

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
            rows.append(dict(series=g[0], rep=int(g[1]), status=g[2],
                             a=int(g[3]), p=int(g[4]),
                             t_first=int(g[5]), t_all=int(g[6]),
                             win=int(g[7]), mx=int(g[8]),
                             msgs=int(g[9]), consensus=g[10], missing=int(g[11])))
    return rows


def mean(xs):
    return statistics.mean(xs) if xs else 0.0


def group(rows, series):
    out = {}
    for r in rows:
        if r["series"] != series:
            continue
        key = (r["a"], r["p"])
        out.setdefault(key, []).append(r)
    return out


def summarize(rows, series):
    res = []
    for (a, p), rs in sorted(group(rows, series).items()):
        ok = [r for r in rs if r["status"] == "ok"]
        res.append(dict(a=a, p=p, n=len(rs), ok=len(ok),
                        t_first=mean([r["t_first"] for r in ok]),
                        t_all=mean([r["t_all"] for r in ok]),
                        win=mean([r["win"] for r in ok]),
                        mx=mean([r["mx"] for r in ok]),
                        msgs=mean([r["msgs"] for r in ok])))
        s = res[-1]
        print("%s A=%d P=%d n=%d ok=%d Tfirst=%.0f Tall=%.0f win=%.1f max=%.1f msgs=%.0f"
              % (series, a, p, s["n"], s["ok"], s["t_first"], s["t_all"],
                 s["win"], s["mx"], s["msgs"]))
    return res


def fmt_num(x):
    return "%.0f" % x


def fmt_rounds(w, m):
    return "%.1f / %.1f" % (w, m)


def main():
    rows = load()
    acc = summarize(rows, "acceptors")
    pro = summarize(rows, "proposers")

    with open(os.path.join(OUT, "summary.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["series", "acceptors", "proposers", "n", "ok",
                    "t_first", "t_all", "winner_round", "max_round", "messages"])
        for series, data in (("acceptors", acc), ("proposers", pro)):
            for s in data:
                w.writerow([series, s["a"], s["p"], s["n"], s["ok"],
                            round(s["t_first"]), round(s["t_all"]),
                            round(s["win"], 1), round(s["mx"], 1),
                            round(s["msgs"])])

    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\small")
    lines.append("\\begin{tabular}{c|c|c|c|c}")
    lines.append("\\hline")
    lines.append("Acceptors & $f$ & $T_{\\mathrm{cons}}$ (ms) & Winner/max rounds & Messages \\\\")
    lines.append("\\hline")
    for s in acc:
        lines.append("%d & %d & %s & %s & %s \\\\" % (
            s["a"], (s["a"] - 1) // 2, fmt_num(s["t_first"]),
            fmt_rounds(s["win"], s["mx"]), fmt_num(s["msgs"])))
    lines.append("\\hline")
    lines.append("\\end{tabular}")
    lines.append("\\caption{Number of acceptors (3 proposers, 10 runs, timeout 2000~ms). "
                 "$f=(A-1)/2$ is the number of crashed acceptors tolerated. Rounds are "
                 "winner/maximum; messages are the total per run.}")
    lines.append("\\label{tab:acceptors}")
    lines.append("\\end{table}")
    with open(os.path.join(OUT, "table_acceptors.tex"), "w") as f:
        f.write("\n".join(lines) + "\n")

    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\small")
    lines.append("\\begin{tabular}{c|c|c|c|c}")
    lines.append("\\hline")
    lines.append("Proposers & $T_{\\mathrm{cons}}$ (ms) & $T_{\\mathrm{all}}$ (ms) & Winner/max rounds & Messages \\\\")
    lines.append("\\hline")
    for s in pro:
        lines.append("%d & %s & %s & %s & %s \\\\" % (
            s["p"], fmt_num(s["t_first"]), fmt_num(s["t_all"]),
            fmt_rounds(s["win"], s["mx"]), fmt_num(s["msgs"])))
    lines.append("\\hline")
    lines.append("\\end{tabular}")
    lines.append("\\caption{Number of proposers (5 acceptors, 10 runs, timeout 2000~ms). "
                 "$T_{\\mathrm{all}}$ is the time until all proposers decide; rounds are "
                 "winner/maximum; messages are the total per run.}")
    lines.append("\\label{tab:proposers}")
    lines.append("\\end{table}")
    with open(os.path.join(OUT, "table_proposers.tex"), "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()

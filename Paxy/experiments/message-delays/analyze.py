#!/usr/bin/env python3
"""Analyse the raw trials of the message-delay experiment and emit:
  - results/summary_main.csv
  - results/summary_timeout.csv
  - results/table_main.tex
  - results/table_timeout.tex
"""
import csv, os, re, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "results", "raw.csv")
OUT = os.path.join(HERE, "results")



def ballot(t):
    m = re.match(r"\{(\d+),", t or "")
    return int(m.group(1)) + 1 if m else None


ROW_RE = re.compile(
    r"^([^,]+),(\d+),([^,]+),(\d+),(\d+),(\d+),(-?\d+),(-?\d+),"
    r"(\{[^}]*\}|-?\d+),(\{[^}]*\}|-?\d+),([^,]+),(\d+)$")


def load():
    rows = []
    with open(RAW) as f:
        for line in f:
            m = ROW_RE.match(line.strip())
            if not m:
                continue
            (series, rep, status, promise, vote, timeout,
             t_first, t_all, win_raw, mx_raw, consensus, missing) = m.groups()
            rows.append(dict(series=series, rep=int(rep), status=status,
                             promise=int(promise), vote=int(vote), timeout=int(timeout),
                             t_first=int(t_first), t_all=int(t_all),
                             win=ballot(win_raw), mx=ballot(mx_raw),
                             consensus=consensus, missing=int(missing)))
    return rows


def stats(vals):
    if not vals:
        return None, None
    if len(vals) == 1:
        return float(vals[0]), 0.0
    return statistics.mean(vals), statistics.stdev(vals)


def group(rows, key):
    g = {}
    for r in rows:
        g.setdefault(key(r), []).append(r)
    return g


def summarize(rows, key, label):
    out = []
    for k, rs in sorted(group(rows, key).items()):
        decided = [r for r in rs if r["t_first"] >= 0]
        full = [r for r in rs if r["missing"] == 0]
        tf = [r["t_first"] for r in decided]
        ta = [r["t_all"] for r in full]
        wins = [r["win"] for r in decided if r["win"]]
        mxs = [r["mx"] for r in decided if r["mx"]]
        m_tf, s_tf = stats(tf)
        m_ta, s_ta = stats(ta)
        out.append(dict(key=k, n=len(rs), ok=len(decided), full=len(full),
                        t_first=m_tf, sd_first=s_tf, t_all=m_ta, sd_all=s_ta,
                        win=stats(wins)[0], mx=stats(mxs)[0]))
        print(label, k, "n=%d decided=%d full=%d" % (len(rs), len(decided), len(full)),
              "T_first=%s" % (round(m_tf) if m_tf is not None else "-"),
              "T_all=%s" % (round(m_ta) if m_ta is not None else "-"))
    return out


def main():
    rows = load()
    main_rows = [r for r in rows if r["series"] in ("baseline", "promise", "vote", "both")]
    timeout_rows = [r for r in rows if r["series"] == "timeout"]

    def mode_of(r):
        if r["series"] == "baseline":
            return "baseline"
        return r["series"]

    def delay_of(r):
        if r["mode"] == "baseline":
            return 0
        if r["mode"] == "promise":
            return r["promise"]
        if r["mode"] == "vote":
            return r["vote"]
        return r["promise"]

    main_rows = [dict(r, mode=mode_of(r)) for r in main_rows]
    main_sum = summarize(main_rows, lambda r: (r["mode"], delay_of(r)), "main")
    time_sum = summarize(timeout_rows, lambda r: (r["promise"], r["timeout"]), "timeout")

    # CSV summaries
    with open(os.path.join(OUT, "summary_main.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["mode", "delay", "n", "ok", "t_first", "sd_first", "t_all", "sd_all", "win", "max"])
        for s in main_sum:
            mode, delay = s["key"]
            w.writerow([mode, delay, s["n"], s["ok"], s["t_first"], s["sd_first"],
                        s["t_all"], s["sd_all"], s["win"], s["mx"]])
    with open(os.path.join(OUT, "summary_timeout.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["delay", "timeout", "n", "ok", "t_first", "sd_first", "t_all", "sd_all"])
        for s in time_sum:
            delay, tmo = s["key"]
            w.writerow([delay, tmo, s["n"], s["ok"], s["t_first"], s["sd_first"],
                        s["t_all"], s["sd_all"]])

    # ---- LaTeX main table -------------------------------------------------
    by = {(s["key"][0], s["key"][1]): s for s in main_sum}

    def cell(s):
        if s is None or s["ok"] == 0 or s["t_first"] is None:
            return "---"
        return "%d" % round(s["t_first"])

    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\small")
    lines.append("\\begin{tabular}{r|r|r|r}")
    lines.append("\\hline")
    lines.append("Delay (ms) & Promise & Vote & Both \\\\")
    lines.append("\\hline")
    for d in (0, 500, 1000, 1500, 2000, 2500):
        if d == 0:
            base = by.get(("baseline", 0))
            row = [cell(base), cell(base), cell(base)]
        else:
            row = [cell(by.get((m, d))) for m in ("promise", "vote", "both")]
        lines.append("%d & %s & %s & %s \\\\" % (d, row[0], row[1], row[2]))
    lines.append("\\hline")
    lines.append("\\end{tabular}")
    lines.append("\\caption{Consensus time (ms), mean of successful runs (standard deviation "
                 "$\\le 10$\\,ms). $D$ is the one-way delay of the promise and/or vote reply; "
                 "\\texttt{---} means no decision within 12~s. Timeout 2000~ms.}")
    lines.append("\\label{tab:delays}")
    lines.append("\\end{table}")
    with open(os.path.join(OUT, "table_main.tex"), "w") as f:
        f.write("\n".join(lines) + "\n")

    # ---- LaTeX timeout table ---------------------------------------------
    tby = {s["key"]: s for s in time_sum}
    lines = []
    lines.append("\\begin{table}[htbp]")
    lines.append("\\centering")
    lines.append("\\small")
    lines.append("\\begin{tabular}{c|c|c|c|c}")
    lines.append("\\hline")
    lines.append("Delay (ms) & $t=500$ & $t=1000$ & $t=2000$ & $t=4000$ \\\\")
    lines.append("\\hline")
    for d in (500, 1500, 2500):
        row = [cell(tby.get((d, t))) for t in (500, 1000, 2000, 4000)]
        lines.append("%d & %s & %s & %s & %s \\\\" % (d, *row))
    lines.append("\\hline")
    lines.append("\\end{tabular}")
    lines.append("\\caption{Consensus time (ms) when both messages are delayed by $D$, for different "
                 "proposer timeouts $t$; \\texttt{---} means no decision within 12~s. Termination "
                 "requires $D<t$, not $2D<t$.}")
    lines.append("\\label{tab:timeout}")
    lines.append("\\end{table}")
    with open(os.path.join(OUT, "table_timeout.tex"), "w") as f:
        f.write("\n".join(lines) + "\n")



if __name__ == "__main__":
    main()

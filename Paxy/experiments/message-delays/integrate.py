#!/usr/bin/env python3
"""Insert the generated section 2.1 and tables into the report template."""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
TEX = os.path.join(ROOT, "paxy-seminar-report-template.tex")
SECTION = os.path.join(HERE, "section21.tex")
MAIN_TABLE = os.path.join(HERE, "results", "table_main.tex")
TIMEOUT_TABLE = os.path.join(HERE, "results", "table_timeout.tex")

with open(SECTION) as f:
    section = f.read()
with open(MAIN_TABLE) as f:
    main_table = f.read().strip()
with open(TIMEOUT_TABLE) as f:
    timeout_table = f.read().strip()

section = section.replace("%%TABLE_MAIN%%", main_table)
section = section.replace("%%TABLE_TIMEOUT%%", timeout_table)

with open(TEX, newline="") as f:
    tex = f.read()
tex = tex.replace("\r\n", "\n").replace("\r", "\n")
start = tex.index(r"\subsection{Message delays}")
end = tex.index(r"\subsection{\texttt{sorry} messages}")
tex = tex[:start] + section.rstrip() + "\n\n" + tex[end:]

with open(TEX, "w", newline="") as f:
    f.write(tex.replace("\n", "\r\n"))
print("updated", TEX)

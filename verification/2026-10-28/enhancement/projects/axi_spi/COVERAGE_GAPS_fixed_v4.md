# AXI SPI remaining coverage

Native `reports/enhanced_final/urg_report/{hierarchy,modinfo,grpinfo,asserts}.txt` is authoritative. FC legacy7/7 and new36/36 mean these43defined bins only.

| Metric / behavior | Remaining | Interpretation / next meaningful target |
|---|---|---|
| Line |0/153 |100% measured; not proof of feature completeness |
| Condition |7/54 |BREADY/RREADY already high before VALID not stimulated; AR gating combinations need reachability review |
| Branch |1/49 |Exhaustive2-bit register index default, apparently unreachable; no formal exclusion claimed |
| FSM |LOAD→IDLE |Target reset precisely during SPI LOAD, no need repeat all random seeds |
| Toggle |254/1296 |Classify tied/unused/high-bit fields against meaningful control/data toggles before adding tests |
| Functional model |0unhit/43 |Reset/busySTART verified by dedicated checker but not functional coverpoints; no PROT/address alignment/divider sweep/cross coverage |
| Architecture limits |Single peripheral, Mode0, onebyte |No AXI burst/full, other SPI modes, board timing or synthesis/CDC claim |

Historical/new DUT coverage percentages use changed RTL and changed denominators; report both, do not imply identical-scope numerators. Native package RAL assertions with0attempts are not verified; five added protocol properties have actual nonzero antecedents and native real successes.

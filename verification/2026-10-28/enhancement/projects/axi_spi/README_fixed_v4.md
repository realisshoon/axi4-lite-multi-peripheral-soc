# AXI4-Lite SPI verification enhancement

Original source remains unchanged at `/home/pedu36/workspace/20260628_axi4_lite_spi_uvm`. This copy contains the preserved `baseline/rtl`, `baseline/tb`, enhanced UVM under `tb/enhanced`, minimally corrected AXI register RTL, actual VCS/URG results in `runs/` and `reports/`, and links to trace-driven portfolio evidence.

Reproduce with `/usr/bin/python3.11 scripts/run.py compile <new_build_name>` then `/usr/bin/python3.11 scripts/run.py sim <build> <new_run_name> directed 0 1 wave` (EDA license network access required). All EDA launches pass through the shared two-slot resource gate. Never reuse an existing run name. `scripts/final_regression.py` records the final fixed_v4 sequence; choose new run names before rerunning. `filelist_original_rtl.f` compiles preserved old RTL for actual before/fix failure reproduction. Existing Makefile is preserved for reference and its clean target was never executed.

See TESTPLAN.md, TROUBLESHOOTING.md, results.json, coverage.json and source_diff.patch. Counts are separate for tests, seeds, register completions, SPI transfers, checker comparisons, reset-aborted work, and SVA antecedents. Final canonical regression consists of final_large_s11..final_large_s20 only; other stages/failures remain separately indexed.

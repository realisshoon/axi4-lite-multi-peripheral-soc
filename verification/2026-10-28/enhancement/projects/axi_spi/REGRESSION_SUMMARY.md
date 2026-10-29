# AXI SPI measured result

10 final seeds11..20: **12,320 completed register operations;38,560 checks;110 completed SPI transfers;55,674 nonvacuous stability antecedents;0 unexpected UVM_ERROR/FATAL/assertion failures;pending0**. One UVM test class is reused; this is10 seeded test executions, not12,320 independent tests.

Per-seed logs/metadata: `runs/final_v5_large_s11` through `runs/final_v5_large_s20`. Each has1,232 completed register operations,3,856 checks,11 SPI completions and1 explicitly reset-aborted SPI attempt. Mid-SPI/unmatchedAW/unmatchedW/stalledB/stalledR reset scenarios deliberately abort incomplete work and reset reference state. See `results.json` for all completed/accepted/aborted counters and prior failure reproduction rows.

Stage progression: final_v5_smoke_s1=15ops/64checks;final_v5_directed_s1=202ops/706checks;final_v5_small_s3=302ops/1006checks;final_v5_intermediate_s4=1232ops/3856checks. Additional `strobe_sideeffects_s1_retry`=26ops/98checks checks masked START/DONEclear. All PASS. Older fixed_v2/v3 runs retained, not added to canonical10-seed totals.

Original failure reproductions are separate: WSTRB before2errors → after0;read-capacity beforetimeout/fatal1 → after6reads/28checks PASS. Operational executable-not-found launch has no simulation log and is excluded.

Final collector review: canonical fixed_v5 repeats the same10seeds after pairing actual AR address to R. Counts unchanged;110actualSR-DONEsamples, 59non-SR-bit1 reads excluded from DONE coverage. `fixed_v4` prior artifacts remain separate. Final targeted=`runs/final_v5_strobe_sideeffects_s1`26ops/98checks PASS.

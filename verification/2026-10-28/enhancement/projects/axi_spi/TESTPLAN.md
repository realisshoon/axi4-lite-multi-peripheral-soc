# AXI4-Lite SPI enhancement testplan

Original source: `/home/pedu36/workspace/20260628_axi4_lite_spi_uvm`; all modifications are in this project copy. UVM 1.2/VCS W-2024.09-SP2. Register specification is derived from original RTL: CR 0x0 (stored START[0], CLR_STATUS[1], divider[15:8]), TX 0x4, RX 0x8 read-only, SR 0xc read-only (busy[0], sticky done[1]). START/CLR bits are stored, not self-clearing. One 8-bit Mode-0 transfer per accepted START while idle; no claim for other SPI modes/AXI bursts.

| Objective | Implemented stimulus | Independent checker / expected behavior | Coverage / timeout |
|---|---|---|---|
| Reset defaults | Read all four words after initial/reset-in-flight | Reference CR=0x6400/TX=RX=SR=0 | register×read; 128-cycle channel watchdog |
| Byte writes/RO | all 16 WSTRB masks, random 32-bit data; write RX/SR | Passive AW/W join; per-byte reference merge; RO ignores writes | 16 masks; addr×RW |
| Command side effects | Masked START and CLR_STATUS, followed by legitimate START/clear | No unexpected pin transfer; DONE stays set for masked clear | targeted `strobe_sideeffects` (no new bins added) |
| Independent channels | simultaneous, AW before W, W before AW; gap1..8 | Count actual AW/W/B; pending queues empty; no duplicates | 3 order bins; 128-cycle timeout |
| Response backpressure | B/R stall0..9; next requests offered before prior response accepted | SVA VALID/payload stable; pending/read reference queue; next response must arrive | stall bins none/short/long; five SVA antecedent counters |
| Lost-read reproduction | Offer second AR while first R is stalled | Two accepted AR must produce two correct R; original fails bounded timeout | `read_capacity`; expected original failure, fixed PASS |
| Reset abort/recovery | Mid-SPI; unmatched AW; unmatched W; stalled B; stalled R | Explicit reset-aborted accounting, reference reset, next transfer checked | no reset functional bins; demonstrated by directed logs/counters |
| SPI end-to-end | TX 00/FF/A5/5A,55,81 and random; MISO independent pattern/random; divider0,2..5,random1..15 | Reconstruct MOSI/MISO at actual rising SCLK; compare against TX model and responder byte; RXDATA must match pin MISO | existing TXDATA/START/DONE/complete CGs retained unchanged |
| Busy START | START again while CS active | Current transfer preserved; no queued extra output; pending queue empty | directed branch/check, not separate coverpoint |
| Multiseed stress | 10 seeds11..20×500 random write/read pairs + directed scenarios and five random SPI transfers/seed | UVM errors/fatals0, five assertions failures0, all check conditions pass, accounting drained | 12,320 completed register transactions, not independent tests |

Random generation uses `$urandom_range` with explicit procedural constraints: 4 aligned addresses, all masks0..15, all orderings0..2, delays1..8, stalls0..9. Random CR data has bits[7:0]=0 to avoid unconstrained START while separately testing START semantics in directed/transfer sequences. This is bounded random stimulus; it does not use SV `randomize()` constraints.

Checker architecture: `enhanced_test → enhanced_sequence → uvm_sequencer → enhanced_driver → axi_lite_if`. `enhanced_scoreboard` contains a passive per-clock AW/W/AR/R monitor plus an independent register model and a passive SPI pin monitor; it is deliberately not described as a separate agent/monitor class. `spi_axi_coverage` is the original four-CG collector; `enhanced_scoreboard.protocol_cg` is new. No fabricated agent hierarchy.

Counts: driver completed operations include only full B/R responses. Monitor writes include one intentionally reset-aborted write; unmatched AW/W and one aborted AR are separately excluded from end accounting. Consequently accepted AW/W, committed writes, B completions and driver completions are not interchangeable. Five stability properties use native SVA and explicit nonvacuous antecedent counters; native URG additionally reports real successes per property.

Open limits: AWPROT/ARPROT only0; only aligned word addresses; no concurrent independent read/write threads beyond explicit same-channel outstanding stress; no random reset-cycle sweep; no SPI LOAD-state reset target; no full8-bit divider sweep; no hardware IO timing/electrical claim. Unsupported AXI full/burst and SPI modes1/2/3 are not claimed.

Collector adapter validation: fixed_v5 carries the actual AR address alongside reference expected RDATA. Both queues drain/reset together. DONE functional samples require paired SR address0xc, not any RDATA with bit1 set. See `COLLECTOR_RESULT` counters in every final_v5 log.

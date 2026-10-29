# Actual troubleshooting records

| Issue | Observation / confirmed cause | Working-copy fix | Same-condition evidence |
|---|---|---|---|
| Original WSTRB ignored | seed1 zero mask: expected11223344, actualDEADBEEF; partial mask5: expected11FE33BE, actualCAFEBABE. Original `S_AXI_WSTRB` unused in all register writes. | Byte lane merge uses latched WSTRB; START/CLR effects require low-byte strobe. | `runs/before_wstrb_trace/`:2UVM_ERROR; `runs/after_wstrb_trace/`:34/34 checks,0errors; both real VCD/CSV |
| Original accepted AR lost while R stalled | A second AR is handshaken while RVALID is occupied, but original read-data logic requires !RVALID and drops the request. Actual `pipelined R lost/timeout`, UVM_FATAL1. | ARREADY must not accept new address while R response occupied. | `runs/before_read_capacity/`:fatal/timeout; `runs/after_read_capacity/`:6complete reads/28checks PASS, actual VCD/CSV |
| Testbench synchronized SPI slave too slow | First enhanced smoke divider2 RXDATA=2D, expected/pin reconstructed5A. Old response model delays CS/SCLK through2..3 system-clock synchronizers, so MISO changes at master's sampling boundary. Confirmed by source/trace. | Only TB responder replaced with pin-edge Mode0 responder: preload on CS assertion, next MISO on falling SCLK. Checker/expected bytes unchanged. | `runs/smoke_s1/`:one mismatch (earliest VCD empty, log retained); `runs/smoke2_s1/`:64/64checks PASS,14KB native VCD/CSV. Final directed includes divider0. |
| AW/W only jointly accepted | Original held-valid delayed-order requests are AXI legal and work; no assertion of protocol bug from simultaneous-VALID requirement alone. | One-entry independent AW and W buffers added for independent acceptance and reset-abort checks. | `runs/final_directed_s1/` actual AW/W pending/stall traces; full multiseed PASS |
| VCD initially empty | `$dumpvars(0)` called within an unnamed nested scope dumped no DUT signals. | Explicit `$dumpvars(1,tb_top);$dumpvars(0,tb_top.dut)` plus raw half-cycle signal CSV. | early empty VCDs retained; `before_wstrb_trace`,`after_wstrb_trace`,`before_read_capacity`,`after_read_capacity`,`final_directed_s1` contain actual DUT values |
| Operational launch before compile completed | `runs/strobe_sideeffects_s1/console.log` has executable-not-found; no simulation happened. | Waited for compile completion; separate retry directory. | `strobe_sideeffects_s1_retry`; operational failure excluded from DUT regression totals, retained |

All original failures above are **new reproductions of the preserved old source**, not historical failure logs from the original team. Scope and fixes are attributable to this enhancement session, not automatically to the user's past individual contribution.

Portfolio four-line records:

문제: AXI WSTRB=0/부분 쓰기에서도 전체 레지스터 값이 변경됨.
원인: 원본 register logic에서 WSTRB 미사용.
해결: 작업본에 byte enable 및 START/CLR_STATUS low-byte gating 구현.
검증: 동일 seed 재현 2 mismatches → 34/34 checks PASS; 실제 before/after CSV/VCD와 10-seed regression 보존.

문제: RREADY stall 중 수락한 두 번째 AR의 응답이 사라짐.
원인: ARREADY는 주소를 수락하지만 RVALID pending 조건으로 R 생성이 생략됨.
해결: 단일 outstanding read 용량에 맞춰 ARREADY를 gate.
검증: 동일 read_capacity 원본 timeout/UVM_FATAL1 → 수정본6 reads/28 checks PASS; 실제 파형 보존.

문제: 빠른 divider에서 기존 SPI slave 모델의 MISO 응답이 늦음.
원인: testbench 모델 내부 시스템 클록 동기화 지연.
해결: Mode0 pin-edge responder로 교체하고 독립 pin checker 유지.
검증: divider2 mismatch → smoke64/64 PASS; 최소 divider0도 directed PASS.

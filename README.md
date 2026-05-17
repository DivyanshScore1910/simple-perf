# SIMPLE-PERF
Single bash script for performance measurements and some hints, for CPU.
**NOTE**: Currently optimized on Intel Xeon 4th Gen CPUs only.

## GEMM Hardware Profile
```bash
$# bash ./perf_tool.sh --profile gemm --output gemm_hw --run <gemm_binary> [args...]
$# bash ./perf_tool.sh --visualize --agent --input gemm_hw
```

The GEMM profile records cache hit rates, AMX busy cycles, execution-port utilization, DRAM read/write bandwidth, and unhalted/reference cycle ratios where the local PMU exposes those events. It uses system-wide `perf stat -a` while the command runs for uncore DRAM/topdown counters.

## Features
```bash
$# bash ./perf_tool.sh --help
perf_tool.sh - Advanced perf profiling tool for performance analysis

USAGE:
  /home/sdp/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output <name> --run <executable> [args...]
  /home/sdp/divyansh/simple-perf/perf_tool.sh --visualize --input <name>
  /home/sdp/divyansh/simple-perf/perf_tool.sh --compare <baseline> <optimized>
  /home/sdp/divyansh/simple-perf/perf_tool.sh --help

OPTIONS:
  --record-cache-metrics    Record comprehensive performance metrics
  --output <name>           Output file name (auto-suffixed if exists)
  --run <executable>        Executable to profile (followed by its arguments)
  --visualize               Display metrics with analysis and insights
  --input <name>            Input file name to visualize
  --no-insights             Skip the automated insights section
  --cache-only              Record only cache-related events (L1/L2/L3, stalls, memory BW)
  --profile gemm            Record GEMM-focused core, AMX, port, CPU, and DRAM events
  --agent                   Render simple markdown tables for agent/code parsing
  --compare <base> <opt>    Compare two metric files side-by-side
  --help                    Show this help message

METRICS RECORDED:

  Cache Metrics:
    L1 Cache:   L1-dcache-loads, L1-dcache-load-misses, L1-dcache-stores
                L1-icache-load-misses
    L2 Cache:   l2_rqsts.references, l2_rqsts.miss
    L3/LLC:     LLC-loads, LLC-load-misses, LLC-stores, LLC-store-misses
    Overall:    cache-references, cache-misses

  Stall Analysis:
    cycle_activity.stalls_total, stalls_mem_any, stalls_l1d_miss
    cycle_activity.stalls_l2_miss, stalls_l3_miss

  Memory Bandwidth:
    offcore_requests.data_rd, offcore_requests.demand_data_rd

  Floating Point:
    fp_arith_inst_retired.scalar_single, scalar_double
    fp_arith_inst_retired.128b_packed, 256b_packed, 512b_packed

  Top-Down Analysis (TMA):
    Disabled by default for per-process profiling (requires system-wide mode)

  Other:
    Branch:     branch-instructions, branch-misses
    TLB:        dTLB-load-misses, iTLB-load-misses
    CPU:        cycles, instructions

EXAMPLES:
  # Record metrics for a GEMM test
  /home/sdp/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output gemm_metrics --run ./gemm_vtune_test 1

  # Visualize metrics with insights
  /home/sdp/divyansh/simple-perf/perf_tool.sh --visualize --input gemm_metrics

  # Record only cache metrics (exclude Branch, TLB, CPU, FLOPs, TMA)
  /home/sdp/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --cache-only --output cache_metrics --run ./gemm_vtune_test 1

  # Compare baseline vs optimized
  /home/sdp/divyansh/simple-perf/perf_tool.sh --compare baseline optimized

  # GEMM hardware profile with markdown output
  /home/sdp/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --profile gemm --output gemm_hw --run ./gemm_vtune_test 1
  /home/sdp/divyansh/simple-perf/perf_tool.sh --visualize --agent --input gemm_hw

  # With environment variables
  export LD_PRELOAD=/path/to/libgomp.so
  export OMP_NUM_THREADS=56
  /home/sdp/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output test --run ./my_program

```

## RECORD
```bash
$# bash ./perf_tool.sh --record-cache-metrics --output readme_baseline_942092 --run /home/sdp/divyansh/score_engine/build/score_gemm/score_gemm --m 64 --n 64 --k 64 --iters 5 --warmup 1 --no-check
══════════════════════════════════════════════════════════════
            Perf Performance Metrics Recording
══════════════════════════════════════════════════════════════

Output file: readme_baseline_942092.txt
Command: /home/sdp/divyansh/score_engine/build/score_gemm/score_gemm --m 64 --n 64 --k 64 --iters 5 --warmup 1 --no-check

Environment:
  LD_PRELOAD=<not set>
  OMP_NUM_THREADS=<not set>

Events being recorded:
  Core: 18 events (cache, branch, TLB, CPU)
  Stall: 5 events (cycle stall analysis)
  Memory: 2 events (bandwidth)
  FLOPs: 8 events (floating point)
  TMA: 0 events (top-down analysis)
Skipped unsupported events: l2_rqsts.references l2_rqsts.miss cycle_activity.stalls_total cycle_activity.cycles_mem_any cycle_activity.stalls_l1d_miss cycle_activity.stalls_l2_miss cycle_activity.stalls_l3_miss offcore_requests.data_rd offcore_requests.demand_data_rd fp_arith_inst_retired.scalar_single fp_arith_inst_retired.scalar_double fp_arith_inst_retired.128b_packed_single fp_arith_inst_retired.256b_packed_single fp_arith_inst_retired.512b_packed_single fp_arith_inst_retired.128b_packed_double fp_arith_inst_retired.256b_packed_double fp_arith_inst_retired.512b_packed_double

Starting perf stat...

score_gemm: M=64 N=64 K=64 threads=512 mode=hot iters=5 warmup=1 skip_iters=0 measured_iters=5 layers=1 packed_b_bytes=8192 cache_clear_bytes=234881024 avg_ms=9.193 median_ms=8.965 avg_gflops=0.057 median_gflops=0.058 checksum=1879816300894911315

Recording complete!
Metrics saved to: readme_baseline_942092.txt

To visualize: bash /home/sdp/divyansh/simple-perf/perf_tool.sh --visualize --input readme_baseline_942092
```

## VISUALIZE
```bash
$# bash ./perf_tool.sh --visualize --input readme_baseline_942092
════════════════════════════════════════════════════════════════════════════════
                         Performance Analysis Report
════════════════════════════════════════════════════════════════════════════════

Source: readme_baseline_942092.txt

┌────────────────────────────────┬────────────────────┬────────────────────┐
│ Event                          │              Count │          Rate/Info │
├────────────────────────────────┼────────────────────┼────────────────────┤
│ ── L1 Cache ──                 │                    │                    │
│   L1D Loads                    │         2351614615 │                    │
│   L1D Load Misses              │           22849952 │              0.97% │
│   L1D Stores                   │          276148636 │                    │
│   L1I Misses                   │           13114378 │                    │
│ ── L3 Cache ──                 │                    │                    │
│   L3/LLC Loads                 │           10682887 │                    │
│   L3/LLC Load Misses           │            7990478 │             74.80% │
│   L3/LLC Stores                │            1763733 │                    │
│   L3/LLC Store Misses          │            1242498 │                    │
│ ── Cache ──                    │                    │                    │
│   Total Cache Refs             │           26596206 │                    │
│   Total Cache Misses           │           18632743 │             70.06% │
│ ── Branch ──                   │                    │                    │
│   Branch Instructions          │         5867759590 │                    │
│   Branch Misses                │            3676053 │              0.06% │
│ ── TLB ──                      │                    │                    │
│   dTLB Load Misses             │             547518 │                    │
│   iTLB Load Misses             │              87915 │                    │
│ ── CPU ──                      │                    │                    │
│   CPU Cycles                   │       107061523559 │                    │
│   Instructions                 │        16519843233 │          IPC: 0.15 │
└────────────────────────────────┴────────────────────┴────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                              Derived Metrics
═══════════════════════════════════════════════════════════════════════════════


⚠ REDUCED METRICS MODE
Some analysis unavailable due to missing events:
  • GFLOPS, vectorization, operational intensity (FLOPs events not recorded)

  IPC (Instructions Per Cycle): 0.154 (Very Low - severe stalling)
  CPI (Cycles Per Instruction): 6.481
  L1D Miss/Load Ratio: 0.97%
  L3/LLC Load Hit Rate: 25.20% (High memory traffic)
  Overall Cache Hit Rate: 29.94%
  Branch Miss Rate: 0.063% (Excellent)
  Memory Intensity: 0.142 loads/instruction
  Elapsed Time: 0.369 seconds

═══════════════════════════════════════════════════════════════════════════════
                            Performance Insights
═══════════════════════════════════════════════════════════════════════════════

⚠ LOW IPC (0.15) - CPU is frequently stalling
  └─ Recommendation: Improve data locality, consider blocking/tiling

⚠ HIGH L3 MISS RATE (74.8%) - Significant memory traffic
  └─ Recommendation: Data exceeds L3, optimize for memory bandwidth

✓ EXCELLENT BRANCH PREDICTION (0.06% miss rate)
  └─ Branch-related optimizations not needed

⚠ HIGH LLC STORE MISS RATE (70.4%)
  └─ High RFO (Request For Ownership) traffic. CPU fetches cache lines just to overwrite them.
  └─ Recommendation: Use Non-Temporal (Streaming) Stores for large write-only buffers

─────────────────────────────────────────────────────────────────────────────────

BOTTLENECK SUMMARY:
  Primary:   Low IPC (execution stalls)
  Secondary: Memory bandwidth

```

## COMPARE
```bash
$# bash ./perf_tool.sh --compare readme_baseline_942092 readme_optimized_942092
════════════════════════════════════════════════════════════════════════════════════════════════════
                                    Performance Comparison
════════════════════════════════════════════════════════════════════════════════════════════════════

Baseline:  readme_baseline_942092.txt
Optimized: readme_optimized_942092.txt

⚠ REDUCED METRICS COMPARISON
Some comparisons unavailable due to missing events in one or both files:
  • GFLOPS and operational intensity comparison

┌────────────────────────────────┬──────────────────┬──────────────────┬──────────────┐
│ Metric                         │         Baseline │        Optimized │       Change │
├────────────────────────────────┼──────────────────┼──────────────────┼──────────────┤
│ L1D Loads                      │       2351614615 │       2097556731 │       -10.8% │
│ L1D Load Misses                │         22849952 │         20665657 │        -9.6% │
│ L1-dcache-stores               │        276148636 │        280534074 │         1.6% │
│ L1-icache-load-misses          │         13114378 │         13351592 │         1.8% │
│ L3/LLC Loads                   │         10682887 │         12233867 │       +14.5% │
│ L3/LLC Load Misses             │          7990478 │          6970647 │       -12.8% │
│ LLC-stores                     │          1763733 │          1820022 │         3.2% │
│ LLC-store-misses               │          1242498 │          1379083 │       +11.0% │
│ Total Cache Refs               │         26596206 │         26702214 │         0.4% │
│ Total Cache Misses             │         18632743 │         14213333 │       -23.7% │
│ Branch Instructions            │       5867759590 │       5017846002 │       -14.5% │
│ Branch Misses                  │          3676053 │          3772671 │         2.6% │
│ dTLB-load-misses               │           547518 │           888260 │       +62.2% │
│ iTLB-load-misses               │            87915 │           217624 │      +147.5% │
│ CPU Cycles                     │     107061523559 │      89760128408 │       -16.2% │
│ Instructions                   │      16519843233 │      14381190135 │       -12.9% │
└────────────────────────────────┴──────────────────┴──────────────────┴──────────────┘

Derived Metrics Comparison:

  IPC:                    0.154 →    0.160 (3.8%)
  L3 Hit Rate:           25.20% →   43.02% (+17.82 pp)
  Elapsed Time:          0.369s →   0.317s (-13.9%)
  Speedup:             1.16x

═══════════════════════════════════════════════════════════════════════════════
                         Performance Explanation
═══════════════════════════════════════════════════════════════════════════════

  No significant metric differences detected.
  Performance difference may be due to:
    • Measurement variance
    • System noise
    • Metrics not captured by these counters

```

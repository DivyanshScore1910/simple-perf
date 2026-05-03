# SIMPLE-PERF
Single bash script for performance measurements and some hints, for CPU.
**NOTE**: Currently optimized on Intel Xeon 4th Gen CPUs only.

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

  # With environment variables
  export LD_PRELOAD=/path/to/libgomp.so
  export OMP_NUM_THREADS=56
  /home/sdp/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output test --run ./my_program

```

## RECORD
```bash
$# bash ./perf_tool.sh --record-cache-metrics --output readme_baseline_931437 --run /home/sdp/divyansh/score_engine/build/score_gemm/score_gemm --m 64 --n 64 --k 64 --iters 5 --warmup 1 --no-check
══════════════════════════════════════════════════════════════
            Perf Performance Metrics Recording
══════════════════════════════════════════════════════════════

Output file: readme_baseline_931437.txt
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

score_gemm: M=64 N=64 K=64 threads=512 mode=hot iters=5 warmup=1 skip_iters=0 measured_iters=5 layers=1 packed_b_bytes=8192 cache_clear_bytes=234881024 avg_ms=7.940 median_ms=7.973 avg_gflops=0.066 median_gflops=0.066 checksum=1879816300894911315

Recording complete!
Metrics saved to: readme_baseline_931437.txt

To visualize: bash /home/sdp/divyansh/simple-perf/perf_tool.sh --visualize --input readme_baseline_931437
```

## VISUALIZE
```bash
$# bash ./perf_tool.sh --visualize --input readme_baseline_931437
════════════════════════════════════════════════════════════════════════════════
                         Performance Analysis Report
════════════════════════════════════════════════════════════════════════════════

Source: readme_baseline_931437.txt

┌────────────────────────────────┬────────────────────┬────────────────────┐
│ Event                          │              Count │          Rate/Info │
├────────────────────────────────┼────────────────────┼────────────────────┤
│ ── L1 Cache ──                 │                    │                    │
│   L1D Loads                    │         2172733255 │                    │
│   L1D Load Misses              │           22925164 │              1.06% │
│   L1D Stores                   │          275976066 │                    │
│   L1I Misses                   │           12980461 │                    │
│ ── L3 Cache ──                 │                    │                    │
│   L3/LLC Loads                 │           15416579 │                    │
│   L3/LLC Load Misses           │            9712415 │             63.00% │
│   L3/LLC Stores                │            1487155 │                    │
│   L3/LLC Store Misses          │            1113864 │                    │
│ ── Cache ──                    │                    │                    │
│   Total Cache Refs             │           23482294 │                    │
│   Total Cache Misses           │           16498962 │             70.26% │
│ ── Branch ──                   │                    │                    │
│   Branch Instructions          │         5227080522 │                    │
│   Branch Misses                │            3380853 │              0.06% │
│ ── TLB ──                      │                    │                    │
│   dTLB Load Misses             │             625406 │                    │
│   iTLB Load Misses             │              82169 │                    │
│ ── CPU ──                      │                    │                    │
│   CPU Cycles                   │        94171919956 │                    │
│   Instructions                 │        14983213505 │          IPC: 0.16 │
└────────────────────────────────┴────────────────────┴────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                              Derived Metrics
═══════════════════════════════════════════════════════════════════════════════


⚠ REDUCED METRICS MODE
Some analysis unavailable due to missing events:
  • GFLOPS, vectorization, operational intensity (FLOPs events not recorded)

  IPC (Instructions Per Cycle): 0.159 (Very Low - severe stalling)
  CPI (Cycles Per Instruction): 6.285
  L1D Miss/Load Ratio: 1.06%
  L3/LLC Load Hit Rate: 37.00% (High memory traffic)
  Overall Cache Hit Rate: 29.74%
  Branch Miss Rate: 0.065% (Excellent)
  Memory Intensity: 0.145 loads/instruction
  Elapsed Time: 0.374 seconds

═══════════════════════════════════════════════════════════════════════════════
                            Performance Insights
═══════════════════════════════════════════════════════════════════════════════

⚠ LOW IPC (0.16) - CPU is frequently stalling
  └─ Recommendation: Improve data locality, consider blocking/tiling

⚠ HIGH L3 MISS RATE (63.0%) - Significant memory traffic
  └─ Recommendation: Data exceeds L3, optimize for memory bandwidth

✓ EXCELLENT BRANCH PREDICTION (0.06% miss rate)
  └─ Branch-related optimizations not needed

⚠ HIGH LLC STORE MISS RATE (74.9%)
  └─ High RFO (Request For Ownership) traffic. CPU fetches cache lines just to overwrite them.
  └─ Recommendation: Use Non-Temporal (Streaming) Stores for large write-only buffers

─────────────────────────────────────────────────────────────────────────────────

BOTTLENECK SUMMARY:
  Primary:   Low IPC (execution stalls)
  Secondary: Memory bandwidth

```

## COMPARE
```bash
$# bash ./perf_tool.sh --compare readme_baseline_931437 readme_optimized_931437
════════════════════════════════════════════════════════════════════════════════════════════════════
                                    Performance Comparison
════════════════════════════════════════════════════════════════════════════════════════════════════

Baseline:  readme_baseline_931437.txt
Optimized: readme_optimized_931437.txt

⚠ REDUCED METRICS COMPARISON
Some comparisons unavailable due to missing events in one or both files:
  • GFLOPS and operational intensity comparison

┌────────────────────────────────┬──────────────────┬──────────────────┬──────────────┐
│ Metric                         │         Baseline │        Optimized │       Change │
├────────────────────────────────┼──────────────────┼──────────────────┼──────────────┤
│ L1D Loads                      │       2172733255 │       2103608090 │        -3.2% │
│ L1D Load Misses                │         22925164 │         19816089 │       -13.6% │
│ L1-dcache-stores               │        275976066 │        292750096 │        +6.1% │
│ L1-icache-load-misses          │         12980461 │         13400209 │         3.2% │
│ L3/LLC Loads                   │         15416579 │         10989063 │       -28.7% │
│ L3/LLC Load Misses             │          9712415 │          6964077 │       -28.3% │
│ LLC-stores                     │          1487155 │          1759733 │       +18.3% │
│ LLC-store-misses               │          1113864 │          1411190 │       +26.7% │
│ Total Cache Refs               │         23482294 │         24997985 │        +6.5% │
│ Total Cache Misses             │         16498962 │         16919920 │         2.6% │
│ Branch Instructions            │       5227080522 │       5105682772 │        -2.3% │
│ Branch Misses                  │          3380853 │          3185263 │        -5.8% │
│ dTLB-load-misses               │           625406 │           595014 │        -4.9% │
│ iTLB-load-misses               │            82169 │           115256 │       +40.3% │
│ CPU Cycles                     │      94171919956 │      91898930574 │        -2.4% │
│ Instructions                   │      14983213505 │      14538417947 │        -3.0% │
└────────────────────────────────┴──────────────────┴──────────────────┴──────────────┘

Derived Metrics Comparison:

  IPC:                    0.159 →    0.158 (-0.6%)
  L3 Hit Rate:           37.00% →   36.63% (-0.37 pp)
  Elapsed Time:          0.374s →   0.362s (-3.2%)
  Speedup:             1.03x

═══════════════════════════════════════════════════════════════════════════════
                         Performance Explanation
═══════════════════════════════════════════════════════════════════════════════

  ✓ L3 Traffic Reduced: 15.4M → 11.0M (29% fewer L2 misses)

```

# SIMPLE-PERF
Single bash script for performance measurements and some hints, for CPU.
**NOTE**: Currently optimized on Intel Xeon 4th Gen CPUs only.

## Features
```bash
$# bash ./perf_tool.sh --help
perf_tool.sh - Advanced perf profiling tool for performance analysis

USAGE:
  /home/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output <name> --run <executable> [args...]
  /home/divyansh/simple-perf/perf_tool.sh --visualize --input <name>
  /home/divyansh/simple-perf/perf_tool.sh --compare <baseline> <optimized>
  /home/divyansh/simple-perf/perf_tool.sh --help

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
    offcore_requests.all_data_rd, demand_data_rd

  Floating Point:
    fp_arith_inst_retired.scalar_single, scalar_double
    fp_arith_inst_retired.128b_packed, 256b_packed, 512b_packed

  Top-Down Analysis (TMA):
    topdown-retiring, topdown-bad-spec, topdown-fe-bound, topdown-be-bound

  Other:
    Branch:     branch-instructions, branch-misses
    TLB:        dTLB-load-misses, iTLB-load-misses
    CPU:        cycles, instructions

EXAMPLES:
  # Record metrics for a GEMM test
  /home/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output gemm_metrics --run ./gemm_vtune_test 1

  # Visualize metrics with insights
  /home/divyansh/simple-perf/perf_tool.sh --visualize --input gemm_metrics

  # Record only cache metrics (exclude Branch, TLB, CPU, FLOPs, TMA)
  /home/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --cache-only --output cache_metrics --run ./gemm_vtune_test 1

  # Compare baseline vs optimized
  /home/divyansh/simple-perf/perf_tool.sh --compare baseline optimized

  # With environment variables
  export LD_PRELOAD=/path/to/libgomp.so
  export OMP_NUM_THREADS=56
  /home/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output test --run ./my_program

```

## RECORD
```bash
$# bash ./perf_tool.sh --record-cache-metrics --output readme_baseline_26420 --run ./gemm_vtune_test 1
══════════════════════════════════════════════════════════════
            Perf Performance Metrics Recording
══════════════════════════════════════════════════════════════

Output file: readme_baseline_26420.txt
Command: ./gemm_vtune_test 1

Environment:
  LD_PRELOAD=<not set>
  OMP_NUM_THREADS=<not set>

Events being recorded:
  Core: 18 events (cache, branch, TLB, CPU)
  Stall: 5 events (cycle stall analysis)
  Memory: 2 events (bandwidth)
  FLOPs: 8 events (floating point)
  TMA: 0 events (top-down analysis)

Starting perf stat...


==========================================================
  VTune Profiling Test: gemm_amx_bf16bf16bf16__prepacked_B
==========================================================

System Configuration:
  Physical Cores: 56
  AMX BF16 Support: true
  OpenMP Threads: 112

Test Configuration:
  Description: Wide K dimension
  M = 256, N = 768, K = 16384
  Iterations: 100

  FLOPs per iteration: 6.44e+09

Allocating matrices...
  A: 256x16384, stride=32768 bytes
  B_packed: 25165824 bytes (prepacked format)
  C: 256x768, stride=1536 bytes

Initializing matrices with random data...
  Initialization complete.

Running warmup iterations (5x)...
  Warmup complete.

Starting main profiling loop (100 iterations)...
>>> ATTACH VTUNE PROFILER NOW <<<



Profiling complete!

========================================
Performance Statistics:
========================================
  Total time: 113.583 ms
  Average time per iteration: 1.136 ms (1135.8 us)
  Throughput: 5672.01 GFLOPS
  Approx. Memory Bandwidth: 52.04 GB/s

Cleaning up...
Done!

Recording complete!
Metrics saved to: readme_baseline_26420.txt

To visualize: bash /home/divyansh/simple-perf/perf_tool.sh --visualize --input readme_baseline_26420
```

## VISUALIZE
```bash
$# bash ./perf_tool.sh --visualize --input readme_baseline_26420
════════════════════════════════════════════════════════════════════════════════
                         Performance Analysis Report
════════════════════════════════════════════════════════════════════════════════

Source: readme_baseline_26420.txt

┌────────────────────────────────┬────────────────────┬────────────────────┐
│ Event                          │              Count │          Rate/Info │
├────────────────────────────────┼────────────────────┼────────────────────┤
│ ── L1 Cache ──                 │                    │                    │
│   L1D Loads                    │      1,105,036,094 │                    │
│   L1D Load Misses              │      1,083,014,872 │             98.01% │
│   L1D Stores                   │        360,458,829 │                    │
│   L1I Misses                   │          6,639,102 │                    │
│ ── L2 Cache ──                 │                    │                    │
│   L2 References                │      1,045,395,504 │                    │
│   L2 Misses                    │        601,106,206 │                    │
│ ── L3 Cache ──                 │                    │                    │
│   L3/LLC Loads                 │        419,700,615 │                    │
│   L3/LLC Load Misses           │          1,977,386 │              0.47% │
│   L3/LLC Stores                │          2,949,848 │                    │
│   L3/LLC Store Misses          │            655,053 │                    │
│ ── Cache ──                    │                    │                    │
│   Total Cache Refs             │        752,753,681 │                    │
│   Total Cache Misses           │            609,680 │              0.08% │
│ ── Stalls ──                   │                    │                    │
│   Total Stall Cycles           │     33,221,330,204 │                    │
│   Memory Stall Cycles          │     15,660,299,500 │                    │
│   L1D Miss Stalls              │      4,006,969,547 │                    │
│   L2 Miss Stalls               │      1,100,377,537 │                    │
│   L3 Miss Stalls               │          1,102,581 │                    │
│ ── Memory BW ──                │                    │                    │
│   All Data Reads               │        751,968,916 │                    │
│   Demand Data Reads            │        481,483,810 │                    │
│ ── FLOPs ──                    │                    │                    │
│   Scalar SP FLOPs              │         67,535,407 │                    │
│   Scalar DP FLOPs              │             32,714 │                    │
│   128b Packed SP               │                  0 │                    │
│   256b Packed SP               │                  0 │                    │
│   512b Packed SP               │                  0 │                    │
│   128b Packed DP               │                  0 │                    │
│   256b Packed DP               │                  0 │                    │
│   512b Packed DP               │                  0 │                    │
│ ── Branch ──                   │                    │                    │
│   Branch Instructions          │      1,664,338,224 │                    │
│   Branch Misses                │            706,878 │              0.04% │
│ ── TLB ──                      │                    │                    │
│   dTLB Load Misses             │              5,356 │                    │
│   iTLB Load Misses             │              1,664 │                    │
│ ── CPU ──                      │                    │                    │
│   CPU Cycles                   │     35,840,708,047 │                    │
│   Instructions                 │      6,237,904,450 │          IPC: 0.17 │
└────────────────────────────────┴────────────────────┴────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                              Derived Metrics
═══════════════════════════════════════════════════════════════════════════════

  IPC (Instructions Per Cycle): 0.174 (Very Low - severe stalling)
  CPI (Cycles Per Instruction): 5.746
  L1D Miss/Load Ratio: 98.01%
  L2 Cache Hit Rate: 42.50% (Poor)
  L3/LLC Load Hit Rate: 99.53% (Excellent)
  Overall Cache Hit Rate: 99.92%
  Branch Miss Rate: 0.042% (Excellent)
  Stall Cycles: 92.7% of cycles
    └─ Memory Stalls: 43.7% of cycles
  Memory Intensity: 0.177 loads/instruction
  GFLOPS: 0.17
  Elapsed Time: 0.391 seconds

═══════════════════════════════════════════════════════════════════════════════
                            Performance Insights
═══════════════════════════════════════════════════════════════════════════════

⚠ HIGH STALL RATE (92.7% of cycles) - CPU mostly waiting
  └─ Memory-related cycles: 43.7% of total
  └─ Recommendation: Optimize memory access patterns, improve cache utilization

⚠ HIGH L1 MISS RATE (98.0%) - Poor L1 cache utilization
  └─ Most loads miss L1 cache (32-48KB per core)
  └─ Recommendation: Improve spatial/temporal locality, consider prefetching

⚠ LOW IPC (0.17) - CPU is frequently stalling
  └─ Memory stalls account for 43.7% of cycles
  └─ Recommendation: Improve data locality, consider blocking/tiling

⚠ HIGH L2 MISS RATE (57.5%) - Data not fitting in L2
  └─ L2 cache: 2.0 MB per core (detected)
  └─ Target working set: ~1.5 MB
  └─ Recommendations:
  └─   • For BF16 GEMM: 512x512 to 768x768 tiles
  └─   • For FP32 GEMM: 256x256 to 384x384 tiles

✓ EXCELLENT L3 HIT RATE (99.53%) - Data fits in L3
  └─ No main memory bandwidth bottleneck

✓ EXCELLENT BRANCH PREDICTION (0.04% miss rate)
  └─ Branch-related optimizations not needed

⚠ LOW VECTORIZATION EFFICIENCY (0.0% vector instructions)
  └─ Code is dominated by scalar instructions
  └─ Recommendation: Use compiler vectorization (-O3, -march=native) or SIMD intrinsics (AVX2/AVX-512)

ℹ MEMORY BANDWIDTH: 114.70 GB/s (Read)
  └─ Note: Verify if this approaches the theoretical peak of your system (e.g. ~100GB/s for Dual DDR5)

⚠ HIGH CORE/L1 STALLS (81.5% of cycles)
  └─ Stalls not due to L1 misses. Likely L1 hit latency (pointer chasing) or execution dependencies.
  └─ Recommendation: Check for long dependency chains (div/sqrt) or L1-bound pointer chasing.

ℹ MEMORY LATENCY BREAKDOWN
  └─ Dominant Factor: L2 Latency
  └─ L2 Hit Stalls:     72.5% of memory stalls
  └─ L3 Hit Stalls:     27.4% of memory stalls
  └─ DRAM/Remote:        0.0% of memory stalls

  ⚠ L2 LATENCY DOMINANT
    └─ Working set thrashing L2 cache
    └─ Recommendations:
    └─   • Tile/block to fit working set in ~1.5 MB (L2 = 2.0 MB)
    └─   • For BF16 GEMM: Try 512x512 tiles
    └─   • For FP32 GEMM: Try 256x256 tiles

ℹ OPERATIONAL INTENSITY: 0.53 FLOPs/byte
  └─ Classification: MEMORY BOUND
  └─ Performance limited by memory bandwidth, not compute
  └─ Optimize: Data locality, blocking, prefetching, streaming stores

─────────────────────────────────────────────────────────────────────────────────

BOTTLENECK SUMMARY:
  Primary:   High stall rate (93% of cycles)
  Secondary: L1 cache misses

```

## COMPARE
```bash
$# bash ./perf_tool.sh --compare readme_baseline_26420 readme_optimized_26420
════════════════════════════════════════════════════════════════════════════════════════════════════
                                    Performance Comparison
════════════════════════════════════════════════════════════════════════════════════════════════════

Baseline:  readme_baseline_26420.txt
Optimized: readme_optimized_26420.txt

┌────────────────────────────────┬──────────────────┬──────────────────┬──────────────┐
│ Metric                         │         Baseline │        Optimized │       Change │
├────────────────────────────────┼──────────────────┼──────────────────┼──────────────┤
│ L1D Loads                      │    1,105,036,094 │    1,028,974,814 │        -6.9% │
│ L1D Load Misses                │    1,083,014,872 │    1,196,803,433 │       +10.5% │
│ L1-dcache-stores               │      360,458,829 │      380,533,748 │        +5.6% │
│ L1-icache-load-misses          │        6,639,102 │        6,889,388 │         3.8% │
│ L2 References                  │    1,045,395,504 │    1,555,788,114 │       +48.8% │
│ L2 Misses                      │      601,106,206 │      843,717,956 │       +40.4% │
│ L3/LLC Loads                   │      419,700,615 │      521,001,771 │       +24.1% │
│ L3/LLC Load Misses             │        1,977,386 │          659,951 │       -66.6% │
│ LLC-stores                     │        2,949,848 │        2,983,728 │         1.1% │
│ LLC-store-misses               │          655,053 │          105,248 │       -83.9% │
│ Total Cache Refs               │      752,753,681 │      826,466,433 │        +9.8% │
│ Total Cache Misses             │          609,680 │          344,860 │       -43.4% │
│ Branch Instructions            │    1,664,338,224 │    1,495,295,770 │       -10.2% │
│ Branch Misses                  │          706,878 │          670,655 │        -5.1% │
│ dTLB-load-misses               │            5,356 │           15,740 │      +193.9% │
│ iTLB-load-misses               │            1,664 │           40,352 │     +2325.0% │
│ CPU Cycles                     │   35,840,708,047 │   35,618,884,300 │        -0.6% │
│ Instructions                   │    6,237,904,450 │    5,695,943,081 │        -8.7% │
│ Total Stall Cycles             │   33,221,330,204 │   33,285,337,431 │         0.2% │
│ Memory Stall Cycles            │   15,660,299,500 │   17,814,460,381 │       +13.8% │
│ L1D Miss Stalls                │    4,006,969,547 │    5,372,609,101 │       +34.1% │
│ L2 Miss Stalls                 │    1,100,377,537 │      588,493,914 │       -46.5% │
│ L3 Miss Stalls                 │        1,102,581 │           81,550 │       -92.6% │
│ All Data Reads                 │      751,968,916 │      611,851,306 │       -18.6% │
│ Demand Data Reads              │      481,483,810 │      397,149,394 │       -17.5% │
│ Scalar SP FLOPs                │       67,535,407 │       66,295,954 │        -1.8% │
│ Scalar DP FLOPs                │           32,714 │           23,645 │       -27.7% │
└────────────────────────────────┴──────────────────┴──────────────────┴──────────────┘

Derived Metrics Comparison:

  IPC:                    0.174 →    0.160 (-8.1%)
  L2 Hit Rate:            42.5% →    45.8% (3.3 pp)
  L3 Hit Rate:           99.53% →   99.87% (0.34 pp)
  Elapsed Time:          0.391s →   0.400s (2.4%)
  Slowdown:            1.02x

═══════════════════════════════════════════════════════════════════════════════
                         Performance Explanation
═══════════════════════════════════════════════════════════════════════════════

  ⚠ L2 Traffic Increased: 1.05B → 1.56B (+49%)
  ✓ L2 Miss Stalls Reduced: 1.10B → 588.5M cycles (47% fewer)
  ✓ Data Reuse Improved: 0.5 → 1.6 FLOPs/byte (2.9x better)
    └─ More compute per byte of DRAM traffic

```

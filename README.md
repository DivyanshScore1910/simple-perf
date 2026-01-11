# SIMPLE-PERF
Single bash script for performance measurements and some hints, for CPU.
**NOTE**: Currently opitmized on Intel Xeon 4th Gen CPUs only.

## Features
```bash
$# bash ./perf_tool.sh --help
perf_tool.sh - Advanced perf profiling tool for performance analysis

USAGE:
  ../gemm/perf_tool.sh --record-cache-metrics --output <name> --run <executable> [args...]
  ../gemm/perf_tool.sh --visualize --input <name>
  ../gemm/perf_tool.sh --compare <baseline> <optimized>
  ../gemm/perf_tool.sh --help

OPTIONS:
  --record-cache-metrics    Record comprehensive performance metrics
  --output <name>           Output file name (auto-suffixed if exists)
  --run <executable>        Executable to profile (followed by its arguments)
  --visualize               Display metrics with analysis and insights
  --input <name>            Input file name to visualize
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
  ../gemm/perf_tool.sh --record-cache-metrics --output gemm_metrics --run ./gemm_vtune_test 1

  # Visualize metrics with insights
  ../gemm/perf_tool.sh --visualize --input gemm_metrics

  # Compare baseline vs optimized
  ../gemm/perf_tool.sh --compare baseline optimized

  # With environment variables
  export LD_PRELOAD=/path/to/libgomp.so
  export OMP_NUM_THREADS=56
  ../gemm/perf_tool.sh --record-cache-metrics --output test --run ./my_program
```

## RECORD
```bash
$# bash ./perf_tool.sh --record-cache-metrics --output gemm_cache --run ./gemm_vtune_test 1
File gemm_cache.txt exists, using: gemm_cache_20260111_124559.txt
══════════════════════════════════════════════════════════════
            Perf Performance Metrics Recording
══════════════════════════════════════════════════════════════

Output file: gemm_cache_20260111_124559.txt
Command: ./gemm_vtune_test 1

Environment:
  LD_PRELOAD=<not set>
  OMP_NUM_THREADS=<not set>

Events being recorded:
  Core: 18 events (cache, branch, TLB, CPU)
  Stall: 5 events (cycle stall analysis)
  Memory: 2 events (bandwidth)
  FLOPs: 5 events (floating point)
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
  Total time: 92.019 ms
  Average time per iteration: 0.920 ms (920.2 us)
  Throughput: 7001.23 GFLOPS
  Approx. Memory Bandwidth: 64.24 GB/s

Cleaning up...
Done!

Recording complete!
Metrics saved to: gemm_cache_20260111_124559.txt

To visualize: bash ./perf_tool.sh --visualize --input gemm_cache_20260111_124559
```

## VISUALIZE
```bash
$# bash ./perf_tool.sh --visualize --input gemm_cache_20260111_124559
════════════════════════════════════════════════════════════════════════════════
                         Performance Analysis Report
════════════════════════════════════════════════════════════════════════════════

Source: gemm_cache_20260111_124559.txt

┌────────────────────────────────┬────────────────────┬────────────────────┐
│ Event                          │              Count │          Rate/Info │
├────────────────────────────────┼────────────────────┼────────────────────┤
│ ── L1 Cache ──                 │                    │                    │
│   L1D Loads                    │        825,923,682 │                    │
│   L1D Load Misses              │        965,982,320 │            116.96% │
│   L1D Stores                   │        297,827,687 │                    │
│   L1I Misses                   │          4,794,091 │                    │
│ ── L2 Cache ──                 │                    │                    │
│   L2 References                │      1,534,143,981 │                    │
│   L2 Misses                    │        903,559,181 │                    │
│ ── L3 Cache ──                 │                    │                    │
│   L3/LLC Loads                 │        600,966,497 │                    │
│   L3/LLC Load Misses           │             13,882 │              0.00% │
│   L3/LLC Stores                │          2,653,238 │                    │
│   L3/LLC Store Misses          │            136,893 │                    │
│ ── Cache ──                    │                    │                    │
│   Total Cache Refs             │        687,055,808 │                    │
│   Total Cache Misses           │            651,134 │              0.09% │
│ ── Stalls ──                   │                    │                    │
│   Total Stall Cycles           │     24,490,865,325 │                    │
│   Memory Stall Cycles          │     14,730,477,563 │                    │
│   L1D Miss Stalls              │      2,374,606,431 │                    │
│   L2 Miss Stalls               │      3,248,886,296 │                    │
│   L3 Miss Stalls               │            217,779 │                    │
│ ── Memory BW ──                │                    │                    │
│   All Data Reads               │        708,522,723 │                    │
│   Demand Data Reads            │        479,823,695 │                    │
│ ── FLOPs ──                    │                    │                    │
│   Scalar SP FLOPs              │         69,109,011 │                    │
│   Scalar DP FLOPs              │             32,297 │                    │
│   128b Packed SP               │                  0 │                    │
│   256b Packed SP               │                  0 │                    │
│   512b Packed SP               │                  0 │                    │
│ ── Branch ──                   │                    │                    │
│   Branch Instructions          │      1,150,298,152 │                    │
│   Branch Misses                │            652,753 │              0.06% │
│ ── TLB ──                      │                    │                    │
│   dTLB Load Misses             │              1,413 │                    │
│   iTLB Load Misses             │                521 │                    │
│ ── CPU ──                      │                    │                    │
│   CPU Cycles                   │     26,315,634,776 │                    │
│   Instructions                 │      4,880,066,612 │          IPC: 0.19 │
└────────────────────────────────┴────────────────────┴────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                              Derived Metrics
═══════════════════════════════════════════════════════════════════════════════

  IPC (Instructions Per Cycle): 0.185 (Low - CPU stalling)
  CPI (Cycles Per Instruction): 5.392
  L1D Miss/Load Ratio: 117.0% (>100% = prefetcher active)
  L2 Cache Hit Rate: 41.10% (Poor)
  L3/LLC Load Hit Rate: 100.00% (Excellent)
  Overall Cache Hit Rate: 99.91%
  Branch Miss Rate: 0.057% (Excellent)
  Stall Cycles: 93.1% of cycles
    └─ Memory Stalls: 56.0% of cycles
  Memory Intensity: 0.169 loads/instruction
  GFLOPS: 0.19
  Elapsed Time: 0.368 seconds

═══════════════════════════════════════════════════════════════════════════════
                            Performance Insights
═══════════════════════════════════════════════════════════════════════════════

⚠ HIGH STALL RATE (93.1% of cycles) - CPU mostly waiting
  └─ Memory-related cycles: 56.0% of total
  └─ Recommendation: Optimize memory access patterns, improve cache utilization

⚠ LOW IPC (0.19) - CPU is frequently stalling
  └─ Memory stalls account for 56.0% of cycles
  └─ Recommendation: Improve data locality, consider blocking/tiling

⚠ HIGH L2 MISS RATE (58.9%) - Data not fitting in L2
  └─ L2 cache typically 1-2 MB per core
  └─ Recommendation: Reduce working set size or improve access patterns

✓ EXCELLENT L3 HIT RATE (100.00%) - Data fits in L3
  └─ No main memory bandwidth bottleneck

✓ EXCELLENT BRANCH PREDICTION (0.06% miss rate)
  └─ Branch-related optimizations not needed

ℹ ACTIVE PREFETCHING (L1 miss/load ratio: 1.2x)
  └─ Hardware prefetcher is aggressively fetching data

⚠ LOW VECTORIZATION EFFICIENCY (0.0% vector instructions)
  └─ Code is dominated by scalar instructions
  └─ Recommendation: Use compiler vectorization (-O3, -march=native) or SIMD intrinsics (AVX2/AVX-512)

ℹ MEMORY BANDWIDTH: 114.89 GB/s (Read)
  └─ Note: Verify if this approaches the theoretical peak of your system (e.g. ~100GB/s for Dual DDR5)

⚠ HIGH CORE/L1 STALLS (84.0% of cycles)
  └─ Stalls not due to L1 misses. Likely L1 hit latency (pointer chasing) or execution dependencies.
  └─ Recommendation: Check for long dependency chains (div/sqrt) or L1-bound pointer chasing.

ℹ MEMORY LATENCY BREAKDOWN
  └─ Dominant Factor: L3 Latency
  └─ L2 Hit Stalls:      0.0% of memory stalls
  └─ L3 Hit Stalls:    136.8% of memory stalls
  └─ DRAM/Remote:        0.0% of memory stalls

─────────────────────────────────────────────────────────────────────────────────

BOTTLENECK SUMMARY:
  Primary:   High stall rate (93% of cycles)
  Secondary: L2 cache misses
```

## COMPARE
```bash
$# bash ./perf_tool.sh --visualize --compare gemm_cache gemm_new_20260111_120700
════════════════════════════════════════════════════════════════════════════════════════════════════
                                    Performance Comparison
════════════════════════════════════════════════════════════════════════════════════════════════════

Baseline:  gemm_cache.txt
Optimized: gemm_new_20260111_120700.txt

┌────────────────────────────────┬──────────────────┬──────────────────┬──────────────┐
│ Metric                         │         Baseline │        Optimized │       Change │
├────────────────────────────────┼──────────────────┼──────────────────┼──────────────┤
│ L1D Loads                      │      664,330,231 │      523,024,392 │       -21.3% │
│ L1D Load Misses                │    1,234,408,212 │      519,197,929 │       -57.9% │
│ L1-dcache-stores               │      305,740,122 │      254,179,032 │       -16.9% │
│ L1-icache-load-misses          │        6,065,343 │        4,656,139 │       -23.2% │
│ L2 References                  │    1,980,548,783 │      894,910,951 │       -54.8% │
│ L2 Misses                      │    1,329,686,647 │      151,631,824 │       -88.6% │
│ L3/LLC Loads                   │      650,774,928 │       79,951,187 │       -87.7% │
│ L3/LLC Load Misses             │            7,808 │            4,175 │       -46.5% │
│ LLC-stores                     │        1,649,998 │          474,339 │       -71.3% │
│ LLC-store-misses               │          667,616 │           30,665 │       -95.4% │
│ Total Cache Refs               │    1,280,720,412 │      213,984,502 │       -83.3% │
│ Total Cache Misses             │          764,240 │          422,402 │       -44.7% │
│ Branch Instructions            │      868,582,161 │      479,670,671 │       -44.8% │
│ Branch Misses                  │          733,088 │          385,979 │       -47.3% │
│ dTLB-load-misses               │           42,429 │              452 │       -98.9% │
│ iTLB-load-misses               │           24,988 │               63 │       -99.7% │
│ CPU Cycles                     │   14,058,014,260 │    3,733,779,537 │       -73.4% │
│ Instructions                   │    3,800,240,647 │    2,616,773,051 │       -31.1% │
│ Total Stall Cycles             │                  │    2,838,458,267 │         0.0% │
│ Memory Stall Cycles            │                  │    3,238,356,463 │         0.0% │
│ L1D Miss Stalls                │                  │      405,429,281 │         0.0% │
│ L2 Miss Stalls                 │                  │      362,830,000 │         0.0% │
│ L3 Miss Stalls                 │                  │          166,691 │         0.0% │
│ All Data Reads                 │                  │      331,710,065 │         0.0% │
│ Demand Data Reads              │                  │      173,366,184 │         0.0% │
│ Scalar SP FLOPs                │                  │       68,056,913 │         0.0% │
│ Scalar DP FLOPs                │                  │           28,930 │         0.0% │
└────────────────────────────────┴──────────────────┴──────────────────┴──────────────┘

Derived Metrics Comparison:

  IPC:                    0.270 →    0.701 (+159.3%)
  L2 Hit Rate:            32.9% →    83.1% (+50.2 pp)
  L3 Hit Rate:          100.00% →   99.99% (-0.00 pp)
  Elapsed Time:          0.362s →   0.297s (-18.1%)
  Speedup:             1.22x
```

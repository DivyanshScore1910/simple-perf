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

  # Compare baseline vs optimized
  /home/divyansh/simple-perf/perf_tool.sh --compare baseline optimized

  # With environment variables
  export LD_PRELOAD=/path/to/libgomp.so
  export OMP_NUM_THREADS=56
  /home/divyansh/simple-perf/perf_tool.sh --record-cache-metrics --output test --run ./my_program

```

## RECORD
```bash
$# bash ./perf_tool.sh --record-cache-metrics --output readme_baseline_681123 --run ./gemm_vtune_test 1
══════════════════════════════════════════════════════════════
            Perf Performance Metrics Recording
══════════════════════════════════════════════════════════════

Output file: readme_baseline_681123.txt
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
  Total time: 103.075 ms
  Average time per iteration: 1.031 ms (1030.7 us)
  Throughput: 6250.26 GFLOPS
  Approx. Memory Bandwidth: 57.35 GB/s

Cleaning up...
Done!

Recording complete!
Metrics saved to: readme_baseline_681123.txt

To visualize: bash /home/divyansh/simple-perf/perf_tool.sh --visualize --input readme_baseline_681123
```

## VISUALIZE
```bash
$# bash ./perf_tool.sh --visualize --input readme_baseline_681123
════════════════════════════════════════════════════════════════════════════════
                         Performance Analysis Report
════════════════════════════════════════════════════════════════════════════════

Source: readme_baseline_681123.txt

┌────────────────────────────────┬────────────────────┬────────────────────┐
│ Event                          │              Count │          Rate/Info │
├────────────────────────────────┼────────────────────┼────────────────────┤
│ ── L1 Cache ──                 │                    │                    │
│   L1D Loads                    │        920,707,358 │                    │
│   L1D Load Misses              │        976,632,847 │            106.07% │
│   L1D Stores                   │        337,270,670 │                    │
│   L1I Misses                   │          7,518,331 │                    │
│ ── L2 Cache ──                 │                    │                    │
│   L2 References                │      1,280,709,046 │                    │
│   L2 Misses                    │        800,164,862 │                    │
│ ── L3 Cache ──                 │                    │                    │
│   L3/LLC Loads                 │        562,522,457 │                    │
│   L3/LLC Load Misses           │            701,127 │              0.12% │
│   L3/LLC Stores                │          3,078,109 │                    │
│   L3/LLC Store Misses          │            333,312 │                    │
│ ── Cache ──                    │                    │                    │
│   Total Cache Refs             │        947,709,713 │                    │
│   Total Cache Misses           │            598,529 │              0.06% │
│ ── Stalls ──                   │                    │                    │
│   Total Stall Cycles           │     31,992,876,117 │                    │
│   Memory Stall Cycles          │     16,379,155,540 │                    │
│   L1D Miss Stalls              │      4,591,362,275 │                    │
│   L2 Miss Stalls               │        913,642,135 │                    │
│   L3 Miss Stalls               │            231,074 │                    │
│ ── Memory BW ──                │                    │                    │
│   All Data Reads               │        615,426,641 │                    │
│   Demand Data Reads            │        386,214,987 │                    │
│ ── FLOPs ──                    │                    │                    │
│   Scalar SP FLOPs              │         67,137,390 │                    │
│   Scalar DP FLOPs              │             28,496 │                    │
│   128b Packed SP               │                  0 │                    │
│   256b Packed SP               │                  0 │                    │
│   512b Packed SP               │                  0 │                    │
│   128b Packed DP               │                  0 │                    │
│   256b Packed DP               │                  0 │                    │
│   512b Packed DP               │                  0 │                    │
│ ── Branch ──                   │                    │                    │
│   Branch Instructions          │      1,471,460,858 │                    │
│   Branch Misses                │            761,499 │              0.05% │
│ ── TLB ──                      │                    │                    │
│   dTLB Load Misses             │             14,929 │                    │
│   iTLB Load Misses             │              3,541 │                    │
│ ── CPU ──                      │                    │                    │
│   CPU Cycles                   │     35,116,397,372 │                    │
│   Instructions                 │      6,141,273,975 │          IPC: 0.17 │
└────────────────────────────────┴────────────────────┴────────────────────┘

═══════════════════════════════════════════════════════════════════════════════
                              Derived Metrics
═══════════════════════════════════════════════════════════════════════════════

  IPC (Instructions Per Cycle): 0.175 (Very Low - severe stalling)
  CPI (Cycles Per Instruction): 5.718
  L1D Miss/Load Ratio: 106.1% (>100% = prefetcher active)
  L2 Cache Hit Rate: 37.52% (Poor)
  L3/LLC Load Hit Rate: 99.88% (Excellent)
  Overall Cache Hit Rate: 99.94%
  Branch Miss Rate: 0.052% (Excellent)
  Stall Cycles: 91.1% of cycles
    └─ Memory Stalls: 46.6% of cycles
  Memory Intensity: 0.150 loads/instruction
  GFLOPS: 0.18
  Elapsed Time: 0.379 seconds

═══════════════════════════════════════════════════════════════════════════════
                            Performance Insights
═══════════════════════════════════════════════════════════════════════════════

⚠ HIGH STALL RATE (91.1% of cycles) - CPU mostly waiting
  └─ Memory-related cycles: 46.6% of total
  └─ Recommendation: Optimize memory access patterns, improve cache utilization

⚠ LOW IPC (0.17) - CPU is frequently stalling
  └─ Memory stalls account for 46.6% of cycles
  └─ Recommendation: Improve data locality, consider blocking/tiling

⚠ HIGH L2 MISS RATE (62.5%) - Data not fitting in L2
  └─ L2 cache: 2.0 MB per core (detected)
  └─ Target working set: ~1.5 MB
  └─ Recommendations:
  └─   • For BF16 GEMM: 512x512 to 768x768 tiles
  └─   • For FP32 GEMM: 256x256 to 384x384 tiles

✓ EXCELLENT L3 HIT RATE (99.88%) - Data fits in L3
  └─ No main memory bandwidth bottleneck

✓ EXCELLENT BRANCH PREDICTION (0.05% miss rate)
  └─ Branch-related optimizations not needed

ℹ ACTIVE PREFETCHING (L1 miss/load ratio: 1.1x)
  └─ Hardware prefetcher is aggressively fetching data

⚠ LOW VECTORIZATION EFFICIENCY (0.0% vector instructions)
  └─ Code is dominated by scalar instructions
  └─ Recommendation: Use compiler vectorization (-O3, -march=native) or SIMD intrinsics (AVX2/AVX-512)

ℹ MEMORY BANDWIDTH: 96.80 GB/s (Read)
  └─ Note: Verify if this approaches the theoretical peak of your system (e.g. ~100GB/s for Dual DDR5)

⚠ HIGH CORE/L1 STALLS (78.0% of cycles)
  └─ Stalls not due to L1 misses. Likely L1 hit latency (pointer chasing) or execution dependencies.
  └─ Recommendation: Check for long dependency chains (div/sqrt) or L1-bound pointer chasing.

ℹ MEMORY LATENCY BREAKDOWN
  └─ Dominant Factor: L2 Latency
  └─ L2 Hit Stalls:     80.1% of memory stalls
  └─ L3 Hit Stalls:     19.9% of memory stalls
  └─ DRAM/Remote:        0.0% of memory stalls

  ⚠ L2 LATENCY DOMINANT
    └─ Working set thrashing L2 cache
    └─ Recommendations:
    └─   • Tile/block to fit working set in ~1.5 MB (L2 = 2.0 MB)
    └─   • For BF16 GEMM: Try 512x512 tiles
    └─   • For FP32 GEMM: Try 256x256 tiles

ℹ OPERATIONAL INTENSITY: 1.50 FLOPs/byte
  └─ Classification: MEMORY BOUND
  └─ Performance limited by memory bandwidth, not compute
  └─ Optimize: Data locality, blocking, prefetching, streaming stores

─────────────────────────────────────────────────────────────────────────────────

BOTTLENECK SUMMARY:
  Primary:   High stall rate (91% of cycles)
  Secondary: L2 cache misses

```

## COMPARE
```bash
$# bash ./perf_tool.sh --compare readme_baseline_681123 readme_optimized_681123
════════════════════════════════════════════════════════════════════════════════════════════════════
                                    Performance Comparison
════════════════════════════════════════════════════════════════════════════════════════════════════

Baseline:  readme_baseline_681123.txt
Optimized: readme_optimized_681123.txt

┌────────────────────────────────┬──────────────────┬──────────────────┬──────────────┐
│ Metric                         │         Baseline │        Optimized │       Change │
├────────────────────────────────┼──────────────────┼──────────────────┼──────────────┤
│ L1D Loads                      │      920,707,358 │      905,402,048 │        -1.7% │
│ L1D Load Misses                │      976,632,847 │      878,244,444 │       -10.1% │
│ L1-dcache-stores               │      337,270,670 │      328,377,883 │        -2.6% │
│ L1-icache-load-misses          │        7,518,331 │        6,503,654 │       -13.5% │
│ L2 References                  │    1,280,709,046 │    1,101,054,882 │       -14.0% │
│ L2 Misses                      │      800,164,862 │      708,714,558 │       -11.4% │
│ L3/LLC Loads                   │      562,522,457 │      504,997,832 │       -10.2% │
│ L3/LLC Load Misses             │          701,127 │          173,782 │       -75.2% │
│ LLC-stores                     │        3,078,109 │        2,974,675 │        -3.4% │
│ LLC-store-misses               │          333,312 │           20,144 │       -94.0% │
│ Total Cache Refs               │      947,709,713 │      889,955,546 │        -6.1% │
│ Total Cache Misses             │          598,529 │          193,124 │       -67.7% │
│ Branch Instructions            │    1,471,460,858 │    1,558,656,632 │        +5.9% │
│ Branch Misses                  │          761,499 │          761,765 │         0.0% │
│ dTLB-load-misses               │           14,929 │           12,922 │       -13.4% │
│ iTLB-load-misses               │            3,541 │            3,697 │         4.4% │
│ CPU Cycles                     │   35,116,397,372 │   34,117,222,917 │        -2.8% │
│ Instructions                   │    6,141,273,975 │    6,108,291,264 │        -0.5% │
│ Total Stall Cycles             │   31,992,876,117 │   30,750,323,199 │        -3.9% │
│ Memory Stall Cycles            │   16,379,155,540 │   15,130,585,581 │        -7.6% │
│ L1D Miss Stalls                │    4,591,362,275 │    4,306,200,747 │        -6.2% │
│ L2 Miss Stalls                 │      913,642,135 │    1,043,901,971 │       +14.3% │
│ L3 Miss Stalls                 │          231,074 │            5,682 │       -97.5% │
│ All Data Reads                 │      615,426,641 │      714,138,085 │       +16.0% │
│ Demand Data Reads              │      386,214,987 │      474,919,668 │       +23.0% │
│ Scalar SP FLOPs                │       67,137,390 │       66,507,558 │        -0.9% │
│ Scalar DP FLOPs                │           28,496 │           31,709 │       +11.3% │
└────────────────────────────────┴──────────────────┴──────────────────┴──────────────┘

Derived Metrics Comparison:

  IPC:                    0.175 →    0.179 (2.4%)
  L2 Hit Rate:            37.5% →    35.6% (-1.9 pp)
  L3 Hit Rate:           99.88% →   99.97% (0.09 pp)
  Elapsed Time:          0.379s →   0.376s (-0.7%)
  Speedup:             1.01x

```

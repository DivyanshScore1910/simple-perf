# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Single-script bash-based performance profiling tool using Linux `perf` for hardware counter analysis. Optimized for Intel Xeon 4th Gen (Sapphire Rapids) CPUs with automated bottleneck detection.

## Common Commands

```bash
# Record performance metrics
./perf_tool.sh --record-cache-metrics --output <name> --run <executable> [args...]

# Visualize with analysis (skip insights with --no-insights)
./perf_tool.sh --visualize --input <name>

# Compare two runs
./perf_tool.sh --compare <baseline> <optimized>

# Auto-generate README.md (runs executable twice for comparison)
./auto_readme.sh <executable> [args...]
```

## Architecture

**perf_tool.sh** (main script):
- Lines 29-92: Event definitions (CORE_EVENTS, STALL_EVENTS, MEMORY_EVENTS, FLOPS_EVENTS, TMA_EVENTS)
- Lines 159-223: `record_cache_metrics()` - wraps `perf stat` with event collection
- Lines 225-1078: `visualize_metrics()` - contains 700+ line AWK script for parsing and insights
- Lines 1080-1328: `compare_metrics()` - side-by-side comparison with percentage changes

**AWK Processing Engine** (inside visualize_metrics):
- Parses perf output, maps events to friendly names
- Computes derived metrics: IPC, cache hit rates, GFLOPS, memory bandwidth
- Bottleneck detection with SPR-calibrated thresholds (IPC up to 4+ for 6-wide issue)
- Insights prioritized: stalls → L1 → L2 → L3 → memory BW → vectorization

**Key Thresholds** (Sapphire Rapids calibrated):
- IPC: <0.5 severe, <1.5 low, <3.0 moderate, <4.0 good, ≥4.0 excellent
- L2 miss rate >50%: recommend tiling (512x512 BF16, 256x256 FP32)
- Memory bandwidth: ~250 GB/s practical peak for single socket

## Pre-commit Hook

When instructed to create a commit:
1. Run `git diff` (--cached if necessary) to review changes
2. Always run `./auto_readme.sh ./gemm_vtune_test 1` before committing to regenerate README.md
3. Stage README.md along with other changes

## Environment Variables

- `LD_PRELOAD`: Library preloading (displayed in recording output)
- `OMP_NUM_THREADS`: OpenMP thread count (displayed in recording output)

## System Detection

Cache sizes auto-detected from:
- `/sys/devices/system/cpu/cpu0/cache/index2/size` (L2)
- `/sys/devices/system/cpu/cpu0/cache/index3/size` (L3)

# USER-INSTRUCTIONS

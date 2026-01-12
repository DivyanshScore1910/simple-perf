# Hardware Performance Counter Reference

This document explains the hardware events collected by `perf_tool.sh` and how to interpret them for performance optimization.

## Quick Reference Table

| Event | What It Measures | Good | Bad | Optimization |
|-------|------------------|------|-----|--------------|
| L1-dcache-load-misses | L1 cache misses | <10% of loads | >50% of loads | Spatial locality |
| l2_rqsts.references | Traffic to L2 | Low count | High count | L1 data reuse |
| l2_rqsts.miss | L2 misses | <20% of refs | >50% of refs | Tiling/blocking |
| LLC-load-misses | L3 misses → DRAM | <1% of LLC loads | >5% of LLC loads | Fit in L3 |
| cycle_activity.stalls_total | Stalled cycles | <25% of cycles | >50% of cycles | Fix bottleneck |
| branch-misses | Mispredictions | <1% of branches | >5% of branches | PGO, eliminate branches |
| IPC | Efficiency | >2.0 | <0.5 | Reduce stalls |

---

## Understanding the Cache Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CPU Core                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Load/Store Instructions (your code)                                │   │
│  │         │                                                           │   │
│  │         ▼                                                           │   │
│  │  ┌──────────────┐  L1-dcache-loads (demand)                        │   │
│  │  │   L1 Cache   │  L1-dcache-load-misses (demand + prefetch)       │   │
│  │  │  (32-48 KB)  │                                                   │   │
│  │  └──────┬───────┘                                                   │   │
│  │         │ L1 miss                                                   │   │
│  │         ▼                                                           │   │
│  │  ┌──────────────┐  l2_rqsts.references (all requests to L2)        │   │
│  │  │   L2 Cache   │  l2_rqsts.miss (requests that missed L2)         │   │
│  │  │   (1-2 MB)   │                                                   │   │
│  │  └──────┬───────┘                                                   │   │
│  │         │ L2 miss                                                   │   │
│  └─────────┼───────────────────────────────────────────────────────────┘   │
│            ▼                                                               │
│  ┌──────────────────┐  LLC-loads (requests reaching L3)                    │
│  │   L3/LLC Cache   │  LLC-load-misses (requests that missed L3)           │
│  │   (30-100 MB)    │                                                      │
│  └────────┬─────────┘                                                      │
│           │ L3 miss                                                        │
└───────────┼─────────────────────────────────────────────────────────────────┘
            ▼
     ┌──────────────┐  offcore_requests.data_rd (all off-core reads)
     │    DRAM      │  offcore_requests.demand_data_rd (demand only)
     │  (Memory)    │
     └──────────────┘
```

---

## Key Concept: Demand vs All/Total

**This distinction is critical for understanding prefetcher activity.**

| Term | Meaning | Example Events |
|------|---------|----------------|
| **Demand** | Explicit load/store instructions from your code | `offcore_requests.demand_data_rd` |
| **All/Total** | Demand + Hardware Prefetch (speculative) | `offcore_requests.data_rd`, `L1-dcache-load-misses` |

### Hardware Prefetcher

The CPU speculatively fetches data it predicts will be needed soon:
- These fetches are NOT triggered by your code's load instructions
- They are counted in "all/total" metrics but NOT in "demand" metrics
- Active prefetching is usually good - it means your access pattern is predictable

### Why L1-dcache-load-misses Can Exceed L1-dcache-loads (>100%)

```
L1-dcache-loads      = demand loads from your code
L1-dcache-load-misses = ALL misses including prefetch misses

Ratio > 100% means: prefetcher is aggressively fetching ahead of your code
```

**Example:**
```
L1D Loads:       693,747,173
L1D Load Misses: 718,885,746 (103.6%)
                           ↑
                 Prefetcher triggered ~25M additional cache line fetches
```

**Interpretation:**
- Ratio 100-150%: Healthy prefetching, predictable access pattern
- Ratio 150-200%: Very aggressive prefetching
- Ratio >200%: Prefetcher working very hard; check if it's helping

---

## L1 Cache Events

### L1-dcache-loads
**What it measures:** Number of load operations that access the L1 data cache.

**Typical L1 sizes:** 32-48 KB per core (Sapphire Rapids: 48 KB)

**How to interpret:**
- This is your baseline for memory access intensity
- Compare with `instructions` to get memory intensity ratio
- `L1-dcache-loads / instructions > 0.3` = memory-intensive code

### L1-dcache-load-misses
**What it measures:** Loads that missed L1 and had to fetch from L2 (includes prefetch-triggered misses).

**Key insights:**
- Miss ratio < 10%: Excellent spatial locality
- Miss ratio 10-50%: Room for improvement
- Miss ratio 50-100%: Poor locality, but fixable
- Miss ratio > 100%: Prefetcher active (see above)

**Optimization:**
- Improve spatial locality (access data sequentially)
- Use cache-friendly data structures (SoA vs AoS)
- Align data to cache line boundaries (64 bytes)

### L1-dcache-stores
**What it measures:** Store (write) operations to L1.

**Optimization insight:**
- High stores relative to loads may indicate write-heavy code
- For write-only buffers: consider non-temporal stores (`_mm_stream_*`)
- Non-temporal stores bypass cache, avoiding read-for-ownership (RFO)

### L1-icache-load-misses
**What it measures:** Instruction cache misses (code fetch failures).

**Warning signs:**
- MPKI (Misses Per Kilo Instructions) > 20: Frontend bottleneck
- May indicate: large code size, poor code locality, or excessive inlining

**Optimization:**
- Profile-Guided Optimization (PGO) to improve code layout
- Reduce code size in hot paths
- Consider huge pages for code (iTLB improvement)

---

## L2 Cache Events

### l2_rqsts.references
**What it measures:** Total requests arriving at L2 cache.

**This includes:**
- L1 data cache misses
- Hardware prefetch requests
- Some instruction cache misses

**Critical for comparing implementations:**
- Lower is better (means L1 is more effective)
- Dramatic reduction indicates improved data reuse
- **This is often the best metric for measuring locality improvements**

**Example from GEMM comparison:**
```
OLD: 1,838,509,762 L2 references
NEW:   755,039,210 L2 references  (-59%)
                                   ↑
                   NEW has much better L1 data reuse
```

### l2_rqsts.miss
**What it measures:** Requests that missed L2 and went to L3/LLC.

**Interpretation:**
- Hit rate = 1 - (miss / references)
- Hit rate < 80%: Data doesn't fit in L2, consider tiling
- Hit rate > 95%: Excellent L2 utilization

**Optimization (for Sapphire Rapids with 2MB L2):**
- Target working set: ~1.5 MB (75% of L2)
- BF16 GEMM: 512×512 to 768×768 tile sizes
- FP32 GEMM: 256×256 to 384×384 tile sizes

---

## L3/LLC Cache Events

### LLC-loads
**What it measures:** Load requests that reached the Last Level Cache (L3).

**Key insight:**
- LLC-loads ≈ L2 misses
- This is traffic that escaped L2 and reached L3
- Lower = better L2 efficiency

### LLC-load-misses
**What it measures:** Loads that missed LLC and had to go to DRAM.

**Critical for memory-bound detection:**
- Miss rate > 5%: Significant DRAM traffic
- Miss rate near 0%: Data fits in LLC (excellent!)

**Impact of LLC misses:**
- DRAM latency: ~80-100+ ns (vs ~12 ns for L3 hit)
- Each miss costs ~200-300 cycles of stall

### LLC-stores / LLC-store-misses
**What it measures:** Store traffic to LLC and store misses.

**RFO (Request For Ownership) explained:**
- When writing to a cache line not in cache, CPU must first fetch it
- This "read before write" is called RFO
- High LLC-store-misses = high RFO traffic

**Optimization:**
- For write-only buffers: use non-temporal stores
- `_mm512_stream_si512()` bypasses cache entirely
- Eliminates RFO overhead for streaming writes

---

## Stall Events

### cycle_activity.stalls_total
**What it measures:** Cycles where the CPU pipeline is stalled (not retiring instructions).

**Interpretation:**
- < 25%: Good utilization
- 25-50%: Significant inefficiency
- > 50%: Severe bottleneck - investigate cause

### cycle_activity.cycles_mem_any
**What it measures:** Cycles with any outstanding memory request.

**Note:** This can exceed stalls_total because:
- Out-of-order execution can do useful work while waiting for memory
- Only counts as "stall" when no progress can be made

### Stall Hierarchy: stalls_l1d_miss → stalls_l2_miss → stalls_l3_miss

**These are nested subsets:**
```
stalls_l1d_miss = cycles stalled waiting for data not in L1
    └── stalls_l2_miss = subset where data also not in L2
            └── stalls_l3_miss = subset where data also not in L3 (waiting for DRAM)
```

**Derived breakdown (where time is spent waiting):**
```
L2 Hit Stalls  = stalls_l1d_miss - stalls_l2_miss  (data found in L2)
L3 Hit Stalls  = stalls_l2_miss  - stalls_l3_miss  (data found in L3)
DRAM Stalls    = stalls_l3_miss                     (data from memory)
```

**Example:**
```
stalls_l1d_miss: 786M cycles
stalls_l2_miss:  219M cycles
stalls_l3_miss:   88M cycles

L2 Hit Stalls: 786M - 219M = 567M (72% of memory stalls)  ← Dominant!
L3 Hit Stalls: 219M - 88M  = 131M (17% of memory stalls)
DRAM Stalls:   88M         =  88M (11% of memory stalls)
```

**Optimization based on dominant stall:**
- **L2 Dominant:** Improve L1 locality, reduce working set
- **L3 Dominant:** Tile to fit in L2, improve temporal locality
- **DRAM Dominant:** Prefetching, bandwidth optimization, streaming stores

---

## Memory Bandwidth Events

### offcore_requests.data_rd
**What it measures:** All data read requests going off-core (to L3 or memory).

**Bandwidth estimation:**
```
Bandwidth (GB/s) = (data_rd × 64 bytes) / elapsed_time / 1e9
```

**Reference (Sapphire Rapids single socket):**
- Theoretical peak: ~300 GB/s (8-channel DDR5-4800)
- Practical peak: ~250 GB/s
- > 70% utilization: Approaching bandwidth limit

### offcore_requests.demand_data_rd
**What it measures:** Demand (non-prefetch) data reads only.

**Prefetch calculation:**
```
Prefetch reads = data_rd - demand_data_rd
Prefetch ratio = Prefetch reads / data_rd
```

**Interpretation:**
- High prefetch ratio (30-50%): Predictable access pattern, prefetcher helping
- Low prefetch ratio (<10%): Random access pattern, prefetcher not effective

---

## FLOPs Events

### Scalar vs Packed (Vector) Operations

| Event | Width | SP FLOPs/inst | DP FLOPs/inst |
|-------|-------|---------------|---------------|
| `scalar_single` / `scalar_double` | 32/64 bit | 1 | 1 |
| `128b_packed_single` / `double` | 128 bit | 4 | 2 |
| `256b_packed_single` / `double` | 256 bit | 8 | 4 |
| `512b_packed_single` / `double` | 512 bit | 16 | 8 |

### Vectorization Efficiency

```
Vector Instructions = sum of all packed FP instructions
Scalar Instructions = scalar_single + scalar_double
Total FP Instructions = Vector + Scalar

Vectorization % = Vector / Total × 100
```

**Interpretation:**
- < 10% vector: Poor vectorization, potential 4-16× speedup available
- 50-80% vector: Moderate vectorization
- > 80% vector: Good vectorization

### AVX-512 Width Utilization

On AVX-512 capable CPUs (like Sapphire Rapids):
```
512b ratio = 512b_packed / (256b_packed + 512b_packed)
```

**If 512b ratio < 50%:**
- Compiler may be using 256-bit fallbacks
- Try: `-march=native -mprefer-vector-width=512`
- Check library versions (some default to 256-bit)

---

## Branch Events

### branch-instructions / branch-misses

**Interpretation:**
- Miss rate < 1%: Excellent prediction
- Miss rate 1-5%: Acceptable
- Miss rate > 5%: Consider optimization

**Misprediction penalty:**
- ~15-20 cycles per mispredict on modern CPUs
- Impact estimation: `(branch_misses × 20) / cycles × 100%`

**Optimization:**
- Profile-Guided Optimization (PGO)
- Branchless algorithms (CMOV, bitwise ops)
- Loop unrolling to reduce branch frequency
- `__builtin_expect()` for likely/unlikely hints

---

## TLB Events

### dTLB-load-misses / iTLB-load-misses

**What they measure:** Page table walk overhead when virtual→physical address translation fails in TLB.

**When to worry:**
- dTLB misses > 1% of loads: Consider huge pages (2MB or 1GB)
- iTLB misses high with high i-cache misses: Code spread across too many pages

**Optimization:**
- Linux: `madvise(addr, size, MADV_HUGEPAGE)` or explicit huge pages
- Improve data locality to reduce unique pages accessed
- Align hot data/code to huge page boundaries

---

## Derived Metrics

### IPC (Instructions Per Cycle)

```
IPC = instructions / cycles
```

**Sapphire Rapids thresholds (6-wide issue):**
- < 0.5: Very low (severe stalling)
- 0.5-1.5: Low (significant stalling)
- 1.5-3.0: Moderate (room for improvement)
- 3.0-4.0: Good
- ≥ 4.0: Excellent (approaching peak)

### CPI (Cycles Per Instruction)

```
CPI = cycles / instructions = 1 / IPC
```

Lower is better. CPI > 2 indicates significant stalling.

### Operational Intensity (OI)

```
OI = total_FLOPs / (LLC_load_misses × 64 bytes)
```

**Classification:**
- OI < 5: Memory bound (optimize data movement)
- OI 5-15: Balanced (both memory and compute matter)
- OI > 15: Compute bound (optimize vectorization, ALU throughput)

### L1 Reuse Ratio

```
L1_Reuse = L1-dcache-loads / l2_rqsts.references
```

**Interpretation:**
- Higher = better L1 effectiveness
- Compare between runs to measure locality improvements
- Significant increase indicates better data reuse

### Memory Traffic Efficiency

```
Traffic_Efficiency = instructions / l2_rqsts.references
```

**Interpretation:**
- Higher = more work done per L2 access
- Compare between implementations

---

## Common Patterns and What They Mean

### Pattern: High stalls but good cache hit rates
**Cause:** Execution dependencies, not memory
**Check:** Long dependency chains (div/sqrt), pointer chasing in L1

### Pattern: L1 miss ratio > 100%
**Cause:** Hardware prefetcher active
**Meaning:** Access pattern is predictable (usually good)

### Pattern: High L2 references, moderate L2 hit rate
**Cause:** Working set thrashing L2
**Fix:** Tile/block to fit in L2

### Pattern: High LLC-store-misses
**Cause:** RFO traffic for writes
**Fix:** Non-temporal stores for write-only buffers

### Pattern: High memory bandwidth but low IPC
**Cause:** Memory bound, waiting for data
**Fix:** Improve locality, reduce traffic, hide latency with prefetching

### Pattern: Low vectorization, high scalar FP
**Cause:** Code not vectorized
**Fix:** Compiler flags, intrinsics, or vectorized libraries

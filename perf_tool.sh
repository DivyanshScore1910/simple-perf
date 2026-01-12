#!/bin/bash
#
# perf_tool.sh - Advanced perf profiling tool for performance analysis
#
# Measures L1, L2, L3 cache hits/misses, stalls, memory bandwidth, FLOPs,
# branch metrics, TLB misses, CPU stats, and provides automated insights.
#
# Usage:
#   ./perf_tool.sh --record-cache-metrics --output <name> --run <executable> [args...]
#   ./perf_tool.sh --visualize --input <name>
#   ./perf_tool.sh --compare <baseline> <optimized>
#   ./perf_tool.sh --help
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Core perf events (always recorded)
CORE_EVENTS=(
    # L1 Cache
    "L1-dcache-loads"
    "L1-dcache-load-misses"
    "L1-dcache-stores"
    "L1-icache-load-misses"
    # L2 Cache (Intel-specific)
    "l2_rqsts.references"
    "l2_rqsts.miss"
    # L3/LLC Cache
    "LLC-loads"
    "LLC-load-misses"
    "LLC-stores"
    "LLC-store-misses"
    # Overall cache
    "cache-references"
    "cache-misses"
    # Branch
    "branch-instructions"
    "branch-misses"
    # TLB
    "dTLB-load-misses"
    "iTLB-load-misses"
    # CPU
    "cycles"
    "instructions"
)

# Stall analysis events
STALL_EVENTS=(
    "cycle_activity.stalls_total"
    "cycle_activity.cycles_mem_any"
    "cycle_activity.stalls_l1d_miss"
    "cycle_activity.stalls_l2_miss"
    "cycle_activity.stalls_l3_miss"
)

# Memory bandwidth events
MEMORY_EVENTS=(
    "offcore_requests.data_rd"
    "offcore_requests.demand_data_rd"
)

# FLOPs events (SP and DP)
FLOPS_EVENTS=(
    "fp_arith_inst_retired.scalar_single"
    "fp_arith_inst_retired.scalar_double"
    "fp_arith_inst_retired.128b_packed_single"
    "fp_arith_inst_retired.256b_packed_single"
    "fp_arith_inst_retired.512b_packed_single"
    "fp_arith_inst_retired.128b_packed_double"
    "fp_arith_inst_retired.256b_packed_double"
    "fp_arith_inst_retired.512b_packed_double"
)

# TMA events (Intel Top-Down Microarchitecture Analysis)
# NOTE: TMA events require system-wide mode (-a flag) which measures entire system
# For per-process profiling, we skip these. Use --system-wide flag to enable.
TMA_EVENTS=(
    # "topdown-retiring"
    # "topdown-bad-spec"
    # "topdown-fe-bound"
    # "topdown-be-bound"
)

# Show help message function
show_help() {
    echo -e "${BOLD}perf_tool.sh${NC} - Advanced perf profiling tool for performance analysis"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo "  $0 --record-cache-metrics --output <name> --run <executable> [args...]"
    echo "  $0 --visualize --input <name>"
    echo "  $0 --compare <baseline> <optimized>"
    echo "  $0 --help"
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo "  --record-cache-metrics    Record comprehensive performance metrics"
    echo "  --output <name>           Output file name (auto-suffixed if exists)"
    echo "  --run <executable>        Executable to profile (followed by its arguments)"
    echo "  --visualize               Display metrics with analysis and insights"
    echo "  --input <name>            Input file name to visualize"
    echo "  --no-insights             Skip the automated insights section"
    echo "  --compare <base> <opt>    Compare two metric files side-by-side"
    echo "  --help                    Show this help message"
    echo ""
    echo -e "${BOLD}METRICS RECORDED:${NC}"
    echo ""
    echo -e "  ${CYAN}Cache Metrics:${NC}"
    echo "    L1 Cache:   L1-dcache-loads, L1-dcache-load-misses, L1-dcache-stores"
    echo "                L1-icache-load-misses"
    echo "    L2 Cache:   l2_rqsts.references, l2_rqsts.miss"
    echo "    L3/LLC:     LLC-loads, LLC-load-misses, LLC-stores, LLC-store-misses"
    echo "    Overall:    cache-references, cache-misses"
    echo ""
    echo -e "  ${CYAN}Stall Analysis:${NC}"
    echo "    cycle_activity.stalls_total, stalls_mem_any, stalls_l1d_miss"
    echo "    cycle_activity.stalls_l2_miss, stalls_l3_miss"
    echo ""
    echo -e "  ${CYAN}Memory Bandwidth:${NC}"
    echo "    offcore_requests.all_data_rd, demand_data_rd"
    echo ""
    echo -e "  ${CYAN}Floating Point:${NC}"
    echo "    fp_arith_inst_retired.scalar_single, scalar_double"
    echo "    fp_arith_inst_retired.128b_packed, 256b_packed, 512b_packed"
    echo ""
    echo -e "  ${CYAN}Top-Down Analysis (TMA):${NC}"
    echo "    topdown-retiring, topdown-bad-spec, topdown-fe-bound, topdown-be-bound"
    echo ""
    echo -e "  ${CYAN}Other:${NC}"
    echo "    Branch:     branch-instructions, branch-misses"
    echo "    TLB:        dTLB-load-misses, iTLB-load-misses"
    echo "    CPU:        cycles, instructions"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo "  # Record metrics for a GEMM test"
    echo "  $0 --record-cache-metrics --output gemm_metrics --run ./gemm_vtune_test 1"
    echo ""
    echo "  # Visualize metrics with insights"
    echo "  $0 --visualize --input gemm_metrics"
    echo ""
    echo "  # Compare baseline vs optimized"
    echo "  $0 --compare baseline optimized"
    echo ""
    echo "  # With environment variables"
    echo "  export LD_PRELOAD=/path/to/libgomp.so"
    echo "  export OMP_NUM_THREADS=56"
    echo "  $0 --record-cache-metrics --output test --run ./my_program"
    echo ""
}

record_cache_metrics() {
    local output_file="$1"
    shift
    local executable="$@"

    if [[ -z "$output_file" ]]; then
        echo -e "${RED}Error: --output <name> is required${NC}"
        exit 1
    fi

    if [[ -z "$executable" ]]; then
        echo -e "${RED}Error: --run <executable> is required${NC}"
        exit 1
    fi

    # Check if file exists, rename existing file with timestamp suffix
    if [[ -f "${output_file}.txt" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${output_file}_${timestamp}"
        mv "${output_file}.txt" "${backup_file}.txt"
        echo -e "${YELLOW}Existing file renamed to: ${backup_file}.txt${NC}"
    fi

    # Combine all events
    local all_events=("${CORE_EVENTS[@]}" "${STALL_EVENTS[@]}" "${MEMORY_EVENTS[@]}" "${FLOPS_EVENTS[@]}" "${TMA_EVENTS[@]}")

    # Build event string
    local events=""
    for event in "${all_events[@]}"; do
        if [[ -n "$events" ]]; then
            events="${events},"
        fi
        events="${events}${event}"
    done

    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}            Perf Performance Metrics Recording${NC}"
    echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Output file:${NC} ${output_file}.txt"
    echo -e "${YELLOW}Command:${NC} ${executable}"
    echo ""
    echo -e "${YELLOW}Environment:${NC}"
    echo "  LD_PRELOAD=${LD_PRELOAD:-<not set>}"
    echo "  OMP_NUM_THREADS=${OMP_NUM_THREADS:-<not set>}"
    echo ""
    echo -e "${YELLOW}Events being recorded:${NC}"
    echo "  Core: ${#CORE_EVENTS[@]} events (cache, branch, TLB, CPU)"
    echo "  Stall: ${#STALL_EVENTS[@]} events (cycle stall analysis)"
    echo "  Memory: ${#MEMORY_EVENTS[@]} events (bandwidth)"
    echo "  FLOPs: ${#FLOPS_EVENTS[@]} events (floating point)"
    echo "  TMA: ${#TMA_EVENTS[@]} events (top-down analysis)"
    echo ""
    echo -e "${GREEN}Starting perf stat...${NC}"
    echo ""

    # Run perf stat
    perf stat -e "$events" -o "${output_file}.txt" -- $executable

    echo ""
    echo -e "${GREEN}Recording complete!${NC}"
    echo -e "Metrics saved to: ${BOLD}${output_file}.txt${NC}"
    echo ""
    echo -e "To visualize: ${CYAN}bash $0 --visualize --input ${output_file}${NC}"
}

visualize_metrics() {
    local input_file="$1"
    local no_insights="$2"

    if [[ -z "$input_file" ]]; then
        echo -e "${RED}Error: --input <name> is required${NC}"
        exit 1
    fi

    local file_path="${input_file}.txt"
    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}Error: File not found: ${file_path}${NC}"
        exit 1
    fi

    # Detect CPU cache sizes from system
    local l2_cache_kb=0
    local l3_cache_kb=0
    if [[ -f /sys/devices/system/cpu/cpu0/cache/index2/size ]]; then
        local l2_size=$(cat /sys/devices/system/cpu/cpu0/cache/index2/size 2>/dev/null)
        # Parse size (e.g., "2048K" -> 2048)
        l2_cache_kb=$(echo "$l2_size" | sed 's/[^0-9]//g')
    fi
    if [[ -f /sys/devices/system/cpu/cpu0/cache/index3/size ]]; then
        local l3_size=$(cat /sys/devices/system/cpu/cpu0/cache/index3/size 2>/dev/null)
        l3_cache_kb=$(echo "$l3_size" | sed 's/[^0-9]//g')
    fi

    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                         Performance Analysis Report${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Source:${NC} ${file_path}"
    echo ""

    # Use awk to parse, format, and generate insights
    awk -v RED="${RED}" -v GREEN="${GREEN}" -v YELLOW="${YELLOW}" -v BLUE="${BLUE}" \
        -v CYAN="${CYAN}" -v MAGENTA="${MAGENTA}" -v NC="${NC}" -v BOLD="${BOLD}" -v DIM="${DIM}" \
        -v no_insights="$no_insights" -v l2_cache_kb="$l2_cache_kb" -v l3_cache_kb="$l3_cache_kb" '
    BEGIN {
        # Initialize variables
        time_elapsed = 0
    }

    # Extract time elapsed
    /seconds time elapsed/ {
        match($0, /[0-9.]+/)
        time_elapsed = substr($0, RSTART, RLENGTH) + 0
    }

    # Skip non-data lines
    /^#/ { next }
    /^[[:space:]]*$/ { next }
    /Performance counter stats/ { next }
    /seconds time elapsed/ { next }
    /seconds user/ { next }
    /seconds sys/ { next }

    # Parse metric lines
    {
        orig_line = $0
        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
        if ($0 !~ /^[0-9,<]+/) next

        # Handle "<not counted>" or "<not supported>" cases
        if ($1 ~ /^</) {
            count_fmt = "<N/A>"
            count = 0
            event = $2
        } else {
            count_fmt = $1
            count = $1
            gsub(/,/, "", count)
            count = count + 0
            event = $2
        }

        # Extract rate info
        rate = ""
        if (index(orig_line, "#") > 0) {
            rate_part = orig_line
            sub(/.*#[[:space:]]*/, "", rate_part)
            sub(/[[:space:]]*\([0-9.]+%\).*/, "", rate_part)
            rate = rate_part
            if (match(rate, /[0-9.]+%/)) {
                rate = substr(rate, RSTART, RLENGTH)
            } else if (match(rate, /[0-9.]+[[:space:]]+insn/)) {
                match(rate, /[0-9.]+/)
                rate = "IPC: " substr(rate, RSTART, RLENGTH)
            }
        }

        # Store all metrics for later use
        metrics[event] = count
        metrics_fmt[event] = count_fmt
        metrics_rate[event] = rate
        metric_order[++metric_count] = event

        # Map event names to categories and friendly names
        category[event] = "Other"
        friendly[event] = event

        # L1 Cache
        if (event == "L1-dcache-loads") { friendly[event] = "L1D Loads"; category[event] = "L1 Cache" }
        else if (event == "L1-dcache-load-misses") { friendly[event] = "L1D Load Misses"; category[event] = "L1 Cache" }
        else if (event == "L1-dcache-stores") { friendly[event] = "L1D Stores"; category[event] = "L1 Cache" }
        else if (event == "L1-icache-load-misses") { friendly[event] = "L1I Misses"; category[event] = "L1 Cache" }
        # L2 Cache
        else if (event == "l2_rqsts.references") { friendly[event] = "L2 References"; category[event] = "L2 Cache" }
        else if (event == "l2_rqsts.miss") { friendly[event] = "L2 Misses"; category[event] = "L2 Cache" }
        # L3 Cache
        else if (event == "LLC-loads") { friendly[event] = "L3/LLC Loads"; category[event] = "L3 Cache" }
        else if (event == "LLC-load-misses") { friendly[event] = "L3/LLC Load Misses"; category[event] = "L3 Cache" }
        else if (event == "LLC-stores") { friendly[event] = "L3/LLC Stores"; category[event] = "L3 Cache" }
        else if (event == "LLC-store-misses") { friendly[event] = "L3/LLC Store Misses"; category[event] = "L3 Cache" }
        # Overall Cache
        else if (event == "cache-references") { friendly[event] = "Total Cache Refs"; category[event] = "Cache" }
        else if (event == "cache-misses") { friendly[event] = "Total Cache Misses"; category[event] = "Cache" }
        # Branch
        else if (event == "branch-instructions") { friendly[event] = "Branch Instructions"; category[event] = "Branch" }
        else if (event == "branch-misses") { friendly[event] = "Branch Misses"; category[event] = "Branch" }
        # TLB
        else if (event == "dTLB-load-misses") { friendly[event] = "dTLB Load Misses"; category[event] = "TLB" }
        else if (event == "iTLB-load-misses") { friendly[event] = "iTLB Load Misses"; category[event] = "TLB" }
        # CPU
        else if (event == "cycles") { friendly[event] = "CPU Cycles"; category[event] = "CPU" }
        else if (event == "instructions") { friendly[event] = "Instructions"; category[event] = "CPU" }
        # Stalls
        else if (event == "cycle_activity.stalls_total") { friendly[event] = "Total Stall Cycles"; category[event] = "Stalls" }
        else if (event == "cycle_activity.cycles_mem_any") { friendly[event] = "Memory Stall Cycles"; category[event] = "Stalls" }
        else if (event == "cycle_activity.stalls_l1d_miss") { friendly[event] = "L1D Miss Stalls"; category[event] = "Stalls" }
        else if (event == "cycle_activity.stalls_l2_miss") { friendly[event] = "L2 Miss Stalls"; category[event] = "Stalls" }
        else if (event == "cycle_activity.stalls_l3_miss") { friendly[event] = "L3 Miss Stalls"; category[event] = "Stalls" }
        # Memory
        else if (event == "offcore_requests.data_rd") { friendly[event] = "All Data Reads"; category[event] = "Memory BW" }
        else if (event == "offcore_requests.demand_data_rd") { friendly[event] = "Demand Data Reads"; category[event] = "Memory BW" }
        # FLOPs
        else if (event ~ /fp_arith_inst_retired/) {
            category[event] = "FLOPs"
            if (event ~ /scalar_single/) friendly[event] = "Scalar SP FLOPs"
            else if (event ~ /scalar_double/) friendly[event] = "Scalar DP FLOPs"
            else if (event ~ /128b_packed_single/) friendly[event] = "128b Packed SP"
            else if (event ~ /256b_packed_single/) friendly[event] = "256b Packed SP"
            else if (event ~ /512b_packed_single/) friendly[event] = "512b Packed SP"
            else if (event ~ /128b_packed_double/) friendly[event] = "128b Packed DP"
            else if (event ~ /256b_packed_double/) friendly[event] = "256b Packed DP"
            else if (event ~ /512b_packed_double/) friendly[event] = "512b Packed DP"
        }
        # TMA
        else if (event == "topdown-retiring") { friendly[event] = "Retiring"; category[event] = "TMA" }
        else if (event == "topdown-bad-spec") { friendly[event] = "Bad Speculation"; category[event] = "TMA" }
        else if (event == "topdown-fe-bound") { friendly[event] = "Frontend Bound"; category[event] = "TMA" }
        else if (event == "topdown-be-bound") { friendly[event] = "Backend Bound"; category[event] = "TMA" }
    }

    END {
        # Print metrics table by category
        print BOLD "┌────────────────────────────────┬────────────────────┬────────────────────┐" NC
        printf BOLD "│ %-30s │ %18s │ %18s │" NC "\n", "Event", "Count", "Rate/Info"
        print BOLD "├────────────────────────────────┼────────────────────┼────────────────────┤" NC

        # Define category order
        cat_order[1] = "L1 Cache"; cat_order[2] = "L2 Cache"; cat_order[3] = "L3 Cache"
        cat_order[4] = "Cache"; cat_order[5] = "Stalls"; cat_order[6] = "Memory BW"
        cat_order[7] = "FLOPs"; cat_order[8] = "TMA"; cat_order[9] = "Branch"
        cat_order[10] = "TLB"; cat_order[11] = "CPU"; cat_order[12] = "Other"

        for (c = 1; c <= 12; c++) {
            current_cat = cat_order[c]
            cat_has_items = 0
            for (i = 1; i <= metric_count; i++) {
                ev = metric_order[i]
                if (category[ev] == current_cat) {
                    cat_has_items = 1
                    break
                }
            }
            if (!cat_has_items) continue

            # Print category header
            printf "│ " CYAN "%-30s" NC " │ %18s │ %18s │\n", "── " current_cat " ──", "", ""

            for (i = 1; i <= metric_count; i++) {
                ev = metric_order[i]
                if (category[ev] == current_cat) {
                    printf "│   %-28s │ %18s │ %18s │\n", friendly[ev], metrics_fmt[ev], metrics_rate[ev]
                }
            }
        }
        print BOLD "└────────────────────────────────┴────────────────────┴────────────────────┘" NC

        # ═══════════════════════════════════════════════════════════════════
        # DERIVED METRICS SECTION
        # ═══════════════════════════════════════════════════════════════════
        print ""
        print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
        print BOLD "                              Derived Metrics" NC
        print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
        print ""

        cycles = metrics["cycles"]
        instructions = metrics["instructions"]
        l1_loads = metrics["L1-dcache-loads"]
        l1_misses = metrics["L1-dcache-load-misses"]
        l2_refs = metrics["l2_rqsts.references"]
        l2_misses = metrics["l2_rqsts.miss"]
        llc_loads = metrics["LLC-loads"]
        llc_load_misses = metrics["LLC-load-misses"]
        cache_refs = metrics["cache-references"]
        cache_miss = metrics["cache-misses"]
        branch_instr = metrics["branch-instructions"]
        branch_miss = metrics["branch-misses"]
        stalls_total = metrics["cycle_activity.stalls_total"]
        stalls_mem = metrics["cycle_activity.cycles_mem_any"]

        # IPC (calibrated for Sapphire Rapids - 6-wide issue, can achieve IPC > 4)
        if (cycles > 0 && instructions > 0) {
            ipc = instructions / cycles
            printf "  " BOLD "IPC (Instructions Per Cycle):" NC " "
            if (ipc < 0.5) printf RED "%.3f" NC " (Very Low - severe stalling)\n", ipc
            else if (ipc < 1.5) printf YELLOW "%.3f" NC " (Low - significant stalling)\n", ipc
            else if (ipc < 3.0) printf YELLOW "%.3f" NC " (Moderate - room for improvement)\n", ipc
            else if (ipc < 4.0) printf GREEN "%.3f" NC " (Good)\n", ipc
            else printf GREEN "%.3f" NC " (Excellent - near peak)\n", ipc
        }

        # CPI
        if (cycles > 0 && instructions > 0) {
            cpi = cycles / instructions
            printf "  " BOLD "CPI (Cycles Per Instruction):" NC " %.3f\n", cpi
        }

        # L1 Miss/Load Ratio
        if (l1_loads > 0 && l1_misses > 0) {
            l1_ratio = (l1_misses * 100.0) / l1_loads
            printf "  " BOLD "L1D Miss/Load Ratio:" NC " "
            if (l1_ratio > 100) {
                printf YELLOW "%.1f%%" NC " (>100%% = prefetcher active)\n", l1_ratio
            } else {
                printf GREEN "%.2f%%" NC "\n", l1_ratio
            }
        }

        # L2 Hit Rate
        if (l2_refs > 0) {
            l2_hit_rate = 100 - (l2_misses * 100.0 / l2_refs)
            printf "  " BOLD "L2 Cache Hit Rate:" NC " "
            if (l2_hit_rate < 50) printf RED "%.2f%%" NC " (Poor)\n", l2_hit_rate
            else if (l2_hit_rate < 80) printf YELLOW "%.2f%%" NC " (Moderate)\n", l2_hit_rate
            else printf GREEN "%.2f%%" NC " (Good)\n", l2_hit_rate
        }

        # L3/LLC Hit Rate
        if (llc_loads > 0) {
            llc_hit_rate = 100 - (llc_load_misses * 100.0 / llc_loads)
            printf "  " BOLD "L3/LLC Load Hit Rate:" NC " "
            if (llc_hit_rate > 95) printf GREEN "%.2f%%" NC " (Excellent)\n", llc_hit_rate
            else if (llc_hit_rate > 80) printf YELLOW "%.2f%%" NC "\n", llc_hit_rate
            else printf RED "%.2f%%" NC " (High memory traffic)\n", llc_hit_rate
        }

        # Overall Cache Hit Rate
        if (cache_refs > 0) {
            cache_hit_rate = 100 - (cache_miss * 100.0 / cache_refs)
            printf "  " BOLD "Overall Cache Hit Rate:" NC " " GREEN "%.2f%%" NC "\n", cache_hit_rate
        }

        # Branch Miss Rate
        if (branch_instr > 0) {
            branch_miss_rate = (branch_miss * 100.0) / branch_instr
            printf "  " BOLD "Branch Miss Rate:" NC " "
            if (branch_miss_rate < 1) printf GREEN "%.3f%%" NC " (Excellent)\n", branch_miss_rate
            else if (branch_miss_rate < 5) printf YELLOW "%.2f%%" NC "\n", branch_miss_rate
            else printf RED "%.2f%%" NC " (High)\n", branch_miss_rate
        }

        # Stall Analysis
        if (cycles > 0 && stalls_total > 0) {
            stall_pct = (stalls_total * 100.0) / cycles
            printf "  " BOLD "Stall Cycles:" NC " "
            if (stall_pct > 50) printf RED "%.1f%%" NC " of cycles\n", stall_pct
            else if (stall_pct > 25) printf YELLOW "%.1f%%" NC " of cycles\n", stall_pct
            else printf GREEN "%.1f%%" NC " of cycles\n", stall_pct

            if (stalls_mem > 0) {
                mem_stall_pct = (stalls_mem * 100.0) / cycles
                printf "    " DIM "└─ Memory Stalls:" NC " %.1f%% of cycles\n", mem_stall_pct
            }
        }

        # Memory Intensity
        if (instructions > 0 && l1_loads > 0) {
            mem_intensity = l1_loads / instructions
            printf "  " BOLD "Memory Intensity:" NC " %.3f loads/instruction\n", mem_intensity
        }

        # GFLOPS (if time elapsed and FP events available)
        if (time_elapsed > 0) {
            total_flops = 0
            # Scalar: 1 op each
            total_flops += metrics["fp_arith_inst_retired.scalar_single"]
            total_flops += metrics["fp_arith_inst_retired.scalar_double"]
            # SP packed: 4/8/16 ops per instruction
            total_flops += metrics["fp_arith_inst_retired.128b_packed_single"] * 4
            total_flops += metrics["fp_arith_inst_retired.256b_packed_single"] * 8
            total_flops += metrics["fp_arith_inst_retired.512b_packed_single"] * 16
            # DP packed: 2/4/8 ops per instruction
            total_flops += metrics["fp_arith_inst_retired.128b_packed_double"] * 2
            total_flops += metrics["fp_arith_inst_retired.256b_packed_double"] * 4
            total_flops += metrics["fp_arith_inst_retired.512b_packed_double"] * 8

            if (total_flops > 0) {
                gflops = total_flops / (time_elapsed * 1e9)
                printf "  " BOLD "GFLOPS:" NC " " GREEN "%.2f" NC "\n", gflops
            }
        }

        # Elapsed time
        if (time_elapsed > 0) {
            printf "  " BOLD "Elapsed Time:" NC " %.3f seconds\n", time_elapsed
        }

        # ═══════════════════════════════════════════════════════════════════
        # TMA SECTION (if available)
        # ═══════════════════════════════════════════════════════════════════
        tma_retiring = metrics["topdown-retiring"]
        tma_bad_spec = metrics["topdown-bad-spec"]
        tma_fe_bound = metrics["topdown-fe-bound"]
        tma_be_bound = metrics["topdown-be-bound"]
        tma_total = tma_retiring + tma_bad_spec + tma_fe_bound + tma_be_bound

        if (tma_total > 0) {
            print ""
            print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
            print BOLD "                     Top-Down Microarchitecture Analysis" NC
            print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
            print ""

            retiring_pct = (tma_retiring * 100.0) / tma_total
            bad_spec_pct = (tma_bad_spec * 100.0) / tma_total
            fe_bound_pct = (tma_fe_bound * 100.0) / tma_total
            be_bound_pct = (tma_be_bound * 100.0) / tma_total

            print "  Pipeline Efficiency Breakdown:"
            print ""

            # Retiring (useful work)
            printf "  ├─ " GREEN "Retiring:" NC "        %5.1f%%  ", retiring_pct
            bar_len = int(retiring_pct / 2)
            for (b = 0; b < bar_len; b++) printf GREEN "█" NC
            for (b = bar_len; b < 50; b++) printf DIM "░" NC
            print " (useful work)"

            # Bad Speculation
            printf "  ├─ " YELLOW "Bad Speculation:" NC " %5.1f%%  ", bad_spec_pct
            bar_len = int(bad_spec_pct / 2)
            for (b = 0; b < bar_len; b++) printf YELLOW "█" NC
            for (b = bar_len; b < 50; b++) printf DIM "░" NC
            print " (mispredictions)"

            # Frontend Bound
            printf "  ├─ " CYAN "Frontend Bound:" NC "  %5.1f%%  ", fe_bound_pct
            bar_len = int(fe_bound_pct / 2)
            for (b = 0; b < bar_len; b++) printf CYAN "█" NC
            for (b = bar_len; b < 50; b++) printf DIM "░" NC
            print " (instruction supply)"

            # Backend Bound
            printf "  └─ " RED "Backend Bound:" NC "   %5.1f%%  ", be_bound_pct
            bar_len = int(be_bound_pct / 2)
            for (b = 0; b < bar_len; b++) printf RED "█" NC
            for (b = bar_len; b < 50; b++) printf DIM "░" NC
            print " (execution stalls)"

            print ""

            # Determine primary bottleneck
            max_bound = 0
            bottleneck = "None"
            if (be_bound_pct > max_bound && be_bound_pct > 20) { max_bound = be_bound_pct; bottleneck = "Backend Bound (execution stalls)" }
            if (fe_bound_pct > max_bound && fe_bound_pct > 20) { max_bound = fe_bound_pct; bottleneck = "Frontend Bound (instruction fetch)" }
            if (bad_spec_pct > max_bound && bad_spec_pct > 10) { max_bound = bad_spec_pct; bottleneck = "Bad Speculation (branch misprediction)" }

            if (bottleneck != "None") {
                printf "  " YELLOW "Primary TMA Bottleneck:" NC " %s\n", bottleneck
            }
        }

        # ═══════════════════════════════════════════════════════════════════
        # INSIGHTS SECTION (skip if --no-insights flag is set)
        # ═══════════════════════════════════════════════════════════════════
        if (no_insights != "1") {
        print ""
        print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
        print BOLD "                            Performance Insights" NC
        print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
        print ""

        insights_count = 0
        primary_bottleneck = ""
        secondary_bottleneck = ""

        # Stall Analysis (check this first as this is often the root cause)
        if (cycles > 0 && stalls_total > 0) {
            stall_pct = (stalls_total * 100.0) / cycles
            if (stall_pct > 50) {
                msg = sprintf("⚠ HIGH STALL RATE (%.1f%% of cycles) - CPU mostly waiting", stall_pct)
                print RED msg NC
                if (stalls_mem > 0) {
                    mem_stall_pct = (stalls_mem * 100.0) / cycles
                    printf "  └─ Memory-related cycles: %.1f%% of total\n", mem_stall_pct
                }
                print "  └─ " DIM "Recommendation: Optimize memory access patterns, improve cache utilization" NC
                print ""
                insights_count++
                if (primary_bottleneck == "") {
                    primary_bottleneck = sprintf("High stall rate (%.0f%% of cycles)", stall_pct)
                }
            }
        }

        # L1 Cache Analysis
        if (l1_loads > 0 && l1_misses > 0) {
            l1_miss_rate = (l1_misses * 100.0) / l1_loads
            # Only warn if miss rate is high but not in prefetching territory (>100%)
            if (l1_miss_rate > 50 && l1_miss_rate <= 100) {
                print YELLOW "⚠ HIGH L1 MISS RATE (" sprintf("%.1f%%", l1_miss_rate) ") - Poor L1 cache utilization" NC
                print "  └─ Most loads miss L1 cache (32-48KB per core)"
                print "  └─ " DIM "Recommendation: Improve spatial/temporal locality, consider prefetching" NC
                print ""
                insights_count++
                if (primary_bottleneck == "") primary_bottleneck = "L1 cache misses"
                else if (secondary_bottleneck == "") secondary_bottleneck = "L1 cache misses"
            }
        }

        # IPC Analysis
        if (cycles > 0 && instructions > 0) {
            ipc = instructions / cycles
            if (ipc < 0.5) {
                print YELLOW "⚠ LOW IPC (" sprintf("%.2f", ipc) ") - CPU is frequently stalling" NC
                if (stalls_mem > 0 && cycles > 0) {
                    mem_stall_pct = (stalls_mem * 100.0) / cycles
                    printf "  └─ Memory stalls account for %.1f%% of cycles\n", mem_stall_pct
                }
                print "  └─ " DIM "Recommendation: Improve data locality, consider blocking/tiling" NC
                print ""
                insights_count++
                if (primary_bottleneck == "") primary_bottleneck = "Low IPC (execution stalls)"
            } else if (ipc >= 0.5 && ipc < 1.0) {
                # Moderate IPC - only flag if there are high stalls
                if (stalls_total > 0 && cycles > 0) {
                    stall_pct = (stalls_total * 100.0) / cycles
                    if (stall_pct > 50) {
                        print YELLOW "⚠ MODERATE IPC (" sprintf("%.2f", ipc) ") with high stalls" NC
                        print "  └─ IPC limited by memory/execution stalls"
                        print ""
                        insights_count++
                    }
                }
            } else if (ipc >= 1.0) {
                print GREEN "✓ GOOD IPC (" sprintf("%.2f", ipc) ") - CPU executing efficiently" NC
                print ""
                insights_count++
            }
        }

        # L2 Cache Analysis (uses detected L2 cache size)
        if (l2_refs > 0) {
            l2_miss_rate = (l2_misses * 100.0) / l2_refs
            if (l2_miss_rate > 50) {
                print YELLOW "⚠ HIGH L2 MISS RATE (" sprintf("%.1f%%", l2_miss_rate) ") - Data not fitting in L2" NC
                if (l2_cache_kb > 0) {
                    l2_mb = l2_cache_kb / 1024
                    target_mb = l2_mb * 0.75  # Target 75% of L2
                    printf "  └─ L2 cache: %.1f MB per core (detected)\n", l2_mb
                    printf "  └─ Target working set: ~%.1f MB\n", target_mb
                } else {
                    print "  └─ L2 cache: unknown (check /sys/devices/system/cpu/cpu0/cache/)"
                }
                print "  └─ " DIM "Recommendations:" NC
                print "  └─   • For BF16 GEMM: 512x512 to 768x768 tiles"
                print "  └─   • For FP32 GEMM: 256x256 to 384x384 tiles"
                print ""
                insights_count++
                if (primary_bottleneck == "") primary_bottleneck = "L2 cache misses"
                else if (secondary_bottleneck == "") secondary_bottleneck = "L2 cache misses"
            } else if (l2_miss_rate < 20) {
                print GREEN "✓ GOOD L2 HIT RATE (" sprintf("%.1f%%", 100 - l2_miss_rate) ") - Data locality is good" NC
                print ""
                insights_count++
            }
        }

        # L3/LLC Analysis
        if (llc_loads > 0) {
            llc_hit_rate = 100 - (llc_load_misses * 100.0 / llc_loads)
            if (llc_hit_rate > 95) {
                print GREEN "✓ EXCELLENT L3 HIT RATE (" sprintf("%.2f%%", llc_hit_rate) ") - Data fits in L3" NC
                print "  └─ No main memory bandwidth bottleneck"
                print ""
                insights_count++
            } else if (llc_hit_rate < 80) {
                print RED "⚠ HIGH L3 MISS RATE (" sprintf("%.1f%%", 100 - llc_hit_rate) ") - Significant memory traffic" NC
                print "  └─ " DIM "Recommendation: Data exceeds L3, optimize for memory bandwidth" NC
                print ""
                insights_count++
                if (primary_bottleneck == "") primary_bottleneck = "Memory bandwidth (L3 misses)"
                else if (secondary_bottleneck == "") secondary_bottleneck = "Memory bandwidth"
            }
        }

        # Branch Analysis
        if (branch_instr > 0) {
            branch_miss_rate = (branch_miss * 100.0) / branch_instr
            if (branch_miss_rate < 1) {
                print GREEN "✓ EXCELLENT BRANCH PREDICTION (" sprintf("%.2f%%", branch_miss_rate) " miss rate)" NC
                print "  └─ Branch-related optimizations not needed"
                print ""
                insights_count++
            } else if (branch_miss_rate > 5) {
                print YELLOW "⚠ HIGH BRANCH MISS RATE (" sprintf("%.2f%%", branch_miss_rate) ")" NC
                print "  └─ " DIM "Recommendation: Consider reducing branches or making them more predictable" NC
                print ""
                insights_count++
                if (secondary_bottleneck == "") secondary_bottleneck = "Branch mispredictions"
            }
        }

        # TLB Analysis
        dtlb_misses = metrics["dTLB-load-misses"]
        if (l1_loads > 0 && dtlb_misses > 0) {
            tlb_miss_rate = (dtlb_misses * 100.0) / l1_loads
            if (tlb_miss_rate > 1) {
                print YELLOW "⚠ HIGH TLB MISS RATE (" sprintf("%.2f%%", tlb_miss_rate) ")" NC
                print "  └─ " DIM "Recommendation: Consider using huge pages or improving memory layout" NC
                print ""
                insights_count++
            }
        }

        # Prefetcher Activity
        if (l1_loads > 0 && l1_misses > l1_loads) {
            prefetch_ratio = l1_misses / l1_loads
            print BLUE "ℹ ACTIVE PREFETCHING (L1 miss/load ratio: " sprintf("%.1fx", prefetch_ratio) ")" NC
            print "  └─ Hardware prefetcher is aggressively fetching data"
            print ""
            insights_count++
        }

        # Vectorization Efficiency (New)
        scalar_ops = metrics["fp_arith_inst_retired.scalar_single"] + metrics["fp_arith_inst_retired.scalar_double"]
        packed_ops = metrics["fp_arith_inst_retired.128b_packed_single"] * 4 + metrics["fp_arith_inst_retired.256b_packed_single"] * 8 + metrics["fp_arith_inst_retired.512b_packed_single"] * 16
        # Note: packed_ops here is weighted by elements to estimate "SIMD utilization", but for instruction count ratio we should use raw counts
        raw_packed_ops = metrics["fp_arith_inst_retired.128b_packed_single"] + metrics["fp_arith_inst_retired.256b_packed_single"] + metrics["fp_arith_inst_retired.512b_packed_single"]

        total_fp_inst = scalar_ops + raw_packed_ops

        if (total_fp_inst > 1000000) { # Only analyze if significant FP work detected
            vec_inst_ratio = (raw_packed_ops * 100.0) / total_fp_inst

            if (vec_inst_ratio < 10) {
                print YELLOW "⚠ LOW VECTORIZATION EFFICIENCY (" sprintf("%.1f%%", vec_inst_ratio) " vector instructions)" NC
                print "  └─ Code is dominated by scalar instructions"
                print "  └─ " DIM "Recommendation: Use compiler vectorization (-O3, -march=native) or SIMD intrinsics (AVX2/AVX-512)" NC
                print ""
                insights_count++
                if (secondary_bottleneck == "") secondary_bottleneck = "Poor Vectorization"
            } else if (vec_inst_ratio > 80) {
                print GREEN "✓ EXCELLENT VECTORIZATION (" sprintf("%.1f%%", vec_inst_ratio) " vector instructions)" NC
                print ""
                insights_count++
            }
        }

        # Instruction Cache Pressure (New)
        icache_misses = metrics["L1-icache-load-misses"]
        if (instructions > 0 && icache_misses > 0) {
            # MPKI (Misses Per Kilo Instruction)
            icache_mpki = (icache_misses * 1000.0) / instructions

            if (icache_mpki > 20) {
                print YELLOW "⚠ HIGH I-CACHE MISS RATE (" sprintf("%.1f", icache_mpki) " MPKI)" NC
                print "  └─ CPU Frontend is waiting for instructions"
                print "  └─ " DIM "Recommendation: Enable PGO (Profile Guided Optimization), reduce code size, or use Huge Pages for text" NC
                print ""
                insights_count++
                if (secondary_bottleneck == "") secondary_bottleneck = "Instruction Cache Pressure"
            }
        }

        # Store Bound / RFO Analysis (New)
        llc_stores = metrics["LLC-stores"]
        llc_store_misses = metrics["LLC-store-misses"]
        if (llc_stores > 100000 && llc_store_misses > 0) {
            store_miss_rate = (llc_store_misses * 100.0) / llc_stores
            if (store_miss_rate > 50) {
                print YELLOW "⚠ HIGH LLC STORE MISS RATE (" sprintf("%.1f%%", store_miss_rate) ")" NC
                print "  └─ High RFO (Request For Ownership) traffic. CPU fetches cache lines just to overwrite them."
                print "  └─ " DIM "Recommendation: Use Non-Temporal (Streaming) Stores for large write-only buffers" NC
                print ""
                insights_count++
                if (secondary_bottleneck == "") secondary_bottleneck = "RFO / Store Bandwidth"
            }
        }

        # Memory Bandwidth Estimation (New)
        data_reads = metrics["offcore_requests.data_rd"]
        if (time_elapsed > 0 && data_reads > 0) {
            # Assuming 64-byte cache lines
            bw_bytes = data_reads * 64
            bw_gbps = bw_bytes / (time_elapsed * 1024 * 1024 * 1024)

            # This is informational as we do not know the hardware max
            print CYAN "ℹ MEMORY BANDWIDTH: " sprintf("%.2f", bw_gbps) " GB/s (Read)" NC
            if (bw_gbps > 50) {
                 print "  └─ " DIM "Note: Verify if this approaches the theoretical peak of your system (e.g. ~100GB/s for Dual DDR5)" NC
            }
            print ""
            insights_count++
        }

        # Branch Misprediction Penalty (New)
        if (cycles > 0 && branch_miss > 0) {
             # Assuming ~20 cycles penalty for modern out-of-order CPUs
             branch_penalty_cycles = branch_miss * 20
             branch_penalty_pct = (branch_penalty_cycles * 100.0) / cycles

             if (branch_penalty_pct > 5) {
                  print YELLOW "⚠ BRANCH MISPREDICTION IMPACT (~" sprintf("%.1f%%", branch_penalty_pct) " of cycles lost)" NC
                  print "  └─ Estimated " sprintf("%.1f", branch_penalty_pct) "% of time wasted flushing the pipeline"
                  print ""
                  insights_count++
                  if (secondary_bottleneck == "") secondary_bottleneck = "Branch Mispredictions"
             }
        }

        # Non-Memory / Execution Stalls (New)
        if (cycles > 0 && stalls_total > 0) {
            # stalls_l1d_miss represents stalls where a load missed L1.
            # Stalls NOT accounted for by L1 misses are either L1 hit latency stalls or non-memory stalls.
            # This is an approximation.
            l1d_miss_stalls = metrics["cycle_activity.stalls_l1d_miss"]
            if (l1d_miss_stalls > 0) {
                other_stalls = stalls_total - l1d_miss_stalls
                if (other_stalls > 0) {
                    other_stall_pct = (other_stalls * 100.0) / cycles

                    # If "other stalls" > 30% of cycles, this is significant
                    if (other_stall_pct > 30) {
                         print YELLOW "⚠ HIGH CORE/L1 STALLS (" sprintf("%.1f%%", other_stall_pct) " of cycles)" NC
                         print "  └─ Stalls not due to L1 misses. Likely L1 hit latency (pointer chasing) or execution dependencies."
                         print "  └─ " DIM "Recommendation: Check for long dependency chains (div/sqrt) or L1-bound pointer chasing." NC
                         print ""
                         insights_count++
                         if (primary_bottleneck == "") primary_bottleneck = "Execution/L1 Stalls"
                    }
                }
            }
        }

        # Memory Stall Breakdown (New)
        # Nested breakdown of where the memory stalls are coming from
        l1d_miss_stalls = metrics["cycle_activity.stalls_l1d_miss"]
        l2_miss_stalls = metrics["cycle_activity.stalls_l2_miss"]
        l3_miss_stalls = metrics["cycle_activity.stalls_l3_miss"]

        if (l1d_miss_stalls > 0) {
             # L1D miss stalls include L2 miss stalls.
             # So (L1D miss - L2 miss) = Stalls satisfied by L2
             l2_hit_stalls = l1d_miss_stalls - l2_miss_stalls
             l3_hit_stalls = l2_miss_stalls - l3_miss_stalls
             dram_stalls = l3_miss_stalls

             if (l2_hit_stalls < 0) l2_hit_stalls = 0
             if (l3_hit_stalls < 0) l3_hit_stalls = 0

             # Determine the dominant component
             max_component_val = 0
             max_component_name = ""

             if (l2_hit_stalls > max_component_val) { max_component_val = l2_hit_stalls; max_component_name = "L2 Latency" }
             if (l3_hit_stalls > max_component_val) { max_component_val = l3_hit_stalls; max_component_name = "L3 Latency" }
             if (dram_stalls > max_component_val) { max_component_val = dram_stalls; max_component_name = "DRAM Latency" }

             if (max_component_val > (l1d_miss_stalls * 0.5)) {
                 # Only print if one component is dominant (>50% of memory stalls)
                 print BLUE "ℹ MEMORY LATENCY BREAKDOWN" NC
                 print "  └─ Dominant Factor: " BOLD max_component_name NC
                 printf "  └─ L2 Hit Stalls:    %5.1f%% of memory stalls\n", (l2_hit_stalls * 100.0 / l1d_miss_stalls)
                 printf "  └─ L3 Hit Stalls:    %5.1f%% of memory stalls\n", (l3_hit_stalls * 100.0 / l1d_miss_stalls)
                 printf "  └─ DRAM/Remote:      %5.1f%% of memory stalls\n", (dram_stalls * 100.0 / l1d_miss_stalls)
                 print ""
                 insights_count++

                 # Enhanced stall recommendations based on dominant component (SPR-specific)
                 if (max_component_name == "DRAM Latency") {
                     print YELLOW "  ⚠ DRAM LATENCY DOMINANT" NC
                     print "    └─ Memory bandwidth may be saturated"
                     print "    └─ " DIM "Recommendations:" NC
                     print "    └─   • Use cache blocking/tiling to reduce DRAM accesses"
                     print "    └─   • Consider non-temporal stores for write-only buffers"
                     print "    └─   • Add software prefetching (prefetcht0/prefetcht1)"
                     print ""
                 } else if (max_component_name == "L3 Latency") {
                     print YELLOW "  ⚠ L3 LATENCY DOMINANT" NC
                     print "    └─ Data exceeds L2 but mostly fits in L3"
                     print "    └─ " DIM "Recommendations:" NC
                     if (l2_cache_kb > 0) {
                         l2_mb = l2_cache_kb / 1024
                         printf "    └─   • Improve temporal locality within L2 (%.1f MB per core)\n", l2_mb
                     } else {
                         print "    └─   • Improve temporal locality within L2"
                     }
                     print "    └─   • Check thread placement for L3 sharing conflicts"
                     print ""
                 } else if (max_component_name == "L2 Latency") {
                     print YELLOW "  ⚠ L2 LATENCY DOMINANT" NC
                     print "    └─ Working set thrashing L2 cache"
                     print "    └─ " DIM "Recommendations:" NC
                     if (l2_cache_kb > 0) {
                         l2_mb = l2_cache_kb / 1024
                         target_mb = l2_mb * 0.75
                         printf "    └─   • Tile/block to fit working set in ~%.1f MB (L2 = %.1f MB)\n", target_mb, l2_mb
                     } else {
                         print "    └─   • Tile/block to fit working set in L2 cache"
                     }
                     print "    └─   • For BF16 GEMM: Try 512x512 tiles"
                     print "    └─   • For FP32 GEMM: Try 256x256 tiles"
                     print ""
                 }
             }
        }

        # ═══════════════════════════════════════════════════════════════════
        # SAPPHIRE RAPIDS SPECIFIC INSIGHTS
        # ═══════════════════════════════════════════════════════════════════

        # Operational Intensity (Compute vs Memory Bound Classification)
        llc_load_misses = metrics["LLC-load-misses"]
        if (total_flops > 0 && llc_load_misses > 0) {
            # OI = FLOPs / Bytes transferred (LLC misses * 64 bytes per cache line)
            bytes_transferred = llc_load_misses * 64
            operational_intensity = total_flops / bytes_transferred

            print CYAN "ℹ OPERATIONAL INTENSITY: " sprintf("%.2f", operational_intensity) " FLOPs/byte" NC
            if (operational_intensity < 5) {
                print "  └─ Classification: " RED "MEMORY BOUND" NC
                print "  └─ Performance limited by memory bandwidth, not compute"
                print "  └─ " DIM "Optimize: Data locality, blocking, prefetching, streaming stores" NC
                if (primary_bottleneck == "") primary_bottleneck = "Memory Bound (low OI)"
            } else if (operational_intensity < 15) {
                print "  └─ Classification: " YELLOW "BALANCED" NC
                print "  └─ Both memory and compute optimizations will help"
            } else {
                print "  └─ Classification: " GREEN "COMPUTE BOUND" NC
                print "  └─ Performance limited by compute throughput"
                print "  └─ " DIM "Optimize: Vectorization (AVX-512/AMX), loop unrolling" NC
            }
            print ""
            insights_count++
        }

        # AVX-512 Width Utilization Check
        sp_256b = metrics["fp_arith_inst_retired.256b_packed_single"]
        sp_512b = metrics["fp_arith_inst_retired.512b_packed_single"]
        dp_256b = metrics["fp_arith_inst_retired.256b_packed_double"]
        dp_512b = metrics["fp_arith_inst_retired.512b_packed_double"]
        total_256b = sp_256b + dp_256b
        total_512b = sp_512b + dp_512b

        if (total_256b > 1000000 && total_512b > 0) {
            ratio_512b = total_512b / (total_256b + total_512b) * 100
            if (ratio_512b < 50) {
                print YELLOW "⚠ SUBOPTIMAL VECTOR WIDTH (" sprintf("%.0f%%", ratio_512b) " using 512-bit)" NC
                print "  └─ Using mostly 256-bit vectors on AVX-512 capable CPU"
                print "  └─ " DIM "Recommendations:" NC
                print "  └─   • Compile with: -march=native -mprefer-vector-width=512"
                print "  └─   • Use explicit AVX-512 intrinsics for hot loops"
                print "  └─   • Check for 256-bit fallbacks in libraries"
                print ""
                insights_count++
                if (secondary_bottleneck == "") secondary_bottleneck = "Suboptimal Vector Width"
            }
        }

        # AMX-BF16 Recommendation for Matrix Workloads
        # Trigger: High FP ops + streaming memory pattern + not already using optimal width
        total_fp_ops = metrics["fp_arith_inst_retired.scalar_single"] + metrics["fp_arith_inst_retired.scalar_double"]
        total_fp_ops += metrics["fp_arith_inst_retired.128b_packed_single"] + metrics["fp_arith_inst_retired.256b_packed_single"] + metrics["fp_arith_inst_retired.512b_packed_single"]
        total_fp_ops += metrics["fp_arith_inst_retired.128b_packed_double"] + metrics["fp_arith_inst_retired.256b_packed_double"] + metrics["fp_arith_inst_retired.512b_packed_double"]

        if (total_fp_ops > 100000000) {  # > 100M FP instructions
            llc_miss_rate = 0
            if (llc_loads > 0) {
                llc_miss_rate = (llc_load_misses * 100.0) / llc_loads
            }
            # Heuristic: Matrix workload = high FP + streaming pattern (high LLC miss) or memory bound
            is_matrix_workload = (llc_miss_rate > 15) || (operational_intensity < 10)

            if (is_matrix_workload) {
                print MAGENTA "ℹ AMX-BF16 RECOMMENDATION" NC
                print "  └─ Matrix-like workload detected on Sapphire Rapids"
                print "  └─ Intel AMX can provide " BOLD "8-16x speedup" NC " for BF16/INT8 GEMM"
                print "  └─ " DIM "Implementation:" NC
                print "  └─   • Use: _tile_loadd(), _tile_dpbf16ps(), _tile_stored()"
                print "  └─   • Compile: -mamx-tile -mamx-bf16"
                print "  └─   • Or use oneDNN/MKL for automatic AMX acceleration"
                print ""
                insights_count++
            }
        }

        # Memory Bandwidth Saturation Detection (Single-socket SPR: ~300 GB/s DDR5)
        data_reads = metrics["offcore_requests.data_rd"]
        if (time_elapsed > 0 && data_reads > 0) {
            bw_bytes = data_reads * 64
            bw_gbps = bw_bytes / (time_elapsed * 1024 * 1024 * 1024)
            # SPR single-socket 8-channel DDR5-4800: ~300 GB/s theoretical, ~250 GB/s practical
            estimated_peak = 250
            bw_utilization = (bw_gbps / estimated_peak) * 100

            if (bw_utilization > 70) {
                print YELLOW "⚠ APPROACHING MEMORY BANDWIDTH LIMIT" NC
                printf "  └─ Measured: %.1f GB/s (%.0f%% of ~%.0f GB/s estimated peak)\n", bw_gbps, bw_utilization, estimated_peak
                print "  └─ " DIM "Recommendations:" NC
                print "  └─   • Use non-temporal stores for write-only buffers"
                print "  └─   • Add software prefetching (prefetcht0/prefetcht1)"
                print "  └─   • For BF16: AMX reduces BW pressure via on-chip accumulation"
                print ""
                insights_count++
                if (primary_bottleneck == "") primary_bottleneck = "Memory Bandwidth Saturation"
            }
        }

        # Bottleneck Summary
        print "─────────────────────────────────────────────────────────────────────────────────"
        print ""
        print BOLD "BOTTLENECK SUMMARY:" NC
        if (primary_bottleneck != "") {
            printf "  Primary:   " RED "%s" NC "\n", primary_bottleneck
        } else {
            print "  Primary:   " GREEN "No major bottleneck identified" NC
        }
        if (secondary_bottleneck != "") {
            printf "  Secondary: " YELLOW "%s" NC "\n", secondary_bottleneck
        } else {
            print "  Secondary: " DIM "None" NC
        }
        print ""
        } # End of no_insights check
    }
    ' "$file_path"
}

compare_metrics() {
    local baseline_file="$1"
    local optimized_file="$2"

    if [[ -z "$baseline_file" ]] || [[ -z "$optimized_file" ]]; then
        echo -e "${RED}Error: --compare requires two file names${NC}"
        echo "Usage: $0 --compare <baseline> <optimized>"
        exit 1
    fi

    local base_path="${baseline_file}.txt"
    local opt_path="${optimized_file}.txt"

    if [[ ! -f "$base_path" ]]; then
        echo -e "${RED}Error: Baseline file not found: ${base_path}${NC}"
        exit 1
    fi

    if [[ ! -f "$opt_path" ]]; then
        echo -e "${RED}Error: Optimized file not found: ${opt_path}${NC}"
        exit 1
    fi

    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}                                    Performance Comparison${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Baseline:${NC}  ${base_path}"
    echo -e "${YELLOW}Optimized:${NC} ${opt_path}"
    echo ""

    # Use awk to parse both files and compare
    awk -v RED="${RED}" -v GREEN="${GREEN}" -v YELLOW="${YELLOW}" -v NC="${NC}" -v BOLD="${BOLD}" \
        -v base_file="$base_path" -v opt_file="$opt_path" '
    # Helper function to format large numbers (defined outside blocks)
    function fmt_num(n) {
        if (n >= 1000000000) return sprintf("%.2fB", n / 1000000000)
        if (n >= 1000000) return sprintf("%.1fM", n / 1000000)
        if (n >= 1000) return sprintf("%.1fK", n / 1000)
        return sprintf("%d", n)
    }

    BEGIN {
        # Parse baseline file
        while ((getline line < base_file) > 0) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line !~ /^[0-9,]+/) continue
            split(line, fields)
            if (fields[1] ~ /^</) continue
            count = fields[1]
            gsub(/,/, "", count)
            event = fields[2]
            base[event] = count + 0
            base_fmt[event] = fields[1]
            if (!(event in event_list)) {
                event_order[++event_count] = event
                event_list[event] = 1
            }

            # Extract time elapsed
            if (line ~ /seconds time elapsed/) {
                match(line, /[0-9.]+/)
                base_time = substr(line, RSTART, RLENGTH) + 0
            }
        }
        close(base_file)

        # Parse optimized file
        while ((getline line < opt_file) > 0) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            if (line !~ /^[0-9,]+/) continue
            split(line, fields)
            if (fields[1] ~ /^</) continue
            count = fields[1]
            gsub(/,/, "", count)
            event = fields[2]
            opt[event] = count + 0
            opt_fmt[event] = fields[1]
            if (!(event in event_list)) {
                event_order[++event_count] = event
                event_list[event] = 1
            }

            # Extract time elapsed
            if (line ~ /seconds time elapsed/) {
                match(line, /[0-9.]+/)
                opt_time = substr(line, RSTART, RLENGTH) + 0
            }
        }
        close(opt_file)

        # Print comparison table
        print BOLD "┌────────────────────────────────┬──────────────────┬──────────────────┬──────────────┐" NC
        printf BOLD "│ %-30s │ %16s │ %16s │ %12s │" NC "\n", "Metric", "Baseline", "Optimized", "Change"
        print BOLD "├────────────────────────────────┼──────────────────┼──────────────────┼──────────────┤" NC

        for (i = 1; i <= event_count; i++) {
            ev = event_order[i]
            b = base[ev]
            o = opt[ev]

            # Skip if both are zero or missing
            if (b == 0 && o == 0) continue

            # Calculate change
            if (b > 0) {
                change = ((o - b) * 100.0) / b
            } else {
                change = 0
            }

            # Format change with color and manual padding to fix alignment
            val_str = sprintf("%.1f%%", change)
            if (change > 5) val_str = sprintf("+%.1f%%", change)

            pad_len = 12 - length(val_str)
            if (pad_len < 0) pad_len = 0
            padding = sprintf("%" pad_len "s", "")

            if (change < -5) {
                # Improvement (less is usually better for most metrics)
                change_str = padding GREEN val_str NC
            } else if (change > 5) {
                # Regression
                change_str = padding RED val_str NC
            } else {
                change_str = padding val_str
            }

            # Map event names to friendly names
            friendly = ev
            if (ev == "L1-dcache-loads") friendly = "L1D Loads"
            else if (ev == "L1-dcache-load-misses") friendly = "L1D Load Misses"
            else if (ev == "l2_rqsts.references") friendly = "L2 References"
            else if (ev == "l2_rqsts.miss") friendly = "L2 Misses"
            else if (ev == "LLC-loads") friendly = "L3/LLC Loads"
            else if (ev == "LLC-load-misses") friendly = "L3/LLC Load Misses"
            else if (ev == "cache-references") friendly = "Total Cache Refs"
            else if (ev == "cache-misses") friendly = "Total Cache Misses"
            else if (ev == "branch-instructions") friendly = "Branch Instructions"
            else if (ev == "branch-misses") friendly = "Branch Misses"
            else if (ev == "cycles") friendly = "CPU Cycles"
            else if (ev == "instructions") friendly = "Instructions"
            else if (ev == "cycle_activity.stalls_total") friendly = "Total Stall Cycles"
            else if (ev == "cycle_activity.cycles_mem_any") friendly = "Memory Stall Cycles"
            else if (ev == "cycle_activity.stalls_l1d_miss") friendly = "L1D Miss Stalls"
            else if (ev == "cycle_activity.stalls_l2_miss") friendly = "L2 Miss Stalls"
            else if (ev == "cycle_activity.stalls_l3_miss") friendly = "L3 Miss Stalls"
            else if (ev == "offcore_requests.data_rd") friendly = "All Data Reads"
            else if (ev == "offcore_requests.demand_data_rd") friendly = "Demand Data Reads"
            else if (ev ~ /fp_arith_inst_retired.scalar_single/) friendly = "Scalar SP FLOPs"
            else if (ev ~ /fp_arith_inst_retired.scalar_double/) friendly = "Scalar DP FLOPs"
            else if (ev == "seconds") continue  # Skip raw seconds, used in derived metrics

            printf "│ %-30s │ %16s │ %16s │ %s │\n", friendly, base_fmt[ev], opt_fmt[ev], change_str
        }

        print BOLD "└────────────────────────────────┴──────────────────┴──────────────────┴──────────────┘" NC

        # Print derived metrics comparison
        print ""
        print BOLD "Derived Metrics Comparison:" NC
        print ""

        # IPC
        if (base["cycles"] > 0 && base["instructions"] > 0) {
            base_ipc = base["instructions"] / base["cycles"]
        } else { base_ipc = 0 }

        if (opt["cycles"] > 0 && opt["instructions"] > 0) {
            opt_ipc = opt["instructions"] / opt["cycles"]
        } else { opt_ipc = 0 }

        if (base_ipc > 0) {
            ipc_change = ((opt_ipc - base_ipc) * 100.0) / base_ipc
            if (ipc_change > 5) {
                ipc_str = sprintf(GREEN "+%.1f%%" NC, ipc_change)
            } else if (ipc_change < -5) {
                ipc_str = sprintf(RED "%.1f%%" NC, ipc_change)
            } else {
                ipc_str = sprintf("%.1f%%", ipc_change)
            }
            printf "  %-20s %8.3f → %8.3f (%s)\n", "IPC:", base_ipc, opt_ipc, ipc_str
        }

        # L2 Hit Rate
        if (base["l2_rqsts.references"] > 0) {
            base_l2_hit = 100 - (base["l2_rqsts.miss"] * 100.0 / base["l2_rqsts.references"])
        } else { base_l2_hit = 0 }

        if (opt["l2_rqsts.references"] > 0) {
            opt_l2_hit = 100 - (opt["l2_rqsts.miss"] * 100.0 / opt["l2_rqsts.references"])
        } else { opt_l2_hit = 0 }

        if (base_l2_hit > 0 || opt_l2_hit > 0) {
            l2_change = opt_l2_hit - base_l2_hit
            if (l2_change > 5) {
                l2_str = sprintf(GREEN "+%.1f pp" NC, l2_change)
            } else if (l2_change < -5) {
                l2_str = sprintf(RED "%.1f pp" NC, l2_change)
            } else {
                l2_str = sprintf("%.1f pp", l2_change)
            }
            printf "  %-20s %7.1f%% → %7.1f%% (%s)\n", "L2 Hit Rate:", base_l2_hit, opt_l2_hit, l2_str
        }

        # L3 Hit Rate
        if (base["LLC-loads"] > 0) {
            base_l3_hit = 100 - (base["LLC-load-misses"] * 100.0 / base["LLC-loads"])
        } else { base_l3_hit = 0 }

        if (opt["LLC-loads"] > 0) {
            opt_l3_hit = 100 - (opt["LLC-load-misses"] * 100.0 / opt["LLC-loads"])
        } else { opt_l3_hit = 0 }

        if (base_l3_hit > 0 || opt_l3_hit > 0) {
            l3_change = opt_l3_hit - base_l3_hit
            if (l3_change > 1) {
                l3_str = sprintf(GREEN "+%.2f pp" NC, l3_change)
            } else if (l3_change < -1) {
                l3_str = sprintf(RED "%.2f pp" NC, l3_change)
            } else {
                l3_str = sprintf("%.2f pp", l3_change)
            }
            printf "  %-20s %7.2f%% → %7.2f%% (%s)\n", "L3 Hit Rate:", base_l3_hit, opt_l3_hit, l3_str
        }

        # Execution time (from cycles, rough estimate)
        if (base_time > 0 && opt_time > 0) {
            time_change = ((opt_time - base_time) * 100.0) / base_time
            if (time_change < -5) {
                time_str = sprintf(GREEN "%.1f%%" NC, time_change)
            } else if (time_change > 5) {
                time_str = sprintf(RED "+%.1f%%" NC, time_change)
            } else {
                time_str = sprintf("%.1f%%", time_change)
            }
            printf "  %-20s %7.3fs → %7.3fs (%s)\n", "Elapsed Time:", base_time, opt_time, time_str

            if (base_time > opt_time) {
                speedup = base_time / opt_time
                printf "  %-20s " GREEN "%.2fx" NC "\n", "Speedup:", speedup
            } else if (opt_time > base_time) {
                slowdown = opt_time / base_time
                printf "  %-20s " RED "%.2fx" NC "\n", "Slowdown:", slowdown
            }
        }

        # ═══════════════════════════════════════════════════════════════════
        # PERFORMANCE EXPLANATION SECTION
        # ═══════════════════════════════════════════════════════════════════
        print ""
        print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
        print BOLD "                         Performance Explanation" NC
        print BOLD "═══════════════════════════════════════════════════════════════════════════════" NC
        print ""

        explanation_count = 0

        # L2 References (Memory Traffic)
        base_l2_refs = base["l2_rqsts.references"]
        opt_l2_refs = opt["l2_rqsts.references"]
        if (base_l2_refs > 0 && opt_l2_refs > 0) {
            l2_refs_change = ((opt_l2_refs - base_l2_refs) * 100.0) / base_l2_refs
            l2_refs_saved = base_l2_refs - opt_l2_refs
            if (l2_refs_change < -10) {
                printf "  " GREEN "✓ L2 Traffic Reduced:" NC " %s → %s ", fmt_num(base_l2_refs), fmt_num(opt_l2_refs)
                printf "(" GREEN "%.0f%% fewer" NC ", saved %s accesses)\n", -l2_refs_change, fmt_num(l2_refs_saved)
                print "    └─ Better L1 data reuse in optimized version"
                explanation_count++
            } else if (l2_refs_change > 10) {
                printf "  " RED "⚠ L2 Traffic Increased:" NC " %s → %s ", fmt_num(base_l2_refs), fmt_num(opt_l2_refs)
                printf "(" RED "+%.0f%%" NC ")\n", l2_refs_change
                explanation_count++
            }
        }

        # L2 Miss Stalls (Direct Cycle Savings)
        base_l2_stalls = base["cycle_activity.stalls_l2_miss"]
        opt_l2_stalls = opt["cycle_activity.stalls_l2_miss"]
        if (base_l2_stalls > 0 && opt_l2_stalls > 0) {
            l2_stalls_change = ((opt_l2_stalls - base_l2_stalls) * 100.0) / base_l2_stalls
            stalls_saved = base_l2_stalls - opt_l2_stalls
            if (l2_stalls_change < -20) {
                printf "  " GREEN "✓ L2 Miss Stalls Reduced:" NC " %s → %s cycles ", fmt_num(base_l2_stalls), fmt_num(opt_l2_stalls)
                printf "(" GREEN "%.0f%% fewer" NC ")\n", -l2_stalls_change
                explanation_count++
            }
        }

        # LLC/L3 Loads (L2 Miss Traffic)
        base_llc_loads = base["LLC-loads"]
        opt_llc_loads = opt["LLC-loads"]
        if (base_llc_loads > 0 && opt_llc_loads > 0) {
            llc_change = ((opt_llc_loads - base_llc_loads) * 100.0) / base_llc_loads
            llc_saved = base_llc_loads - opt_llc_loads
            if (llc_change < -20) {
                printf "  " GREEN "✓ L3 Traffic Reduced:" NC " %s → %s ", fmt_num(base_llc_loads), fmt_num(opt_llc_loads)
                printf "(" GREEN "%.0f%% fewer" NC " L2 misses)\n", -llc_change
                explanation_count++
            }
        }

        # L1D Stores (Write Traffic)
        base_stores = base["L1-dcache-stores"]
        opt_stores = opt["L1-dcache-stores"]
        if (base_stores > 0 && opt_stores > 0) {
            stores_change = ((opt_stores - base_stores) * 100.0) / base_stores
            if (stores_change < -20) {
                printf "  " GREEN "✓ Store Operations Reduced:" NC " %s → %s ", fmt_num(base_stores), fmt_num(opt_stores)
                printf "(" GREEN "%.0f%% fewer" NC ")\n", -stores_change
                explanation_count++
            }
        }

        # Operational Intensity comparison
        # Calculate FLOPs for both
        base_flops = base["fp_arith_inst_retired.scalar_single"] + base["fp_arith_inst_retired.scalar_double"]
        base_flops += base["fp_arith_inst_retired.128b_packed_single"] * 4 + base["fp_arith_inst_retired.256b_packed_single"] * 8 + base["fp_arith_inst_retired.512b_packed_single"] * 16
        base_flops += base["fp_arith_inst_retired.128b_packed_double"] * 2 + base["fp_arith_inst_retired.256b_packed_double"] * 4 + base["fp_arith_inst_retired.512b_packed_double"] * 8

        opt_flops = opt["fp_arith_inst_retired.scalar_single"] + opt["fp_arith_inst_retired.scalar_double"]
        opt_flops += opt["fp_arith_inst_retired.128b_packed_single"] * 4 + opt["fp_arith_inst_retired.256b_packed_single"] * 8 + opt["fp_arith_inst_retired.512b_packed_single"] * 16
        opt_flops += opt["fp_arith_inst_retired.128b_packed_double"] * 2 + opt["fp_arith_inst_retired.256b_packed_double"] * 4 + opt["fp_arith_inst_retired.512b_packed_double"] * 8

        base_llc_misses = base["LLC-load-misses"]
        opt_llc_misses = opt["LLC-load-misses"]

        if (base_flops > 0 && base_llc_misses > 0 && opt_flops > 0 && opt_llc_misses > 0) {
            base_oi = base_flops / (base_llc_misses * 64)
            opt_oi = opt_flops / (opt_llc_misses * 64)
            oi_ratio = opt_oi / base_oi

            if (oi_ratio > 1.5) {
                printf "  " GREEN "✓ Data Reuse Improved:" NC " %.1f → %.1f FLOPs/byte ", base_oi, opt_oi
                printf "(" GREEN "%.1fx better" NC ")\n", oi_ratio
                print "    └─ More compute per byte of DRAM traffic"
                explanation_count++
            } else if (oi_ratio < 0.67) {
                printf "  " RED "⚠ Data Reuse Degraded:" NC " %.1f → %.1f FLOPs/byte ", base_oi, opt_oi
                printf "(" RED "%.1fx worse" NC ")\n", 1/oi_ratio
                explanation_count++
            }
        }

        # Prefetch efficiency (L1 miss/load ratio)
        base_l1_loads = base["L1-dcache-loads"]
        base_l1_misses = base["L1-dcache-load-misses"]
        opt_l1_loads = opt["L1-dcache-loads"]
        opt_l1_misses = opt["L1-dcache-load-misses"]

        if (base_l1_loads > 0 && opt_l1_loads > 0) {
            base_pf_ratio = base_l1_misses / base_l1_loads
            opt_pf_ratio = opt_l1_misses / opt_l1_loads

            if (base_pf_ratio > 1.0 && opt_pf_ratio > 1.0) {
                # Both have prefetching, compare intensity
                if (base_pf_ratio > opt_pf_ratio * 1.3) {
                    printf "  " GREEN "✓ Prefetch Pressure Reduced:" NC " %.1fx → %.1fx miss/load ratio\n", base_pf_ratio, opt_pf_ratio
                    print "    └─ More efficient memory access pattern"
                    explanation_count++
                }
            }
        }

        # Total stall cycles comparison
        base_stalls = base["cycle_activity.stalls_total"]
        opt_stalls = opt["cycle_activity.stalls_total"]
        base_cycles = base["cycles"]
        opt_cycles = opt["cycles"]

        if (base_stalls > 0 && opt_stalls > 0 && base_cycles > 0 && opt_cycles > 0) {
            stall_cycles_saved = base_stalls - opt_stalls
            if (stall_cycles_saved > base_cycles * 0.01) {  # More than 1% of baseline cycles
                printf "  " GREEN "✓ Stall Cycles Reduced:" NC " %s cycles saved\n", fmt_num(stall_cycles_saved)
                explanation_count++
            }
        }

        # Summary
        if (explanation_count == 0) {
            print "  No significant metric differences detected."
            print "  Performance difference may be due to:"
            print "    • Measurement variance"
            print "    • System noise"
            print "    • Metrics not captured by these counters"
        }

        print ""
    }
    ' 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error parsing metric files${NC}"
        exit 1
    fi
}

# Parse arguments
MODE=""
OUTPUT=""
INPUT=""
EXECUTABLE=""
EXEC_ARGS=()
COMPARE_BASE=""
COMPARE_OPT=""
NO_INSIGHTS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --record-cache-metrics)
            MODE="record"
            shift
            ;;
        --visualize)
            MODE="visualize"
            shift
            ;;
        --no-insights)
            NO_INSIGHTS="1"
            shift
            ;;
        --compare)
            MODE="compare"
            COMPARE_BASE="$2"
            COMPARE_OPT="$3"
            shift 3
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        --input)
            INPUT="$2"
            shift 2
            ;;
        --run)
            shift
            EXECUTABLE="$1"
            shift
            # Collect remaining arguments for the executable
            while [[ $# -gt 0 ]]; do
                EXEC_ARGS+=("$1")
                shift
            done
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Execute based on mode
case "$MODE" in
    record)
        record_cache_metrics "$OUTPUT" "$EXECUTABLE" "${EXEC_ARGS[@]}"
        ;;
    visualize)
        visualize_metrics "$INPUT" "$NO_INSIGHTS"
        ;;
    compare)
        compare_metrics "$COMPARE_BASE" "$COMPARE_OPT"
        ;;
    "")
        echo -e "${RED}Error: No mode specified${NC}"
        echo "Use --help for usage information"
        exit 1
        ;;
esac

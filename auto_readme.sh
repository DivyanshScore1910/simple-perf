#!/bin/bash
#
# auto_readme.sh - Automatically generates README.md from perf_tool.sh outputs
#
# Usage: ./auto_readme.sh <executable> [args...]
# Example: ./auto_readme.sh ./gemm_vtune_test 1
#

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PERF_TOOL="$SCRIPT_DIR/perf_tool.sh"
README="$SCRIPT_DIR/README.md"
GENERATED_README=""

# Strip ANSI color codes
strip_colors() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Validate arguments
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <executable> [args...]"
    echo "Example: $0 ./gemm_vtune_test 1"
    exit 1
fi

EXECUTABLE="$1"
shift
EXEC_ARGS=("$@")
COMMAND_DISPLAY=""
printf -v COMMAND_DISPLAY "%q " "$EXECUTABLE" "${EXEC_ARGS[@]}"
COMMAND_DISPLAY="${COMMAND_DISPLAY% }"

# Check executable exists
if [[ ! -x "$EXECUTABLE" ]]; then
    echo "Error: '$EXECUTABLE' is not executable or does not exist"
    exit 1
fi

# Check perf_tool.sh exists
if [[ ! -f "$PERF_TOOL" ]]; then
    echo "Error: perf_tool.sh not found at $PERF_TOOL"
    exit 1
fi

# Generate unique temp filenames using PID
BASELINE="readme_baseline_$$"
OPTIMIZED="readme_optimized_$$"
GENERATED_README="$(mktemp "$SCRIPT_DIR/README.tmp.XXXXXX")"

# Cleanup temp files on exit
cleanup() {
    rm -f "$SCRIPT_DIR/${BASELINE}.txt" "$SCRIPT_DIR/${OPTIMIZED}.txt" "$GENERATED_README"
}
trap cleanup EXIT

echo "Generating README.md..."
echo ""

# Start README with header
cat > "$GENERATED_README" << 'HEADER'
# SIMPLE-PERF
Single bash script for performance measurements and some hints, for CPU.
**NOTE**: Currently optimized on Intel Xeon 4th Gen CPUs only.

## Features
```bash
HEADER

# Features section (--help output)
echo '$# bash ./perf_tool.sh --help' >> "$GENERATED_README"
bash "$PERF_TOOL" --help 2>&1 | strip_colors >> "$GENERATED_README"
echo '```' >> "$GENERATED_README"

echo "[1/4] Features section complete"

# RECORD section
{
    echo ""
    echo "## RECORD"
    echo '```bash'
    echo "\$# bash ./perf_tool.sh --record-cache-metrics --output $BASELINE --run $COMMAND_DISPLAY"
} >> "$GENERATED_README"

bash "$PERF_TOOL" --record-cache-metrics --output "$BASELINE" --run "$EXECUTABLE" "${EXEC_ARGS[@]}" 2>&1 | strip_colors >> "$GENERATED_README"
echo '```' >> "$GENERATED_README"

echo "[2/4] Record section complete"

# VISUALIZE section
{
    echo ""
    echo "## VISUALIZE"
    echo '```bash'
    echo "\$# bash ./perf_tool.sh --visualize --input $BASELINE"
} >> "$GENERATED_README"

bash "$PERF_TOOL" --visualize --input "$BASELINE" 2>&1 | strip_colors >> "$GENERATED_README"
echo '```' >> "$GENERATED_README"

echo "[3/4] Visualize section complete"

# COMPARE section - run executable again for "optimized" comparison
echo "Running second pass for comparison..."
bash "$PERF_TOOL" --record-cache-metrics --output "$OPTIMIZED" --run "$EXECUTABLE" "${EXEC_ARGS[@]}" >/dev/null 2>&1

{
    echo ""
    echo "## COMPARE"
    echo '```bash'
    echo "\$# bash ./perf_tool.sh --compare $BASELINE $OPTIMIZED"
} >> "$GENERATED_README"

bash "$PERF_TOOL" --compare "$BASELINE" "$OPTIMIZED" 2>&1 | strip_colors >> "$GENERATED_README"
echo '```' >> "$GENERATED_README"

echo "[4/4] Compare section complete"
echo ""
mv "$GENERATED_README" "$README"
GENERATED_README=""
echo "README.md generated successfully!"

# Project Instructions

## Pre-commit Hook

Always run `./auto_readme.sh` before making any commit to regenerate README.md with current tool outputs.

### Example workflow:

```bash
# Regenerate README with current perf outputs
./auto_readme.sh ./gemm_vtune_test 1

# Stage and commit
git add README.md auto_readme.sh CLAUDE.md
git commit -m "Your commit message"
```

### Notes

- The script runs the executable twice (baseline + optimized) to generate the COMPARE section
- ANSI color codes are automatically stripped for clean markdown display
- Temporary metric files are cleaned up automatically after generation

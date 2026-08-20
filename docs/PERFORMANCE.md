# Performance budgets

Run `./scripts/benchmark.sh` for a repeatable release-mode audio-analysis
throughput result. Record the JSON output with the Mac model, macOS version,
and commit hash.

For the full app, profile a five-minute Music Reactive session with Instruments
Time Profiler, Allocations, Metal System Trace, and Energy Log. Initial budgets
are under 5% average CPU while reacting, under 1% while steady, under 150 MB
resident memory, no sustained renderer rate above 30 FPS, and no retained raw
audio buffers. Regressions above 20% require investigation before release.

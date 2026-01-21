# Phase 2: Download Engine - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Core download mechanics via HTTPS — getting files from OpenNeuro to local disk with progress, reliability, and resume support. Users can download full datasets, single files, or pattern-matched subsets. No caching layer (Phase 3), no alternative backends (Phase 4).

</domain>

<decisions>
## Implementation Decisions

### Download scope
- Three download modes: full dataset, single file, and regex pattern
- Full regex support for pattern matching (e.g., `sub-0[1-5].*`)
- Annexed (large) files included by default — download everything
- Default destination: working directory (`./ds000001/`)
- User can override with `dest_dir` parameter

### Progress reporting
- Default: overall progress bar ("Downloading 12/47 files") with transfer speed
- Auto-suppress in non-interactive sessions (`interactive()` check)
- `verbose=TRUE`: nested progress bars (overall + per-file)
- `quiet=TRUE`: total silence, only errors
- Always print completion summary: "Downloaded 47 files (1.2 GB) to ./ds000001/"
- Summary includes any issues/skipped files

### Failure handling
- 3 retries with exponential backoff for transient failures
- Fail fast on permanent failure — stop entire batch download
- Delete partial files on failure — no corrupt data on disk
- Plain error messages (no suggestions) — "Download failed: Connection timed out after 30 seconds"

### Resume behavior
- HTTP range requests for files >= 10 MB only
- Skip files that already exist with correct size
- `force=TRUE` parameter to re-download everything

### Claude's Discretion
- Detection mechanism for incomplete downloads (temp suffix vs size comparison)
- Exact exponential backoff timing
- Progress bar styling within cli conventions

</decisions>

<specifics>
## Specific Ideas

No specific references — open to standard approaches following httr2 and cli package conventions.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-download-engine*
*Context gathered: 2026-01-21*

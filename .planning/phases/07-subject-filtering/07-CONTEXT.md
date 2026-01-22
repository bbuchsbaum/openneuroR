# Phase 7: Subject Filtering - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Filter downloads to specific subjects using the `subjects=` parameter in `on_download()`. Users can specify exact subject IDs or use regex patterns to match multiple subjects. The filter applies to file selection before download begins.

</domain>

<decisions>
## Implementation Decisions

### Input format
- Prefix optional — accept both "01" and "sub-01", normalize internally
- Accept character vectors for literal IDs: `c("sub-01", "sub-02")`
- Accept regex patterns via wrapper: `regex("sub-0[1-5]")`
- Character vectors are always treated as literal IDs (no auto-detection)
- Create `regex()` helper function to mark patterns explicitly

### Pattern matching
- Use R's default regex flavor (POSIX extended) via `grepl()`
- Full match required — pattern must match entire subject ID (auto-anchor with ^ and $)
- Case-sensitive only — BIDS subject IDs are case-sensitive, no ignore.case option

### Root file handling
- Always include root-level files (dataset_description.json, README, etc.) with any subject filter
- Include derivatives by default — `include_derivatives=TRUE` gets derivatives/*/sub-XX/ for matching subjects
- Add `include_derivatives` parameter to control this behavior
- Include all sessions within filtered subjects — no session-level filtering in this phase

### Claude's Discretion
- Behavior when regex matches zero subjects (error vs warning)
- Internal normalization logic for prefix handling
- Exact implementation of the `regex()` helper class/function

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-subject-filtering*
*Context gathered: 2026-01-22*

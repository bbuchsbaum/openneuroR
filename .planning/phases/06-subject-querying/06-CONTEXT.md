# Phase 6: Subject Querying - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Query subjects in a dataset without downloading any data. Users can call on_subjects() to discover what subjects exist before deciding what to download. This is a metadata-only operation using the existing GraphQL infrastructure.

</domain>

<decisions>
## Implementation Decisions

### Output format
- Return tibble with columns: dataset_id, subject_id, n_sessions, n_files
- One row per subject (summary view, not expanded by session)
- Natural sort order for subject IDs (sub-01, sub-02, ... sub-10, sub-11)
- Include dataset_id for context when comparing across datasets

### Snapshot handling
- Claude's discretion: Default to latest snapshot, allow version= parameter consistent with other API functions

### Error messages
- Claude's discretion: Follow existing patterns from on_dataset(), on_files() for invalid IDs and empty results

### Caching behavior
- Claude's discretion: No special caching beyond standard GraphQL response handling

### Claude's Discretion
- Snapshot parameter design (version= or tag= consistent with existing API)
- Error message wording and structure
- Whether to cache subject lists (probably not needed for metadata queries)
- How to handle datasets with no BIDS structure (no sub-* folders)

</decisions>

<specifics>
## Specific Ideas

- Output should feel consistent with on_files() and on_snapshots() — tibble-based, informative columns
- Natural sorting is important for neuroimaging where subject numbers matter

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-subject-querying*
*Context gathered: 2026-01-22*

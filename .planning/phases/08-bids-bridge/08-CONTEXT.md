# Phase 8: BIDS Bridge - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Bridge fetched OpenNeuro datasets to bidser `bids_project` objects. Users call `on_bids(handle)` to convert a downloaded dataset into a BIDS-aware object for rich data access. Includes support for fMRIPrep derivatives.

</domain>

<decisions>
## Implementation Decisions

### Function signature
- Accept handle objects only (not raw paths) - consistent with on_fetch(), on_path() pattern
- Auto-fetch if handle not yet fetched - user just calls on_bids() and it works
- Brief message during operation (e.g., "Creating BIDS project from ds000001") - consistent with on_fetch()

### Derivatives handling
- fmriprep=TRUE looks for `derivatives/fmriprep` (lowercase, standard BIDS-Apps convention)
- If fmriprep=TRUE but path doesn't exist: warn and continue without derivatives
- prep_dir accepts single path only (not vector) - keeps API simple
- If both fmriprep=TRUE and prep_dir specified: prep_dir wins (custom overrides convenience)

### Handle requirements
- Works silently with partial datasets (subjects= filtered handles)
- Validate dataset has dataset_description.json before calling bidser
- Informative cli::cli_abort errors for wrong input types (suggest on_handle())
- No caching of bids_project in handle - fresh object each call

### Claude's Discretion
- Return type (direct bids_project vs wrapped object with metadata)
- Exact messaging text
- Internal helper structure

</decisions>

<specifics>
## Specific Ideas

No specific requirements - open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None - discussion stayed within phase scope.

</deferred>

---

*Phase: 08-bids-bridge*
*Context gathered: 2026-01-22*

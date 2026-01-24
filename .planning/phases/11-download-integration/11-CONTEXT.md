# Phase 11: Download Integration - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable researchers to download fMRIPrep derivative data with filtering by subject and output space. Infrastructure (discovery via on_derivatives(), space detection via on_spaces(), S3 backend for derivatives bucket) already exists from Phases 9-10. This phase adds the download function and integrates with the existing cache system.

</domain>

<decisions>
## Implementation Decisions

### Filter behavior
- Subject and space filters combine with AND logic (file must match both)
- Invalid subjects: warn about missing, download what exists (skip missing)
- Space matching and invalid space handling: Claude's discretion

### Download scope
- Default: full derivative (all subjects, all spaces) when no filters specified
- Input format: dataset ID + pipeline name as separate arguments (e.g., `on_download_derivatives("ds000001", "fmriprep")`)
- Add `suffix=` parameter to filter by BIDS suffix (bold, T1w, mask, etc.)
- Add `dry_run=` parameter — TRUE returns tibble of files without downloading

### Output organization
- Cache structure: BIDS-like `{cache}/ds000001/derivatives/fmriprep/` (derivatives inside dataset folder)
- Existing files: skip if file exists AND size matches (check size, not just path)
- Manifest: single manifest per dataset, entries tagged as 'raw' or 'derivative'
- Cache visibility: on_cache_list() and on_cache_info() show unified view (raw + derivatives with type column)

### Claude's Discretion
- Exact match vs prefix match for space filtering
- Error behavior when requested space doesn't exist
- Internal implementation of size checking for skip logic

</decisions>

<specifics>
## Specific Ideas

- Consistent with existing on_download() patterns from v1.0
- subjects= parameter should reuse v1.1 pattern from on_download()
- BIDS-compliant path structure mirrors what fMRIPrep outputs

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-download-integration*
*Context gathered: 2026-01-23*

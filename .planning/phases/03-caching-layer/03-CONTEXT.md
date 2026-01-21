# Phase 3: Caching Layer - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Downloaded datasets persist locally and are not re-downloaded. Provide CRAN-compliant cache location, manifest tracking, and cache management utilities. Backend selection and lazy handles are Phase 4.

</domain>

<decisions>
## Implementation Decisions

### Cache structure
- Nested by dataset, mirroring OpenNeuro structure: `cache/ds000001/sub-01/anat/...`
- Single version per dataset (latest or explicitly requested), not separate per snapshot
- Human-browsable paths — users can navigate cache with file explorer
- Files stored at: `tools::R_user_dir("openneuroR", "cache")/ds000001/...`

### Manifest design
- JSON format (human-readable, debuggable, works with jsonlite)
- Per-dataset manifest: `cache/ds000001/manifest.json`
- Only record complete files — partial downloads not tracked in manifest
- Manifest updated after each file fully downloaded (atomic)

### Claude's Discretion
- Exact metadata fields in manifest (minimally: path, size, download time; may add checksum/backend if useful)
- Behavior when user requests different snapshot than cached (replace vs error)
- Internal cache path helpers and validation

</decisions>

<specifics>
## Specific Ideas

- Users should be able to find their downloaded data by browsing `tools::R_user_dir()` directly
- Manifest should be readable if user opens it in a text editor

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-caching-layer*
*Context gathered: 2026-01-21*

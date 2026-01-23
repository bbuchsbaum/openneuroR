# Phase 9: Discovery Foundation - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can discover available derivative datasets (fMRIPrep, etc.) for any OpenNeuro dataset. Discovery returns a comprehensive tibble with pipeline info, source, and metadata. Downloading derivatives is Phase 11.

</domain>

<decisions>
## Implementation Decisions

### Discovery output format
- Comprehensive tibble: pipeline name, source, version, subject count, file count, total size, last modified
- Version shows the derivative dataset version/tag from OpenNeuroDerivatives (not fMRIPrep pipeline version)
- Sizes shown as human-readable strings ("2.3 GB" style)
- Include S3 URL column so users can pass to other tools or use directly

### Source handling
- Unified tibble with a `source` column (values: "embedded" or "openneuro-derivatives")
- If same pipeline exists in both sources, prefer embedded (show embedded row only)
- Default behavior: check both sources
- User parameter `sources=` allows limiting to "embedded" or "openneuro-derivatives" only

### Session caching
- `refresh=TRUE` parameter bypasses cache and forces fresh fetch
- If GitHub rate limit hit: error with retry-after time (don't silently skip)

### Claude's Discretion
- What exactly to cache (GitHub org list vs both sources vs final tibble)
- In-memory vs disk caching strategy
- Exact column names and ordering in output tibble

</decisions>

<specifics>
## Specific Ideas

- S3 URL inclusion enables interop with other tools outside R
- "openneuro-derivatives" source name matches the GitHub org for clarity
- Error-on-rate-limit ensures user knows when data is incomplete

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-discovery-foundation*
*Context gathered: 2026-01-23*

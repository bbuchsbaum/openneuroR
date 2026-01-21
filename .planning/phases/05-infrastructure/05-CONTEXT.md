# Phase 5: Infrastructure - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the openneuroR package CRAN-ready with comprehensive mocked tests, R CMD check compliance, and a diagnostics function. This phase does not add new user-facing features — it ensures existing features are tested and the package passes CRAN submission requirements.

</domain>

<decisions>
## Implementation Decisions

### Test coverage scope
- Focus on critical paths: download, cache, and handle functions
- Skip simple getters and metadata functions
- Minimal error testing: one or two error cases per function, not exhaustive
- Test each backend in isolation (mock S3 unavailable, DataLad unavailable separately)
- Use real dataset IDs (ds000001, etc.) so mocked responses match real API structure

### on_doctor() output
- Styled terminal table with cli formatting, colors, and symbols (✓/✗)
- Check backends only (DataLad, AWS CLI, HTTPS availability)
- Show installation hints when backends are missing (e.g., "pip install datalad")
- Display version numbers when backends are available (e.g., "DataLad 0.19.3")
- Group backends: HTTPS as required/always available, DataLad/S3 as optional enhancements
- Only runs when explicitly called (no startup messages)
- Returns structured list invisibly for programmatic use
- No minimum version enforcement — if installed, assume it works

### Mocking strategy
- Optional live test mode via environment variable for maintainer use
- All CRAN/CI tests use mocking, never hit real APIs

### Claude's Discretion
- Choice of mocking framework (httptest2, webmockr, or other httr2-compatible)
- Mock file organization (per-test vs shared fixtures)
- Whether to mock CLI tool calls or use skip_if_not_installed()
- R CMD check profile and note suppression

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard R package testing approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-infrastructure*
*Context gathered: 2026-01-21*

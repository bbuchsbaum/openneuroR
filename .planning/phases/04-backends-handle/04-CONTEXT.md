# Phase 4: Backends + Handle - Context

**Gathered:** 2026-01-21
**Status:** Ready for planning

<domain>
## Phase Boundary

Alternative download backends (S3 via AWS CLI, DataLad via CLI) with automatic selection based on availability, plus lazy handles that defer downloads until explicitly fetched. HTTPS backend already exists from Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Backend selection logic
- Default priority order: DataLad > S3 > HTTPS
- DataLad preferred for integrity checks, S3 as fast alternative, HTTPS as universal fallback
- User can force specific backend via argument: `on_download(..., backend = "s3")`
- No session-wide option needed — argument override is sufficient

### Fallback behavior
- Auto-fallback silently to next backend in priority order if selected backend fails
- No user intervention required during fallback
- Keep downloads seamless for researchers

### Claude's Discretion
- Backend availability detection timing (package load vs lazy vs per-call)
- Handle lifecycle details (state tracking, what fetch returns)
- CLI dependency detection methods (how to check for aws/datalad)
- Error messages and feedback during backend operations
- S3 and DataLad backend implementation details
- Handle class design and methods

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. User wants it to "just work" with minimal friction.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-backends-handle*
*Context gathered: 2026-01-21*

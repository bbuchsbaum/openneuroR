# Phase 10: Spaces and S3 Backend - Context

**Gathered:** 2026-01-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Enable users to discover available output spaces in derivative datasets and extend S3 backend to support the `s3://openneuro-derivatives/` bucket. This phase delivers:
1. `on_spaces()` function returning available output spaces for a derivative
2. S3 backend capable of downloading from the derivatives bucket (not just `s3://openneuro/`)

</domain>

<decisions>
## Implementation Decisions

### on_spaces() Input Interface
- Single derivative at a time (no vectorization — user loops if needed)
- Network access allowed if needed to get space info
- Claude's discretion: Input format (derivative tibble row vs dataset ID + pipeline) — choose most convenient/unsurprising pattern consistent with existing API
- Claude's discretion: Behavior when pipeline not specified — choose friendliest approach

### Space Discovery Approach
- Support both volumetric (MNI152NLin2009cAsym, MNI152NLin6Asym, T1w) and surface spaces (fsaverage, fsaverage5, fsaverage6, fsnative)
- Embedded derivatives and OpenNeuroDerivatives may use different code paths if needed
- If no recognizable spaces found: warn and return empty vector
- Claude's discretion: Detection method (filename parsing vs directory patterns) — pick based on fMRIPrep conventions

### Return Structure
- Character vector of space names (simple, not tibble)
- Alphabetically sorted
- Session caching enabled (like on_derivatives())
- Claude's discretion: Whether to distinguish anat-only vs func-only spaces

### S3 Fallback Behavior
- Primary fallback chain: S3 → DataLad → HTTPS (exhaust all options before failing)
- Probe bucket accessibility on first use (lazy, not at package load)
- Verbose logging during fallback attempts ("S3 failed, trying DataLad...")

</decisions>

<specifics>
## Specific Ideas

- Fallback chain modeled on existing auto-select pattern from v1.0
- Space detection should handle the common fMRIPrep spaces researchers care about most

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 10-spaces-and-s3-backend*
*Context gathered: 2026-01-23*

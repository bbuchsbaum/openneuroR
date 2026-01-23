# Requirements: openneuro

**Defined:** 2026-01-20
**Core Value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.

## v1.2 Requirements (Current Milestone)

Requirements for fMRIPrep Derivative Discovery milestone. Each maps to roadmap phases.

### Discovery

- [ ] **DISC-01**: User can list available derivative pipelines for a dataset via `on_derivatives()`
- [ ] **DISC-02**: `on_derivatives()` returns tibble with pipeline name, source (embedded/OpenNeuroDerivatives), and metadata
- [ ] **DISC-03**: User can discover OpenNeuroDerivatives (784+ pre-computed fMRIPrep datasets from GitHub org)
- [ ] **DISC-04**: Discovery results are cached per-session to avoid GitHub API rate limits (60/hr unauthenticated)

### Spaces

- [ ] **SPAC-01**: User can list available output spaces for a derivative via `on_spaces()`
- [ ] **SPAC-02**: `on_spaces()` returns character vector of space names (MNI152NLin2009cAsym, T1w, fsaverage, etc.)

### Download

- [ ] **DOWN-01**: User can download fMRIPrep derivatives via `on_download_derivatives()`
- [ ] **DOWN-02**: `on_download_derivatives()` supports `subjects=` parameter for subject filtering (reuses v1.1 pattern)
- [ ] **DOWN-03**: `on_download_derivatives()` supports `space=` parameter for output space filtering
- [ ] **DOWN-04**: Downloaded derivatives use BIDS-compliant cache structure (`{dataset}/derivatives/{pipeline}/`)

### Infrastructure

- [ ] **INFR-01**: New functions have mocked tests (no real API/downloads in tests)
- [ ] **INFR-02**: Package passes R CMD check with no errors/warnings after changes
- [ ] **INFR-03**: S3 backend supports parameterized bucket for derivatives bucket access

## v1.1 Requirements (Complete)

All v1.1 requirements shipped. See `.planning/milestones/v1.1-REQUIREMENTS.md` for full archive.

**Summary:** 12 requirements across Subject Discovery (2), Download Filtering (3), BIDS Bridge (4), Infrastructure (3).

## v1.0 Requirements (Complete)

All v1.0 requirements shipped. See `.planning/milestones/v1.0-REQUIREMENTS.md` for full archive.

**Summary:** 22 requirements across Discovery (4), Downloads (4), Backends (4), Caching (4), Handle/Pipeline (3), Infrastructure (3).

## Future Requirements

Deferred to later milestones:

- Session-level filtering in `on_download()` — v1.3+
- Task-level filtering in `on_download()` — v1.3+
- MRIQC derivative support — v1.3+
- FreeSurfer derivative support — v2+
- Concurrent multi-subject downloads — v2+
- `tar_openneuro()` targets helper — v2+
- Cross-dataset derivative aggregation — v3+

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Upload/write operations | Read-only access for v1.x; OpenNeuro upload has separate workflow |
| OAuth/social login | API key + bearer token sufficient; OpenNeuro uses simple auth |
| BIDS validation | Separate concern; compose with bids-validator or other tools |
| Derivative processing | openneuroR fetches data, fMRIPrep/other tools process it |
| Automatic space selection | MNI variants cause confusion; require explicit parameter |
| Automatic confound selection | Hotly debated in literature; analysis-specific decision |
| Unified derivatives API | OpenNeuro + OpenNeuroDerivatives have different access patterns; keep separate |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISC-01 | Phase 9 | Pending |
| DISC-02 | Phase 9 | Pending |
| DISC-03 | Phase 9 | Pending |
| DISC-04 | Phase 9 | Pending |
| SPAC-01 | Phase 10 | Pending |
| SPAC-02 | Phase 10 | Pending |
| DOWN-01 | Phase 11 | Pending |
| DOWN-02 | Phase 11 | Pending |
| DOWN-03 | Phase 11 | Pending |
| DOWN-04 | Phase 11 | Pending |
| INFR-01 | Phase 11 | Pending |
| INFR-02 | Phase 11 | Pending |
| INFR-03 | Phase 10 | Pending |

**Coverage:**
- v1.2 requirements: 13 total
- Mapped to phases: 13
- Unmapped: 0

---
*Requirements defined: 2026-01-20*
*Last updated: 2026-01-23 — v1.2 requirements defined*

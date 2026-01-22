# Requirements: openneuro

**Defined:** 2026-01-20
**Core Value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.

## v1.1 Requirements (Current Milestone)

Requirements for BIDS integration milestone. Each maps to roadmap phases.

### Subject Discovery

- [x] **SUBJ-01**: User can query subjects in a dataset without downloading (returns tibble with subject IDs)
- [x] **SUBJ-02**: User can see subject count from on_subjects() output

### Download Filtering

- [x] **FILT-01**: User can download specific subjects only via subjects= parameter in on_download()
- [x] **FILT-02**: subjects= parameter accepts character vector of subject IDs (e.g., c("sub-01", "sub-02"))
- [x] **FILT-03**: subjects= parameter supports regex patterns for flexible matching (e.g., "sub-0[1-5]")

### BIDS Bridge

- [ ] **BIDS-01**: User can get bidser bids_project object from fetched handle via on_bids()
- [ ] **BIDS-02**: on_bids() checks for bidser and provides helpful installation message if not installed
- [ ] **BIDS-03**: on_bids() accepts fmriprep= parameter to include fMRIPrep derivatives
- [ ] **BIDS-04**: on_bids() accepts prep_dir= parameter to specify custom derivatives path

### Infrastructure

- [ ] **INF1-01**: bidser listed in Suggests (not Imports) for optional dependency
- [ ] **INF1-02**: All new functions have mocked tests (no real API/downloads in tests)
- [ ] **INF1-03**: Package passes R CMD check with no errors/warnings

## v1.0 Requirements (Complete)

All v1.0 requirements shipped. See `.planning/milestones/v1.0-REQUIREMENTS.md` for full archive.

**Summary:** 22 requirements across Discovery (4), Downloads (4), Backends (4), Caching (4), Handle/Pipeline (3), Infrastructure (3).

## Future Requirements

Deferred to later milestones:

- Session-level filtering in on_download() - v1.2+
- Task-level filtering in on_download() - v1.2+
- Derivative discovery from OpenNeuro API - v1.2+
- Concurrent multi-subject downloads - v2+
- tar_openneuro() targets helper - v2+

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Upload/write operations | Read-only access for v1.x; OpenNeuro upload has separate workflow |
| OAuth/social login | API key + bearer token sufficient; OpenNeuro uses simple auth |
| BIDS validation | Separate concern; compose with bids-validator or other tools |
| Derivative processing | openneuroR fetches data, bidser/other tools process it |
| Real-time notifications | Not needed for data access patterns |
| GUI/RStudio integration | CLI/programmatic access only |
| Offline search index | High complexity, defer indefinitely |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| SUBJ-01 | Phase 6 | Complete |
| SUBJ-02 | Phase 6 | Complete |
| FILT-01 | Phase 7 | Complete |
| FILT-02 | Phase 7 | Complete |
| FILT-03 | Phase 7 | Complete |
| BIDS-01 | Phase 8 | Pending |
| BIDS-02 | Phase 8 | Pending |
| BIDS-03 | Phase 8 | Pending |
| BIDS-04 | Phase 8 | Pending |
| INF1-01 | Phase 8 | Pending |
| INF1-02 | Phase 8 | Pending |
| INF1-03 | Phase 8 | Pending |

**Coverage:**
- v1.1 requirements: 12 total
- Mapped to phases: 12
- Unmapped: 0

---
*Requirements defined: 2026-01-20*
*Last updated: 2026-01-22 - v1.1 roadmap created with phase mappings*

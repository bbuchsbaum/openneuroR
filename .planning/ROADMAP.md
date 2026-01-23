# Roadmap: openneuro

## Milestones

- **v1.0 MVP** - Phases 1-5 (shipped 2026-01-22) — see `milestones/v1.0-ROADMAP.md`
- **v1.1 BIDS Integration** - Phases 6-8 (shipped 2026-01-22) — see `milestones/v1.1-ROADMAP.md`
- **v1.2 fMRIPrep Derivative Discovery** - Phases 9-11 (in progress)

## Phases

<details>
<summary>v1.0 MVP (Phases 1-5) - SHIPPED 2026-01-22</summary>

### Phase 1: Foundation + Discovery
**Goal**: Researchers can search and explore OpenNeuro datasets from R
**Depends on**: Nothing (first phase)
**Requirements**: DISC-01, DISC-02, DISC-03, DISC-04
**Success Criteria** (what must be TRUE):
  1. User can call on_search("word") and get a tibble of matching datasets
  2. User can call on_dataset("ds000001") and get metadata (name, dates, public status)
  3. User can list snapshots for a dataset and see tags/timestamps
  4. User can list files in a snapshot with filename, size, and annexed status
**Plans**: 2 plans

Plans:
- [x] 01-01-PLAN.md - Package skeleton and GraphQL infrastructure
- [x] 01-02-PLAN.md - Discovery API functions (on_search, on_dataset, on_snapshots, on_files)

### Phase 2: Download Engine
**Goal**: Researchers can download datasets via HTTPS with progress and reliability
**Depends on**: Phase 1
**Requirements**: DOWN-01, DOWN-02, DOWN-03, DOWN-04, BACK-01
**Success Criteria** (what must be TRUE):
  1. User can download a full dataset to local disk
  2. Download shows progress bar during transfer (cli-based)
  3. Download retries automatically on transient failures (exponential backoff)
  4. Interrupted download resumes from where it stopped (for large files)
  5. HTTPS backend works with no external CLI dependencies
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md - Download infrastructure (URL construction, single-file download, recursive file listing)
- [x] 02-02-PLAN.md - User-facing on_download() with full/file/pattern modes and progress reporting

### Phase 3: Caching Layer
**Goal**: Downloaded datasets persist locally and are not re-downloaded
**Depends on**: Phase 2
**Requirements**: CACH-01, CACH-02, CACH-03, CACH-04
**Success Criteria** (what must be TRUE):
  1. Repeat access to same dataset uses cached files (no network call)
  2. Cache location is CRAN-compliant (tools::R_user_dir)
  3. Manifest tracks what was downloaded, when, and via which backend
  4. User can list cached datasets, get sizes, and clear cache
**Plans**: 2 plans

Plans:
- [x] 03-01-PLAN.md - Cache infrastructure (path resolution, manifest read/write)
- [x] 03-02-PLAN.md - Cache integration and management functions (on_cache_list, on_cache_info, on_cache_clear)

### Phase 4: Backends + Handle
**Goal**: Researchers get best-available backend and pipeline-friendly lazy handles
**Depends on**: Phase 3
**Requirements**: BACK-02, BACK-03, BACK-04, HAND-01, HAND-02, HAND-03
**Success Criteria** (what must be TRUE):
  1. S3 backend downloads datasets using AWS CLI (--no-sign-request)
  2. DataLad backend downloads datasets using DataLad CLI with integrity checks
  3. Auto-select picks best available backend (DataLad > S3 > HTTPS)
  4. User can create lazy handle without triggering download
  5. User can fetch handle to materialize download and get filesystem path
**Plans**: 4 plans

Plans:
- [x] 04-01-PLAN.md - Backend detection utilities and S3 backend (AWS CLI)
- [x] 04-02-PLAN.md - DataLad backend (clone + get with integrity)
- [x] 04-03-PLAN.md - Auto-select dispatch and on_download backend integration
- [x] 04-04-PLAN.md - Lazy handle pattern (on_handle, on_fetch, on_path)

### Phase 5: Infrastructure
**Goal**: Package is CRAN-ready with comprehensive mocked tests
**Depends on**: Phase 4
**Requirements**: INFR-01, INFR-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. R CMD check passes with no errors or warnings
  2. All tests use mocking (httptest2), no real API calls
  3. on_doctor() reports status of all backends (installed, version, working)
**Plans**: 3 plans

Plans:
- [x] 05-01-PLAN.md - Test infrastructure setup with httptest2 and API discovery function tests
- [x] 05-02-PLAN.md - Backend/handle/cache tests and on_doctor() implementation
- [x] 05-03-PLAN.md - R CMD check compliance and final verification

</details>

<details>
<summary>v1.1 BIDS Integration (Phases 6-8) - SHIPPED 2026-01-22</summary>

- [x] Phase 6: Subject Querying (1/1 plans) — completed 2026-01-22
- [x] Phase 7: Subject Filtering (1/1 plans) — completed 2026-01-22
- [x] Phase 8: BIDS Bridge (1/1 plans) — completed 2026-01-22

</details>

### v1.2 fMRIPrep Derivative Discovery (In Progress)

**Milestone Goal:** Enable researchers to discover and download fMRIPrep derivative datasets from OpenNeuro.

#### Phase 9: Discovery Foundation
**Goal**: Users can discover available derivative datasets for any OpenNeuro dataset
**Depends on**: Phase 8 (v1.1 complete)
**Requirements**: DISC-01, DISC-02, DISC-03, DISC-04
**Success Criteria** (what must be TRUE):
  1. User can call `on_derivatives("ds000001")` and get a tibble of available pipelines
  2. Tibble includes pipeline name, source (embedded vs OpenNeuroDerivatives), and metadata
  3. OpenNeuroDerivatives GitHub organization repos are discoverable (784+ datasets)
  4. Discovery results are cached per-session (no repeated GitHub API calls within session)
**Plans**: TBD

Plans:
- [ ] 09-01: TBD

#### Phase 10: Spaces and S3 Backend
**Goal**: Users can explore output spaces and S3 infrastructure supports derivative bucket access
**Depends on**: Phase 9
**Requirements**: SPAC-01, SPAC-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. User can call `on_spaces()` on a derivative to get available output spaces
  2. Space names returned as character vector (MNI152NLin2009cAsym, T1w, fsaverage, etc.)
  3. S3 backend can download from `s3://openneuro-derivatives/` bucket (not just `s3://openneuro/`)
**Plans**: TBD

Plans:
- [ ] 10-01: TBD

#### Phase 11: Download Integration
**Goal**: Users can download filtered derivative data with full test coverage
**Depends on**: Phase 10
**Requirements**: DOWN-01, DOWN-02, DOWN-03, DOWN-04, INFR-01, INFR-02
**Success Criteria** (what must be TRUE):
  1. User can call `on_download_derivatives()` to download fMRIPrep derivatives
  2. User can filter by subject via `subjects=` parameter (reuses v1.1 pattern)
  3. User can filter by output space via `space=` parameter
  4. Downloaded derivatives stored in BIDS-compliant path: `{dataset}/derivatives/{pipeline}/`
  5. All new functions have mocked tests (no real API/downloads in test suite)
  6. Package passes R CMD check with 0 errors, 0 warnings after changes
**Plans**: TBD

Plans:
- [ ] 11-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 > 2 > 3 > 4 > 5 > 6 > 7 > 8 > 9 > 10 > 11

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation + Discovery | v1.0 | 2/2 | Complete | 2026-01-21 |
| 2. Download Engine | v1.0 | 2/2 | Complete | 2026-01-21 |
| 3. Caching Layer | v1.0 | 2/2 | Complete | 2026-01-21 |
| 4. Backends + Handle | v1.0 | 4/4 | Complete | 2026-01-21 |
| 5. Infrastructure | v1.0 | 3/3 | Complete | 2026-01-22 |
| 6. Subject Querying | v1.1 | 1/1 | Complete | 2026-01-22 |
| 7. Subject Filtering | v1.1 | 1/1 | Complete | 2026-01-22 |
| 8. BIDS Bridge | v1.1 | 1/1 | Complete | 2026-01-22 |
| 9. Discovery Foundation | v1.2 | 0/TBD | Not started | - |
| 10. Spaces and S3 Backend | v1.2 | 0/TBD | Not started | - |
| 11. Download Integration | v1.2 | 0/TBD | Not started | - |

---
*Roadmap created: 2026-01-20*
*v1.2 milestone added: 2026-01-23*

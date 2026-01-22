# Roadmap: openneuro

## Milestones

- **v1.0 MVP** - Phases 1-5 (shipped 2026-01-22)
- **v1.1 BIDS Integration** - Phases 6-8 (in progress)

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

### v1.1 BIDS Integration (In Progress)

**Milestone Goal:** Make openneuroR BIDS-native by integrating with bidser for rich BIDS-aware data access. Users can discover subjects before downloading, selectively download subsets, and convert fetched datasets into bids_project objects.

- [ ] **Phase 6: Subject Querying** - Query subjects in a dataset without downloading
- [ ] **Phase 7: Subject Filtering** - Download specific subjects via subjects= parameter
- [ ] **Phase 8: BIDS Bridge** - Bridge to bidser for BIDS-aware project objects

## Phase Details

### Phase 6: Subject Querying
**Goal**: Users can discover subjects in a dataset before downloading
**Depends on**: Phase 5 (uses existing GraphQL infrastructure)
**Requirements**: SUBJ-01, SUBJ-02
**Success Criteria** (what must be TRUE):
  1. User can call on_subjects("ds000001") and get a tibble with subject IDs
  2. User can see how many subjects exist in the dataset from the output
  3. Function works without downloading any data (metadata-only query)
**Plans**: 1 plan

Plans:
- [x] 06-01-PLAN.md - GraphQL query, on_subjects() function, and tests

### Phase 7: Subject Filtering
**Goal**: Users can download only specific subjects instead of entire datasets
**Depends on**: Phase 6 (uses on_subjects() for validation)
**Requirements**: FILT-01, FILT-02, FILT-03
**Success Criteria** (what must be TRUE):
  1. User can call on_download(..., subjects = c("sub-01", "sub-02")) to download specific subjects
  2. User can use regex patterns (subjects = "sub-0[1-5]") for flexible matching
  3. Download respects subject filter and only retrieves matching files
  4. Invalid subject IDs produce helpful error messages
**Plans**: TBD

Plans:
- [ ] 07-01: Subject filtering implementation

### Phase 8: BIDS Bridge
**Goal**: Users can get BIDS-aware project objects from fetched datasets
**Depends on**: Phase 7 (requires download functionality)
**Requirements**: BIDS-01, BIDS-02, BIDS-03, BIDS-04, INF1-01, INF1-02, INF1-03
**Success Criteria** (what must be TRUE):
  1. User can call on_bids(handle) and get a bidser bids_project object
  2. on_bids() provides helpful message if bidser is not installed
  3. User can include fMRIPrep derivatives via on_bids(handle, fmriprep = TRUE)
  4. User can specify custom derivatives path via on_bids(handle, prep_dir = "derivatives/custom")
  5. R CMD check passes with bidser as Suggests (not Imports)
**Plans**: TBD

Plans:
- [ ] 08-01: BIDS bridge and bidser integration

## Progress

**Execution Order:**
Phases execute in numeric order: 1 > 2 > 3 > 4 > 5 > 6 > 7 > 8

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Foundation + Discovery | v1.0 | 2/2 | Complete | 2026-01-21 |
| 2. Download Engine | v1.0 | 2/2 | Complete | 2026-01-21 |
| 3. Caching Layer | v1.0 | 2/2 | Complete | 2026-01-21 |
| 4. Backends + Handle | v1.0 | 4/4 | Complete | 2026-01-21 |
| 5. Infrastructure | v1.0 | 3/3 | Complete | 2026-01-22 |
| 6. Subject Querying | v1.1 | 1/1 | Complete | 2026-01-22 |
| 7. Subject Filtering | v1.1 | 0/1 | Not started | - |
| 8. BIDS Bridge | v1.1 | 0/1 | Not started | - |

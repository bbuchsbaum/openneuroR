# Roadmap: openneuro

## Overview

This roadmap delivers an R package for programmatic OpenNeuro access in 5 phases. We start with package foundation and GraphQL-based discovery, then build the download engine with HTTPS backend, add caching for persistence, layer in alternative backends (S3, DataLad) with the lazy handle pattern, and finish with testing infrastructure and polish. Each phase delivers a coherent, testable capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: Foundation + Discovery** - Package skeleton and GraphQL-based dataset discovery
- [x] **Phase 2: Download Engine** - Core download mechanics with HTTPS backend
- [ ] **Phase 3: Caching Layer** - CRAN-compliant cache with manifest tracking
- [ ] **Phase 4: Backends + Handle** - S3/DataLad backends, auto-select, and lazy handle pattern
- [ ] **Phase 5: Infrastructure** - Tests, R CMD check, diagnostics

## Phase Details

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
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

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
**Plans**: TBD

Plans:
- [ ] 04-01: TBD
- [ ] 04-02: TBD

### Phase 5: Infrastructure
**Goal**: Package is CRAN-ready with comprehensive mocked tests
**Depends on**: Phase 4
**Requirements**: INFR-01, INFR-02, INFR-03
**Success Criteria** (what must be TRUE):
  1. R CMD check passes with no errors or warnings
  2. All tests use mocking (vcr/webmockr), no real API calls
  3. on_doctor() reports status of all backends (installed, version, working)
**Plans**: TBD

Plans:
- [ ] 05-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 > 2 > 3 > 4 > 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Discovery | 2/2 | Complete | 2026-01-21 |
| 2. Download Engine | 2/2 | Complete | 2026-01-21 |
| 3. Caching Layer | 0/1 | Not started | - |
| 4. Backends + Handle | 0/2 | Not started | - |
| 5. Infrastructure | 0/1 | Not started | - |

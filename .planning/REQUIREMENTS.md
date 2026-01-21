# Requirements: openneuro

**Defined:** 2026-01-20
**Core Value:** Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Discovery

- [x] **DISC-01**: User can search datasets by text query, returning tibble of results
- [x] **DISC-02**: User can get dataset metadata (name, created, updated, public status)
- [x] **DISC-03**: User can list snapshots for a dataset with tags and timestamps
- [x] **DISC-04**: User can list files within a snapshot (filename, size, annexed status)

### Downloads

- [x] **DOWN-01**: User can download full dataset to local cache
- [x] **DOWN-02**: Download shows progress bar during transfer
- [x] **DOWN-03**: Download retries automatically with exponential backoff on failure
- [x] **DOWN-04**: Download resumes from where it stopped on interruption (large files)

### Backends

- [x] **BACK-01**: HTTPS backend works with no external dependencies
- [ ] **BACK-02**: S3 backend uses AWS CLI for fast bulk downloads
- [ ] **BACK-03**: DataLad backend uses DataLad CLI for integrity + partial retrieval
- [ ] **BACK-04**: Auto-select chooses best available backend automatically

### Caching

- [ ] **CACH-01**: Downloaded datasets are cached locally (no re-download on repeat access)
- [ ] **CACH-02**: Cache uses CRAN-compliant location (tools::R_user_dir)
- [ ] **CACH-03**: Manifest tracks what was downloaded, when, via which backend
- [ ] **CACH-04**: User can list, clear, and manage cached datasets

### Handle/Pipeline

- [ ] **HAND-01**: User can create lazy handle to dataset (no immediate download)
- [ ] **HAND-02**: User can fetch handle to materialize download
- [ ] **HAND-03**: User can get filesystem path from fetched handle

### Infrastructure

- [ ] **INFR-01**: Package passes R CMD check with no errors/warnings
- [ ] **INFR-02**: Tests use mocking (vcr/webmockr), no real API calls
- [ ] **INFR-03**: on_doctor() reports backend dependency status

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Enhanced Discovery

- **DISC-05**: Search filtered by modality (MRI, EEG, etc.)
- **DISC-06**: Search filtered by species
- **DISC-07**: Paginated search results with cursor

### Enhanced Downloads

- **DOWN-05**: Concurrent multi-file downloads for large datasets
- **DOWN-06**: Checksum verification after download
- **DOWN-07**: Subset downloads (specific files/subjects only)

### Pipeline Integration

- **PIPE-01**: tar_openneuro() targets helper
- **PIPE-02**: on_bids() returns BIDS descriptor object

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Upload/write operations | Read-only access for v1; OpenNeuro upload has separate workflow |
| OAuth/social login | API key + bearer token sufficient; OpenNeuro uses simple auth |
| BIDS validation | Separate concern; integrate with existing BIDS packages |
| Real-time notifications | Not needed for data access patterns |
| GUI/RStudio integration | CLI/programmatic access only for v1 |
| Offline search index | High complexity, defer indefinitely |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| DISC-01 | Phase 1 | Complete |
| DISC-02 | Phase 1 | Complete |
| DISC-03 | Phase 1 | Complete |
| DISC-04 | Phase 1 | Complete |
| DOWN-01 | Phase 2 | Complete |
| DOWN-02 | Phase 2 | Complete |
| DOWN-03 | Phase 2 | Complete |
| DOWN-04 | Phase 2 | Complete |
| BACK-01 | Phase 2 | Complete |
| BACK-02 | Phase 4 | Pending |
| BACK-03 | Phase 4 | Pending |
| BACK-04 | Phase 4 | Pending |
| CACH-01 | Phase 3 | Pending |
| CACH-02 | Phase 3 | Pending |
| CACH-03 | Phase 3 | Pending |
| CACH-04 | Phase 3 | Pending |
| HAND-01 | Phase 4 | Pending |
| HAND-02 | Phase 4 | Pending |
| HAND-03 | Phase 4 | Pending |
| INFR-01 | Phase 5 | Pending |
| INFR-02 | Phase 5 | Pending |
| INFR-03 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 22 total
- Mapped to phases: 22
- Unmapped: 0

---
*Requirements defined: 2026-01-20*
*Last updated: 2026-01-20 after roadmap creation*

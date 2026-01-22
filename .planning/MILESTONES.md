# Project Milestones: openneuro

## v1.0 MVP (Shipped: 2026-01-22)

**Delivered:** Complete R package for OpenNeuro data access with GraphQL discovery, multi-backend downloads, smart caching, and pipeline-friendly lazy handles.

**Phases completed:** 1-5 (13 plans total)

**Key accomplishments:**

- GraphQL-based dataset discovery API (on_search, on_dataset, on_snapshots, on_files)
- HTTPS download engine with progress bar, retry, and resume support
- CRAN-compliant caching layer with manifest tracking
- Multi-backend support: DataLad, S3 (AWS CLI), and HTTPS with auto-select
- Lazy handle pattern for pipeline-friendly deferred downloads
- Comprehensive test infrastructure with httptest2 mocking (142 tests)

**Stats:**

- 157 files created/modified
- 6,239 lines of R
- 5 phases, 13 plans
- 2 days from start to ship

**Git range:** `feat(01-01)` → `feat(05-02)`

**What's next:** Enhanced discovery (modality/species filters), concurrent downloads, targets integration

---

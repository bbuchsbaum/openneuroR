# openneuro 0.1.0

## Initial Release

* Search and explore OpenNeuro datasets via GraphQL API
  - `on_search()` - Full-text and modality-based search
  - `on_dataset()` - Detailed metadata retrieval
  - `on_snapshots()` - List version history
  - `on_files()` - Browse file trees

* Download datasets with multi-backend support
  - `on_download()` - Download files with automatic backend selection
  - HTTPS fallback always available
  - S3 (via AWS CLI) for faster parallel downloads
  - DataLad for version-controlled provenance tracking

* CRAN-compliant caching with manifest tracking
  - `on_cache_list()`, `on_cache_info()`, `on_cache_clear()`
  - Platform-appropriate cache locations via `tools::R_user_dir()`
  - Atomic writes prevent corrupt manifests
  - Resume support for large downloads

* Lazy handle pattern for pipeline integration

  - `on_handle()` - Create lazy dataset references
  - `on_fetch()` - Materialize data when needed
  - `on_path()` - Get local paths for immediate use

* Developer utilities
  - `on_client()` - Create and configure API clients
  - `on_doctor()` - Diagnose backend availability
  - Comprehensive mocked test suite with httptest2

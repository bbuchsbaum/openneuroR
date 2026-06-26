# openneuro 0.1.0

## Bug fixes

* `on_files()` (and therefore `on_download()`, which lists files before
  fetching) no longer fails with `HTTP 400 GRAPHQL_VALIDATION_FAILED`. The
  `getFiles` query requested a `key` field that the current OpenNeuro schema
  no longer exposes on `DatasetFile`; the query now requests `id` (the
  directory tree token) and `urls` (direct HTTPS download links) instead
  (#1).
* `on_files()` now returns an `id` column (the token to pass back as `tree`
  when recursing into a directory) and a `urls` list column. The `key`
  column is retained as a backward-compatible alias of `id`.
* GraphQL validation/HTTP errors are no longer reported as
  *"Network error connecting to OpenNeuro / Check your internet
  connection."* The API's actual error message (e.g. a
  `GRAPHQL_VALIDATION_FAILED` reason) is now surfaced, and genuine
  connectivity failures remain distinct (#1).
* `on_doctor()` and backend auto-selection no longer treat a broken AWS CLI
  as available. The S3 backend check now runs `aws --version` and requires a
  clean exit, instead of only looking for the `aws` binary on `PATH` (#1).

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

# Changelog

## openneuro 0.1.0

### Initial Release

- Search and explore OpenNeuro datasets via GraphQL API

  - [`on_search()`](https://bbuchsbaum.github.io/openneuroR/reference/on_search.md) -
    Full-text and modality-based search
  - [`on_dataset()`](https://bbuchsbaum.github.io/openneuroR/reference/on_dataset.md) -
    Detailed metadata retrieval
  - [`on_snapshots()`](https://bbuchsbaum.github.io/openneuroR/reference/on_snapshots.md) -
    List version history
  - [`on_files()`](https://bbuchsbaum.github.io/openneuroR/reference/on_files.md) -
    Browse file trees

- Download datasets with multi-backend support

  - [`on_download()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download.md) -
    Download files with automatic backend selection
  - HTTPS fallback always available
  - S3 (via AWS CLI) for faster parallel downloads
  - DataLad for version-controlled provenance tracking

- CRAN-compliant caching with manifest tracking

  - [`on_cache_list()`](https://bbuchsbaum.github.io/openneuroR/reference/on_cache_list.md),
    [`on_cache_info()`](https://bbuchsbaum.github.io/openneuroR/reference/on_cache_info.md),
    [`on_cache_clear()`](https://bbuchsbaum.github.io/openneuroR/reference/on_cache_clear.md)
  - Platform-appropriate cache locations via
    [`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html)
  - Atomic writes prevent corrupt manifests
  - Resume support for large downloads

- Lazy handle pattern for pipeline integration

  - [`on_handle()`](https://bbuchsbaum.github.io/openneuroR/reference/on_handle.md) -
    Create lazy dataset references
  - [`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md) -
    Materialize data when needed
  - [`on_path()`](https://bbuchsbaum.github.io/openneuroR/reference/on_path.md) -
    Get local paths for immediate use

- Developer utilities

  - [`on_client()`](https://bbuchsbaum.github.io/openneuroR/reference/on_client.md) -
    Create and configure API clients
  - [`on_doctor()`](https://bbuchsbaum.github.io/openneuroR/reference/on_doctor.md) -
    Diagnose backend availability
  - Comprehensive mocked test suite with httptest2

# Changelog

## openneuro 0.1.0

### Bug fixes

- [`on_files()`](https://bbuchsbaum.github.io/openneuroR/reference/on_files.md)
  (and therefore
  [`on_download()`](https://bbuchsbaum.github.io/openneuroR/reference/on_download.md),
  which lists files before fetching) no longer fails with
  `HTTP 400 GRAPHQL_VALIDATION_FAILED`. The `getFiles` query requested a
  `key` field that the current OpenNeuro schema no longer exposes on
  `DatasetFile`; the query now requests `id` (the directory tree token)
  and `urls` (direct HTTPS download links) instead
  ([\#1](https://github.com/bbuchsbaum/openneuroR/issues/1)).
- [`on_files()`](https://bbuchsbaum.github.io/openneuroR/reference/on_files.md)
  now returns an `id` column (the token to pass back as `tree` when
  recursing into a directory) and a `urls` list column. The `key` column
  is retained as a backward-compatible alias of `id`.
- GraphQL validation/HTTP errors are no longer reported as *“Network
  error connecting to OpenNeuro / Check your internet connection.”* The
  API’s actual error message (e.g. a `GRAPHQL_VALIDATION_FAILED` reason)
  is now surfaced, and genuine connectivity failures remain distinct
  ([\#1](https://github.com/bbuchsbaum/openneuroR/issues/1)).
- [`on_doctor()`](https://bbuchsbaum.github.io/openneuroR/reference/on_doctor.md)
  and backend auto-selection no longer treat a broken AWS CLI as
  available. The S3 backend check now runs `aws --version` and requires
  a clean exit, instead of only looking for the `aws` binary on `PATH`
  ([\#1](https://github.com/bbuchsbaum/openneuroR/issues/1)).

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

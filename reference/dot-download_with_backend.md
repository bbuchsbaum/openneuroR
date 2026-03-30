# Download with Backend and Fallback

Executes download using the selected backend with automatic fallback on
failure. Falls back through the priority chain: DataLad -\> S3 -\>
HTTPS.

## Usage

``` r
.download_with_backend(
  dataset_id,
  dest_dir,
  files = NULL,
  backend = NULL,
  quiet = FALSE,
  timeout = 1800,
  bucket = "openneuro.org"
)
```

## Arguments

- dataset_id:

  Character string: Dataset identifier (e.g., "ds000001"). For
  derivatives from openneuro-derivatives bucket, caller constructs path
  as `{pipeline}/{dataset_id}-{pipeline}`.

- dest_dir:

  Character string: Destination directory path.

- files:

  Character vector: Specific files to download. If NULL, downloads all.

- backend:

  Character string: Backend to use. If NULL, auto-selects.

- quiet:

  Logical: If TRUE, suppress progress output.

- timeout:

  Numeric: Timeout in seconds for backend operations.

- bucket:

  Character string: S3 bucket name. Default "openneuro.org". Use
  "openneuro-derivatives" for derivative datasets.

## Value

A list with:

- success:

  Logical: TRUE if download succeeded

- backend:

  Character: Backend that was used

Returns NULL if HTTPS fallback should be used (signals caller to use
existing HTTPS flow).

## Details

Supports multiple S3 buckets:

- `openneuro.org` - Raw datasets (default)

- `openneuro-derivatives` - Pre-computed derivatives

When verbose logging is enabled (quiet = FALSE), detailed progress is
shown:

- Backend selection messages

- Bucket information for S3 downloads

- Fallback attempts with error context

Note: For openneuro-derivatives bucket, the DataLad fallback uses
github.com/OpenNeuroDerivatives/ instead of
github.com/OpenNeuroDatasets/. This is handled by the caller
constructing appropriate dataset_id.

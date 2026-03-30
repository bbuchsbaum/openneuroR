# Download Dataset via S3 Backend

Uses AWS CLI `s3 sync` command to download datasets from an OpenNeuro S3
bucket. Supports selective file downloads via include/exclude patterns.

## Usage

``` r
.download_s3(
  dataset_id,
  dest_dir,
  files = NULL,
  quiet = FALSE,
  timeout = 1800,
  bucket = "openneuro.org"
)
```

## Arguments

- dataset_id:

  Character string: Dataset identifier (e.g., "ds000001"). For
  derivatives, caller constructs path as
  `<pipeline>/<dataset_id>-<pipeline>`.

- dest_dir:

  Character string: Destination directory path.

- files:

  Character vector: Specific files/patterns to download. If NULL,
  downloads all files. Patterns support glob syntax.

- quiet:

  Logical: If TRUE, suppress progress output.

- timeout:

  Numeric: Timeout in seconds. Default 1800 (30 minutes).

- bucket:

  Character string: S3 bucket name. Default "openneuro.org". Use
  "openneuro-derivatives" for derivative datasets.

## Value

Invisibly returns a list with:

- success:

  Logical: TRUE if download succeeded

- backend:

  Character: "s3"

## Details

Uses `--no-sign-request` for anonymous access to public S3 buckets.

Supported buckets:

- `openneuro.org` - Raw datasets (default)

- `openneuro-derivatives` - Pre-computed derivatives (fMRIPrep, MRIQC,
  etc.)

When `files` is provided, the function first excludes all files
(`--exclude "*"`) then includes only the specified patterns. This is the
correct order for AWS CLI include/exclude logic.

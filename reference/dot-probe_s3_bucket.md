# Probe S3 Bucket Accessibility

Tests whether an S3 bucket is accessible via anonymous access. Results
are cached per-session to avoid repeated network probes.

## Usage

``` r
.probe_s3_bucket(bucket, test_path = NULL, refresh = FALSE)
```

## Arguments

- bucket:

  Character string: S3 bucket name (e.g., "openneuro.org").

- test_path:

  Character string: Optional path within bucket to test. Useful for
  buckets with restricted ListObjectsV2 permissions. If NULL, probes
  bucket root.

- refresh:

  Logical: If TRUE, bypass cache and probe again.

## Value

Logical: TRUE if bucket is accessible, FALSE otherwise.

## Details

Uses `aws s3 ls --no-sign-request` to test bucket access. The probe has
a 10-second timeout to avoid blocking on network issues.

Results are cached in `.discovery_cache` with key format
`s3_bucket_probe_<bucket>` (or `s3_bucket_probe_<bucket>_<test_path>` if
test_path is provided).

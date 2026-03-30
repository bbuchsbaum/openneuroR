# List Derivative Files from OpenNeuroDerivatives S3 Bucket

Lists files from the OpenNeuroDerivatives S3 bucket using the AWS CLI.
This function handles the `s3://openneuro-derivatives/` bucket
structure.

## Usage

``` r
.list_derivative_files_s3(dataset_id, pipeline)
```

## Arguments

- dataset_id:

  Character string: Dataset identifier (e.g., "ds000102").

- pipeline:

  Character string: Pipeline name (e.g., "fmriprep").

## Value

Character vector: Filenames found in the S3 bucket. Returns empty vector
with warning if access is denied or AWS CLI is not available.

## Details

The OpenNeuroDerivatives S3 bucket uses the structure:
`s3://openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/`

This function uses `--no-sign-request` for anonymous access and limits
results to 500 items for efficiency.

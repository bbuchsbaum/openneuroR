# Create Empty Derivatives Tibble

Returns a tibble with the correct structure for derivative discovery but
zero rows. Used as the base structure for on_derivatives() results.

## Usage

``` r
.empty_derivatives_tibble()
```

## Value

An empty tibble with derivative columns:

- dataset_id:

  Dataset identifier (character)

- pipeline:

  Pipeline name, e.g., "fmriprep" (character)

- source:

  Source of derivative: "embedded" or "openneuro-derivatives"
  (character)

- version:

  Pipeline version if available (character)

- n_subjects:

  Number of subjects processed (integer)

- n_files:

  Number of derivative files (integer)

- total_size:

  Human-readable size string, e.g., "2.3 GB" (character)

- last_modified:

  Last modification time (POSIXct)

- s3_url:

  S3 URL for OpenNeuroDerivatives sources (character)

# Construct S3 Download URL for OpenNeuro File

Builds the direct S3 HTTPS URL for downloading a file from OpenNeuro.

## Usage

``` r
.construct_download_url(dataset_id, file_path)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- file_path:

  Path to file within the dataset (e.g., "sub-01/anat/T1w.nii.gz").

## Value

A URL string for downloading the file.

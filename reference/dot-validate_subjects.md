# Validate Subject IDs Against Available Subjects

Checks that requested subject IDs exist in the dataset.

## Usage

``` r
.validate_subjects(requested, available, dataset_id)
```

## Arguments

- requested:

  Character vector of requested subject IDs.

- available:

  Character vector of available subject IDs from API.

- dataset_id:

  Dataset identifier for error messages.

## Value

Character vector of normalized requested IDs (with "sub-" prefix).

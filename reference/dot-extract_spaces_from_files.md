# Extract Unique Spaces from Filenames

Extracts unique space labels from a vector of BIDS-formatted filenames.
Results are sorted alphabetically and NAs are removed.

## Usage

``` r
.extract_spaces_from_files(filenames)
```

## Arguments

- filenames:

  Character vector: BIDS-formatted filenames.

## Value

Character vector: Unique space labels, sorted alphabetically. Returns
`character(0)` if no spaces are found.

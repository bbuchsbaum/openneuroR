# Extract BIDS Suffix from Filename

Extracts the BIDS suffix from a filename. The suffix is the part after
the last underscore and before the extension.

## Usage

``` r
.extract_suffix_from_filename(filename)
```

## Arguments

- filename:

  Character string: a BIDS-formatted filename.

## Value

Character string: the suffix, or `NA_character_` if none found.

## Details

Handles compound extensions like `.nii.gz`, `.func.gii`,
`.dtseries.nii`.

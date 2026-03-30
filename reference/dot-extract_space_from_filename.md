# Extract Space from BIDS Filename

Extracts the space label from a BIDS-formatted filename. Looks for the
`_space-<label>` entity pattern.

## Usage

``` r
.extract_space_from_filename(filename)
```

## Arguments

- filename:

  Character string: A BIDS-formatted filename.

## Value

Character string: The space label, or `NA_character_` if no space entity
is found.

## Details

This function does NOT infer T1w from files without a space entity. Per
BIDS convention, native space files often omit the space entity, so
absence of `_space-` does not imply T1w space.

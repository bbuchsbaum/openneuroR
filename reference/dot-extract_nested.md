# Extract Nested Value Safely

Extracts a value from a nested list structure, returning NA if not
found.

## Usage

``` r
.extract_nested(x, ..., default = NA)
```

## Arguments

- x:

  A list object.

- ...:

  Names of nested elements to traverse.

- default:

  Default value if path not found.

## Value

The value at the specified path, or the default value.

# Fetch Handle (Materialize Download)

Materializes a lazy handle by downloading the referenced dataset. If the
handle is already in "ready" state, returns it unchanged unless
`force = TRUE`.

## Usage

``` r
on_fetch(handle, ...)

# S3 method for class 'openneuro_handle'
on_fetch(handle, quiet = FALSE, force = FALSE, ...)
```

## Arguments

- handle:

  An object to fetch. For `openneuro_handle` objects, triggers the
  download.

- ...:

  Additional arguments passed to methods.

- quiet:

  If TRUE, suppress progress output during download.

- force:

  If TRUE, re-download even if handle is already "ready".

## Value

The handle with updated state. For `openneuro_handle`, returns the
handle with `state = "ready"`, `path` set to the download location, and
`fetch_time` set to current time.

## Important

You must capture the return value! S3 objects have copy semantics:

    # CORRECT
    handle <- on_fetch(handle)

    # WRONG - changes are lost
    on_fetch(handle)

## See also

[`on_handle()`](https://bbuchsbaum.github.io/openneuroR/reference/on_handle.md)
to create a handle,
[`on_path()`](https://bbuchsbaum.github.io/openneuroR/reference/on_path.md)
to get path.

## Examples

``` r
if (FALSE) { # \dontrun{
handle <- on_handle("ds000001", files = "participants.tsv")
handle <- on_fetch(handle)  # Downloads now
handle$state  # "ready"
} # }
```

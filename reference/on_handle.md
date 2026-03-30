# Create Lazy Handle to OpenNeuro Dataset

Creates a lazy handle that references an OpenNeuro dataset without
triggering an immediate download. The handle can be fetched later when
the data is actually needed.

## Usage

``` r
on_handle(dataset_id, tag = NULL, files = NULL, backend = NULL)
```

## Arguments

- dataset_id:

  Dataset identifier (e.g., "ds000001").

- tag:

  Snapshot version tag. If NULL, uses latest snapshot when fetched.

- files:

  Character vector of specific files to download when fetched, or a
  regex pattern. If NULL, downloads all files when fetched.

- backend:

  Backend to use when fetching: "datalad", "s3", or "https". If NULL,
  auto-selects best available backend.

## Value

An S3 object of class `openneuro_handle` with state "pending".

## Details

Handles support a lazy evaluation pattern:

1.  Create handle with `on_handle()` - no download occurs

2.  Fetch data with
    [`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md) -
    download happens here

3.  Get path with
    [`on_path()`](https://bbuchsbaum.github.io/openneuroR/reference/on_path.md) -
    returns filesystem path

This is useful for pipelines where dataset references need to be defined
early but data should only be downloaded when needed.

## Important

S3 objects have copy semantics. You must capture the return value of
[`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md):

    # WRONG - handle not updated
    on_fetch(handle)
    handle$state  # Still "pending"!

    # CORRECT - capture returned handle
    handle <- on_fetch(handle)
    handle$state  # Now "ready"

## See also

[`on_fetch()`](https://bbuchsbaum.github.io/openneuroR/reference/on_fetch.md)
to materialize the download,
[`on_path()`](https://bbuchsbaum.github.io/openneuroR/reference/on_path.md)
to get path.

## Examples

``` r
if (FALSE) { # \dontrun{
# Create lazy handle - no download yet
handle <- on_handle("ds000001", files = "participants.tsv")
print(handle)  # Shows state: pending

# Fetch when data is needed
handle <- on_fetch(handle)
print(handle)  # Shows state: ready

# Get filesystem path
path <- on_path(handle)
} # }
```

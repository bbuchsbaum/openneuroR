# Architecture: bidser Integration

**Milestone:** bidser integration
**Researched:** 2026-01-22
**Confidence:** HIGH

## Layer Placement

```
Layer A: GraphQL Client
  on_client(), on_request()
  on_dataset(), on_search(), on_files()
+ on_subjects()  <-- NEW: queries API for subject list

Layer B: Download Backends
  .download_datalad(), .download_s3(), .download_https()
  (no changes needed)

Layer C: Cache + Handle
  on_handle(), on_fetch(), on_path()
+ on_download(..., subjects=)  <-- ENHANCED: filter by subjects
+ on_bids()                    <-- NEW: orchestrates fetch + bids_project
```

## Data Flow: on_bids()

```
User                    Layer C              Layer B              bidser
  |                        |                    |                    |
  |-- on_bids(handle) ---->|                    |                    |
  |                        |                    |                    |
  |                        |-- on_fetch() ----->|                    |
  |                        |                    |-- download ------->|
  |                        |                    |<-- files ----------|
  |                        |<-- path -----------|                    |
  |                        |                    |                    |
  |                        |-- bids_project(path) ------------------>|
  |                        |<-- bids_project object -----------------|
  |                        |                    |                    |
  |<-- bids_project -------|                    |                    |
```

## Data Flow: Subject Filtering

```
User                    Layer A              Layer C
  |                        |                    |
  |-- on_subjects(id) ---->|                    |
  |                        |-- GraphQL -------->|
  |                        |<-- ["01","02"...] -|
  |<-- subject vector -----|                    |
  |                        |                    |
  |-- on_download(id, subjects=c("01","02")) -->|
  |                        |                    |-- filter files by sub-01/, sub-02/
  |                        |                    |-- download filtered set
```

## New Functions

| Function | Layer | Dependencies | Purpose |
|----------|-------|--------------|---------|
| `on_subjects(id, tag)` | A | GraphQL | Return subject IDs from API |
| `on_bids(handle)` | C | bidser | Fetch + create bids_project |
| `on_download(..., subjects)` | C | on_subjects | Filter download by subject |

## Integration Points

**on_subjects() -> GraphQL:**
- Query: extend `get_dataset.gql` or new query for `snapshot.summary.subjects`
- Returns: character vector of subject IDs (e.g., `c("01", "02", "03")`)

**on_download() -> subject filtering:**
- Filter file list using regex: `^sub-(01|02|03)/` pattern
- Applied before download dispatch to any backend

**on_bids() -> bidser:**
- Calls `bidser::bids_project(on_path(handle))`
- bidser is Suggests, not Imports (graceful error if missing)

## No Changes Needed

- Layer B backends: subject filtering happens before backend dispatch
- on_handle(): unchanged, still creates lazy reference
- on_fetch(): unchanged, still materializes download
- on_path(): unchanged, still returns filesystem path

## Dependency Management

```r
# DESCRIPTION
Suggests:
    bidser
```

```r
# In on_bids()
on_bids <- function(handle, fmriprep = FALSE) {
  rlang::check_installed("bidser", reason = "to create BIDS project objects")
  handle <- on_fetch(handle)
  bidser::bids_project(on_path(handle), fmriprep = fmriprep)
}
```

## Sources

- bidser docs: https://bbuchsbaum.github.io/bidser/reference/bids_project.html
- `bids_project(path, fmriprep=FALSE, prep_dir="derivatives/fmriprep")`
- `participants(proj)` returns subject ID vector

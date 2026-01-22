# Feature Landscape: BIDS Integration for openneuroR v1.1

**Domain:** BIDS-aware neuroimaging data access
**Researched:** 2026-01-22
**Confidence:** HIGH (verified via bidser docs, OpenNeuro GraphQL schema, openneuro-py patterns)

---

## User Workflow

```
Discovery → Subsetting → Download → Analysis
    |           |            |          |
on_search() → on_subjects() → on_download() → on_bids()
                    ↓              ↓              ↓
              Subject list    subjects=c()    bids_project()
```

**Primary flow:**
1. User finds dataset via `on_search()` or knows dataset ID
2. User queries subjects without downloading: `on_subjects("ds000001")`
3. User downloads subset: `on_download("ds000001", subjects = c("01", "02"))`
4. User gets bidser object: `proj <- on_bids(handle)` for analysis

---

## Table Stakes

Features users expect for BIDS integration. Missing = incomplete.

| Feature | Input | Output | Complexity |
|---------|-------|--------|------------|
| `on_bids(handle)` | fetched handle | `bids_project` object | Low |
| `on_subjects(id)` | dataset_id | character vector | Low |
| `on_download(..., subjects=)` | id + subject IDs | downloaded subset | Medium |
| Graceful bidser absence | any BIDS call | informative error | Low |

### on_bids(handle)

**Purpose:** Fetch dataset and return bidser's `bids_project` object.

```r
handle <- on_handle("ds000001") |> on_fetch()
proj <- on_bids(handle)
# Equivalent to: bidser::bids_project(on_path(handle))
```

**Behaviors:**
- Auto-fetches if handle is pending
- Returns `bids_project` ready for `participants()`, `func_scans()`, etc.
- Fails gracefully if bidser not installed

### on_subjects(dataset_id)

**Purpose:** List subject IDs from OpenNeuro metadata without downloading.

```r
subs <- on_subjects("ds000001")
#> [1] "01" "02" "03" "04" ...
```

**Implementation:** Query `summary.subjects` from GraphQL (already in search_datasets.gql).

### on_download(..., subjects=)

**Purpose:** Download only specified subjects.

```r
on_download("ds000001", subjects = c("01", "02"))
```

**Behaviors:**
- Filters file list to `sub-XX/` directories + root BIDS files
- Always includes: `dataset_description.json`, `participants.tsv`, `README*`
- Validates subject IDs against `on_subjects()` before download

---

## Differentiators

Features that add value but aren't strictly expected.

| Feature | Value | Complexity | Recommendation |
|---------|-------|------------|----------------|
| `on_tasks(id)` | List tasks pre-download | Low | Defer to v1.2 |
| `on_modalities(id)` | List modalities | Low | Defer to v1.2 |
| `on_sessions(id)` | List sessions | Medium | Defer to v1.2 |
| `on_download(..., tasks=)` | Task filtering | Medium | Defer to v1.2 |

**Rationale:** Keep v1.1 focused on subject-level operations. Tasks/sessions add API surface without critical user value.

---

## Anti-Features

Things to NOT build.

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| BIDS validation | Separate concern | Users run `bids-validator` |
| BIDS writing | Out of scope | Use bidser directly |
| Custom BIDS parsing | Reinvents bidser | Delegate to bidser |
| Embedded bidser | Forces heavy dep | Optional Suggests |
| Subject metadata API | Overlaps bidser | Use `on_bids()` then `participants()` |

---

## Feature Dependencies

```
on_subjects(id)        # Independent (GraphQL only)
       ↓
on_download(subjects=) # Uses on_subjects() for validation
       ↓
on_bids(handle)        # Requires fetched handle + bidser
       ↓
bidser::bids_project() # External package
```

**Build order:** on_subjects → subject filtering → on_bids bridge

---

## MVP Scope for v1.1

**Table stakes (must ship):**
1. `on_subjects(dataset_id)` - Pre-download subject listing
2. `on_download(..., subjects=)` - Selective download
3. `on_bids(handle)` - bidser bridge

**Infrastructure:**
- bidser in Suggests (not Imports)
- `.check_bidser()` helper for graceful failure
- New GraphQL query or field access for subject list

**Deferred:**
- on_tasks(), on_modalities(), on_sessions()
- Task/session filtering in download

---

## Sources

- [bidser documentation](https://bbuchsbaum.github.io/bidser/) - bids_project() workflow
- [OpenNeuro API docs](https://docs.openneuro.org/api.html) - GraphQL schema
- [openneuro-py](https://github.com/hoechenberger/openneuro-py) - include/exclude patterns
- openneuroR search_datasets.gql - confirms `summary.subjects` field available

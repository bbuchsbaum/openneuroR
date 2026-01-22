---
phase: "08"
plan: "01"
status: complete
subsystem: bridge
tags: [bids, bidser, integration, optional-dependency]

dependency_graph:
  requires: [phase-04]  # Requires handle API from phase 4
  provides: [on_bids]
  affects: []  # Final phase of v1.1

tech_stack:
  added:
    - bidser (Suggests)
  patterns:
    - Optional dependency via check_installed()
    - Namespace-qualified calls (pkg::fun)
    - BIDS structure validation

key_files:
  created:
    - R/bids.R
    - tests/testthat/test-bids.R
    - man/on_bids.Rd
  modified:
    - DESCRIPTION
    - NAMESPACE

decisions:
  - key: return-type
    choice: "Return bids_project directly, not wrapped"
    reason: "Let bidser's API shine through"
  - key: error-classes
    choice: "openneuro_bids_error for BIDS validation failures"
    reason: "Distinct from validation errors, easier to catch"
  - key: auto-fetch
    choice: "Auto-fetch pending handles before BIDS project creation"
    reason: "Reduces friction for users"

metrics:
  duration: "4m 29s"
  completed: "2026-01-22"
---

# Phase 8 Plan 1: BIDS Bridge Summary

**One-liner:** Bridge openneuro handles to bidser bids_project objects with optional dependency handling.

## Completed Tasks

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Create on_bids() function with optional dependency handling | 65428b4 | R/bids.R, DESCRIPTION, NAMESPACE, man/on_bids.Rd |
| 2 | Create comprehensive tests with mocking | 258e4b2 | tests/testthat/test-bids.R |
| 3 | Final verification and R CMD check | (verification only) | - |

## Key Implementations

### on_bids() Function

```r
on_bids(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep")
```

Creates a `bids_project` object from an OpenNeuro handle:
- Validates input is `openneuro_handle`
- Auto-fetches pending handles
- Validates BIDS structure (dataset_description.json required)
- Supports fMRIPrep derivatives via `fmriprep=TRUE`
- Supports custom derivatives paths via `prep_dir`
- `prep_dir` takes precedence over `fmriprep=TRUE` when both specified

### Helper Functions (Internal)

- `.validate_bids_structure(path)` - Checks for dataset_description.json
- `.check_derivatives_path(path, fmriprep, prep_dir)` - Validates derivatives path exists

### Optional Dependency Pattern

```r
# Check for bidser availability first
rlang::check_installed(
  "bidser",
  reason = "to create BIDS project objects from OpenNeuro datasets"
)

# Then use namespace-qualified call
bidser::bids_project(...)
```

## Test Coverage

24 tests in test-bids.R covering:
- Input validation (non-handle rejection)
- Error message quality (suggests on_handle())
- BIDS structure validation
- Derivatives path warnings
- Auto-fetch behavior
- Argument passing to bidser
- Dependency check verification
- Integration tests (skip if bidser not installed)

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

- **R CMD check:** 0 errors, 0 warnings, 0 notes
- **Tests:** 495 passing, 1 skip (expected)
- **Manual verification:** on_bids() successfully creates bids_project

## v1.1 Milestone Complete

With this phase, v1.1 BIDS Integration is complete:

| Feature | Status | Phase |
|---------|--------|-------|
| on_subjects() | SHIPPED | 06-01 |
| on_download(..., subjects=) | SHIPPED | 07-01 |
| regex() | SHIPPED | 07-01 |
| on_bids() | SHIPPED | 08-01 |

**v1.1 Public API Additions:**
- `on_subjects(id)` - List subjects in a dataset
- `regex(pattern)` - Create regex pattern for subject filtering
- `on_download(..., subjects=, include_derivatives=)` - Subject-filtered downloads
- `on_bids(handle)` - Bridge to bidser for BIDS-aware access

## Files Changed

### Created
- `R/bids.R` (166 lines) - on_bids() and helpers
- `tests/testthat/test-bids.R` (493 lines) - Comprehensive test suite
- `man/on_bids.Rd` - Generated documentation

### Modified
- `DESCRIPTION` - Added bidser to Suggests
- `NAMESPACE` - Added on_bids export

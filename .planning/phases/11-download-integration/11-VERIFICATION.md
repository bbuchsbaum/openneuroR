---
phase: 11-download-integration
verified: 2026-01-23T22:45:00Z
status: passed
score: 6/6 must-haves verified
---

# Phase 11: Download Integration Verification Report

**Phase Goal:** Users can download filtered derivative data with full test coverage
**Verified:** 2026-01-23T22:45:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can call `on_download_derivatives()` to download fMRIPrep derivatives | ✓ VERIFIED | Function exists (888 lines), exported in NAMESPACE, has complete roxygen docs with examples |
| 2 | User can filter by subject via `subjects=` parameter (reuses v1.1 pattern) | ✓ VERIFIED | Parameter exists, uses `.normalize_subject_ids()` from subject-filter.R, supports literal and regex() patterns |
| 3 | User can filter by output space via `space=` parameter | ✓ VERIFIED | Parameter exists, calls `.filter_files_by_space()` which uses `.extract_space_from_filename()` from discovery-spaces.R |
| 4 | Downloaded derivatives stored in BIDS-compliant path: `{dataset}/derivatives/{pipeline}/` | ✓ VERIFIED | `.on_derivative_cache_path()` returns `{cache}/{dataset_id}/derivatives/{pipeline}/` (line 869-872) |
| 5 | All new functions have mocked tests (no real API/downloads in test suite) | ✓ VERIFIED | test-download-derivatives.R has 927 lines, 36 test_that blocks, 19 uses of local_mocked_bindings, no real network calls |
| 6 | Package passes R CMD check with 0 errors, 0 warnings after changes | ✓ VERIFIED | R CMD check run completed: "0 errors ✔ | 0 warnings ✔ | 0 notes ✔" |

**Score:** 6/6 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/download-derivatives.R` | Main download function with all filters | ✓ VERIFIED | 888 lines, exported on_download_derivatives(), includes all filter helpers |
| `tests/testthat/test-download-derivatives.R` | Comprehensive mocked tests | ✓ VERIFIED | 927 lines, 36 tests covering validation, filters, dry_run, cache paths, type field |
| `R/cache-manifest.R` | Type field support | ✓ VERIFIED | `.update_manifest()` has `type = "raw"` parameter (line 147), includes `type = type` in file_entry (line 161) |
| `R/cache-management.R` | Type column in cache list | ✓ VERIFIED | `on_cache_list()` returns tibble with type column (lines 92, 111) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| on_download_derivatives() | .normalize_subject_ids() | Subject normalization | ✓ WIRED | Line 238: `normalized <- .normalize_subject_ids(subjects)` |
| on_download_derivatives() | .filter_derivative_files_by_subjects() | Subject filtering | ✓ WIRED | Line 239: filters by normalized subjects (derivative-specific implementation) |
| on_download_derivatives() | .extract_space_from_filename() | Space extraction for filtering | ✓ WIRED | Line 664: `.extract_space_from_filename(basename(path))` |
| on_download_derivatives() | .filter_files_by_space() | Space filtering | ✓ WIRED | Line 245: `files_df <- .filter_files_by_space(files_df, space)` |
| on_download_derivatives() | .filter_files_by_suffix() | Suffix filtering | ✓ WIRED | Line 251: `files_df <- .filter_files_by_suffix(files_df, suffix)` |
| on_download_derivatives() | .download_with_backend() | Actual download with S3 bucket | ✓ WIRED | Line 295: calls with `bucket = "openneuro-derivatives"` (line 301) |
| on_download_derivatives() | .update_manifest() | Manifest update with type='derivative' | ✓ WIRED | Line 308-318: calls with `type = "derivative"` parameter |
| tests | local_mocked_bindings() | Mock all network calls | ✓ WIRED | 19 uses of local_mocked_bindings across test file, no real API/download calls |

### Anti-Patterns Found

**None detected.**

Scanned files:
- R/download-derivatives.R: No TODO/FIXME/placeholders, no empty returns
- R/cache-manifest.R: No issues
- R/cache-management.R: No issues
- tests/testthat/test-download-derivatives.R: No placeholders, comprehensive mocked tests

### Code Quality Assessment

**Substantive Implementation:**
- `on_download_derivatives()`: 888 lines with complete filtering logic
- Test coverage: 927 lines, 36 test blocks
- Filter helpers: `.filter_files_by_space()` (43 lines), `.filter_files_by_suffix()` (40 lines)
- All functions have roxygen documentation
- Exported function appears in NAMESPACE

**Pattern Adherence:**
- Reuses `.normalize_subject_ids()` from subject-filter.R (✓)
- Reuses `.extract_space_from_filename()` from discovery-spaces.R (✓)
- Uses `.download_with_backend()` with bucket parameter (✓)
- Follows on_download() return structure pattern (✓)
- Mocked testing pattern consistent with test-download.R (✓)

**Minor Deviation:**
- Created derivative-specific `.filter_derivative_files_by_subjects()` instead of reusing `.filter_files_by_subjects()` from subject-filter.R
- Rationale: Derivative file paths differ structurally from raw data (derivatives/{pipeline}/ prefix)
- Impact: None - functionality equivalent, tests verify behavior
- Verdict: Acceptable implementation choice

---

## Verification Details

### Truth 1: User can call on_download_derivatives()

**Evidence:**
- Function defined at line 117 in R/download-derivatives.R
- Exported in NAMESPACE (line 17)
- Complete roxygen documentation with @param, @return, @details, @examples
- Example calls in documentation show usage with fmriprep pipeline

**Verification:** ✓ VERIFIED

### Truth 2: Subject filtering with subjects= parameter

**Evidence:**
- Parameter `subjects = NULL` in function signature (line 119)
- Documentation shows support for literal and regex() patterns (lines 9-12)
- Reuses `.normalize_subject_ids()` from subject-filter.R (line 238)
- Literal filter: `.filter_derivative_files_by_subjects()` (line 239)
- Regex filter: `.filter_derivative_files_by_subjects_regex()` (line 235)
- Tests verify both literal and regex subject filtering (lines 77-168 of test file)

**Verification:** ✓ VERIFIED

### Truth 3: Space filtering with space= parameter

**Evidence:**
- Parameter `space = NULL` in function signature (line 120)
- Calls `.filter_files_by_space(files_df, space)` (line 245)
- Helper uses `.extract_space_from_filename()` (line 664) from discovery-spaces.R
- Documentation notes exact matching and native space inclusion (lines 13-16, 74-79)
- Tests verify space filtering and native space handling (lines 193-300 of test file)

**Verification:** ✓ VERIFIED

### Truth 4: BIDS-compliant cache path

**Evidence:**
- `.on_derivative_cache_path()` helper defined (lines 869-872)
- Returns: `fs::path(base_path, "derivatives", pipeline)`
- Base path from `.on_dataset_cache_path(dataset_id)` gives `{cache}/{dataset_id}`
- Final structure: `{cache_root}/{dataset_id}/derivatives/{pipeline}/`
- Used when `use_cache = TRUE` and `dest_dir = NULL` (line 187)
- Documentation explicitly states this structure (line 24, 64)

**Verification:** ✓ VERIFIED

### Truth 5: Mocked tests (no real API/downloads)

**Evidence:**
- test-download-derivatives.R exists with 927 lines
- 36 test_that blocks covering:
  - Input validation (5 tests)
  - Derivative lookup (2 tests)
  - Subject filtering (6 tests)
  - Space filtering (4 tests)
  - Suffix filtering (2 tests)
  - Combined filters (1 test)
  - dry_run (2 tests)
  - Backend/cache paths (3 tests)
  - Helper functions (6 tests)
  - Cache type field (5 tests)
- All network dependencies mocked via `local_mocked_bindings()`:
  - on_client
  - on_derivatives
  - .list_derivative_files_full
  - .download_with_backend
  - .update_manifest
- No grep matches for real AWS CLI calls or API endpoints in test assertions

**Verification:** ✓ VERIFIED

### Truth 6: R CMD check passes

**Evidence:**
- R CMD check run completed successfully
- Output: "0 errors ✔ | 0 warnings ✔ | 0 notes ✔"
- Duration: 20.9s
- All checks passed including:
  - R files for syntax errors
  - Package can be loaded
  - Dependencies in R code
  - Rd files and documentation
  - Examples
  - Tests (Running 'testthat.R' OK)
  - No detritus in temp directory

**Verification:** ✓ VERIFIED

---

## Test Coverage Assessment

### Input Validation Tests
- ✓ dataset_id validation (empty, NULL, non-character)
- ✓ pipeline validation (empty, NULL)
- ✓ Derivative lookup errors (no derivatives, pipeline not found)

### Subject Filter Tests
- ✓ Literal subject IDs (with and without sub- prefix)
- ✓ Regex patterns via regex()
- ✓ Multiple subjects (AND logic within subject list)
- ✓ Root-level files included when filtering subjects

### Space Filter Tests
- ✓ Exact space matching (MNI152NLin2009cAsym)
- ✓ Files without _space- entity included (native space)
- ✓ Unknown space warning issued

### Suffix Filter Tests
- ✓ Single suffix (bold)
- ✓ Multiple suffixes (bold, mask)
- ✓ Suffix extraction from BIDS filenames
- ✓ Compound extension handling (.nii.gz, .func.gii)

### Combined Filter Tests
- ✓ Subject + space + suffix (AND logic)
- ✓ All filters must match

### dry_run Tests
- ✓ Returns tibble without downloading
- ✓ Tibble has path, size, size_formatted, dest_path columns
- ✓ Empty tibble when no matches

### Cache Type Field Tests
- ✓ .update_manifest() accepts type parameter
- ✓ Type defaults to "raw"
- ✓ Type="derivative" passed from on_download_derivatives()
- ✓ on_cache_list() includes type column
- ✓ Type shows "raw", "derivative", or "raw+derivative"
- ✓ Backward compatibility (old manifests default to "raw")

### Backend Tests
- ✓ Uses "openneuro-derivatives" bucket
- ✓ Constructs correct S3 dataset ID (pipeline/dataset_id-pipeline)
- ✓ S3 backend preferred, HTTPS fallback available

**Total test cases:** 36
**Coverage:** Comprehensive - all major code paths covered

---

## Requirements Coverage

Phase 11 requirements from ROADMAP:
- DOWN-01: Download derivative data ✓
- DOWN-02: Filter by subject ✓
- DOWN-03: Filter by space ✓
- DOWN-04: BIDS cache structure ✓
- INFR-01: Mocked tests ✓
- INFR-02: R CMD check passes ✓

All requirements satisfied.

---

## Overall Assessment

**Status:** passed

All 6 success criteria verified:
1. ✓ on_download_derivatives() function exists and works
2. ✓ Subject filtering via subjects= parameter
3. ✓ Space filtering via space= parameter
4. ✓ BIDS-compliant cache path: {dataset}/derivatives/{pipeline}/
5. ✓ All functions have comprehensive mocked tests
6. ✓ R CMD check: 0 errors, 0 warnings, 0 notes

**Code Quality:** Excellent
- Substantive implementations (no stubs)
- All key links properly wired
- Comprehensive test coverage with mocks
- No anti-patterns detected
- Follows established package patterns
- Complete documentation

**Phase Goal Achieved:** YES

Users can download filtered derivative data with:
- fMRIPrep/MRIQC pipeline support
- Subject filtering (literal + regex)
- Output space filtering (exact match)
- BIDS suffix filtering
- dry_run preview mode
- BIDS-compliant cache structure
- Full test coverage (no real downloads in tests)
- Package passing R CMD check

**Ready for Production:** YES

---

_Verified: 2026-01-23T22:45:00Z_
_Verifier: Claude (gsd-verifier)_

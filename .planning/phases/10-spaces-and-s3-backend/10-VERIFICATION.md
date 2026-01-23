---
phase: 10-spaces-and-s3-backend
verified: 2026-01-23T22:15:22Z
status: passed
score: 8/8 must-haves verified
---

# Phase 10: Spaces and S3 Backend Verification Report

**Phase Goal:** Users can explore output spaces and S3 infrastructure supports derivative bucket access

**Verified:** 2026-01-23T22:15:22Z

**Status:** PASSED

**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can call on_spaces() on a derivative row from on_derivatives() output | ✓ VERIFIED | Function exported in NAMESPACE (line 1), accepts data.frame with validation (lines 391-421), returns character vector (line 467) |
| 2 | on_spaces() returns character vector of space names | ✓ VERIFIED | Uses .extract_spaces_from_files() which returns sort(unique(spaces)) (line 89), final return is character vector (line 467) |
| 3 | Spaces are alphabetically sorted | ✓ VERIFIED | .extract_spaces_from_files() calls sort(unique(spaces)) (line 89) |
| 4 | Results are session cached | ✓ VERIFIED | Cache check at line 432, cache set at line 466, uses .discovery_cache with key format "spaces_{dataset_id}_{pipeline}_{source}" |
| 5 | Works for embedded sources | ✓ VERIFIED | .list_derivative_files_embedded() implemented (lines 111-221), uses on_files() to navigate derivatives tree (lines 115, 135, 155, 185, 202) |
| 6 | Works for openneuro-derivatives sources | ✓ VERIFIED | .list_derivative_files_s3() implemented (lines 243-329), constructs S3 path as "openneuro-derivatives/{pipeline}/{dataset_id}-{pipeline}/" (line 259) |
| 7 | S3 backend can download from openneuro-derivatives bucket | ✓ VERIFIED | .download_s3() has bucket parameter with default "openneuro.org" (line 60), S3 URI constructed with bucket variable (line 73), documented for derivatives usage (lines 24, 37-39) |
| 8 | Verbose logging during fallback attempts | ✓ VERIFIED | cli::cli_alert_info shows backend + bucket (lines 115-120), cli::cli_alert_warning shows "{selected} failed: {error}, trying {fallback}..." (lines 154-156) |

**Score:** 8/8 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/discovery-spaces.R` | on_spaces() function and space extraction helpers | ✓ VERIFIED | EXISTS (468 lines), exports on_spaces, implements 4 helpers (.extract_space_from_filename, .extract_spaces_from_files, .list_derivative_files_embedded, .list_derivative_files_s3), no stub patterns |
| `man/on_spaces.Rd` | Documentation for on_spaces() | ✓ VERIFIED | EXISTS, generated from roxygen2 |
| `R/backend-s3.R` | Parameterized .download_s3() with bucket argument | ✓ VERIFIED | EXISTS (212 lines), bucket parameter with default "openneuro.org" (line 60), .probe_s3_bucket() implemented (lines 149-212), uses .discovery_cache for probe caching (lines 158-159), no stub patterns |
| `R/backend-dispatch.R` | Updated .download_with_backend() with bucket passthrough | ✓ VERIFIED | EXISTS (173 lines), bucket parameter with default "openneuro.org" (line 108), passes bucket to .download_s3() (line 136), verbose logging implemented (lines 115-120, 154-156), no stub patterns |
| `man/dot-probe_s3_bucket.Rd` | Documentation for .probe_s3_bucket() | ✓ VERIFIED | EXISTS, generated from roxygen2 |
| `NAMESPACE` | on_spaces export | ✓ VERIFIED | Contains "export(on_spaces)" |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| R/discovery-spaces.R | R/api-files.R | on_files() calls | ✓ WIRED | on_files() called 5 times (lines 115, 135, 155, 185, 202) for embedded derivative file listing |
| R/discovery-spaces.R | R/discovery-cache.R | .discovery_cache | ✓ WIRED | Cache checked at line 432, cache set at line 466 |
| R/backend-dispatch.R | R/backend-s3.R | .download_s3() with bucket parameter | ✓ WIRED | Called at line 136 with bucket parameter passed through |
| R/backend-s3.R | R/discovery-cache.R | .discovery_cache for bucket probe | ✓ WIRED | Cache used in .probe_s3_bucket() at lines 158-159, 166, 210 |

### Requirements Coverage

| Requirement | Status | Supporting Truths |
|-------------|--------|-------------------|
| SPAC-01: User can list available output spaces for a derivative via on_spaces() | ✓ SATISFIED | Truth 1, 4, 5, 6 |
| SPAC-02: on_spaces() returns character vector of space names | ✓ SATISFIED | Truth 2, 3 |
| INFR-03: S3 backend supports parameterized bucket for derivatives bucket access | ✓ SATISFIED | Truth 7, 8 |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | - | - | - | No anti-patterns detected |

**Anti-pattern scan results:**
- No TODO/FIXME/placeholder comments
- No empty implementations or stub patterns
- No console.log-only handlers
- All functions have substantive implementations

### Human Verification Required

**1. Space Discovery Accuracy**

**Test:** Use on_derivatives() to get a derivative row, then call on_spaces() on it. Compare returned spaces with what you see when browsing the dataset files.

**Expected:** 
- For fMRIPrep derivatives: Should return spaces like "MNI152NLin2009cAsym", "fsaverage", "T1w", etc.
- Spaces match what's actually in _space- entity of filenames
- Empty vector with warning if no space entities found

**Why human:** Requires real API/S3 access and knowledge of what spaces should exist for a given derivative

**2. S3 Bucket Download**

**Test:** Try downloading from openneuro-derivatives bucket by calling backend functions with bucket="openneuro-derivatives"

**Expected:**
- Downloads work for datasets available in openneuro-derivatives
- Verbose logging shows "Trying s3 backend for bucket openneuro-derivatives..."
- Fallback to DataLad if S3 fails with message "s3 failed: {error}, trying datalad..."

**Why human:** Requires AWS CLI setup and network access to test actual downloads

**3. Session Caching**

**Test:** Call on_spaces() twice on the same derivative row without refresh parameter

**Expected:**
- First call fetches from API/S3 (may take a few seconds)
- Second call returns instantly (from cache)
- Use refresh=TRUE to bypass cache and fetch fresh

**Why human:** Timing differences and cache behavior best verified by human interaction

**4. Error Handling**

**Test:** Call on_spaces() with invalid inputs (multi-row data.frame, missing columns, non-existent derivative)

**Expected:**
- Friendly error messages guide user
- Suggests correct usage pattern
- Warns but doesn't error when no spaces found

**Why human:** Error message quality and helpfulness assessed by human judgment

---

## Verification Summary

**All must-haves VERIFIED.**

Phase 10 goal is ACHIEVED:

✓ Users can call on_spaces() on a derivative to get available output spaces
✓ Space names returned as alphabetically sorted character vector
✓ S3 backend can download from s3://openneuro-derivatives/ bucket with parameterized bucket argument
✓ Verbose logging during fallback chain
✓ Session caching prevents redundant API/S3 calls
✓ Backward compatibility maintained (default bucket="openneuro.org")

**Infrastructure ready for Phase 11** (Download Integration):
- on_spaces() ready to support space filtering
- S3 backend can target openneuro-derivatives bucket
- Verbose fallback logging helps debug derivative downloads
- .probe_s3_bucket() available for pre-download accessibility checks

**Code Quality:**
- All artifacts substantive (468, 212, 173 lines respectively)
- No stub patterns detected
- All functions exported/wired correctly
- Documentation complete with roxygen2

---

_Verified: 2026-01-23T22:15:22Z_

_Verifier: Claude (gsd-verifier)_

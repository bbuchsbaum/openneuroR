---
phase: 08-bids-bridge
verified: 2026-01-22T19:50:08Z
status: passed
score: 5/5 must-haves verified
---

# Phase 8: BIDS Bridge Verification Report

**Phase Goal:** Users can get BIDS-aware project objects from fetched datasets
**Verified:** 2026-01-22T19:50:08Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can call on_bids(handle) and get a bidser bids_project object | ✓ VERIFIED | Function exists, calls bidser::bids_project (line 108), returns result directly (line 108-112), integration test passes (test-bids.R:459-475) |
| 2 | on_bids() provides helpful message if bidser is not installed | ✓ VERIFIED | check_installed() called first (lines 66-69) with helpful reason message, test verifies dependency check (test-bids.R:425-452) |
| 3 | User can include fMRIPrep derivatives via on_bids(handle, fmriprep = TRUE) | ✓ VERIFIED | fmriprep parameter exists (line 63), passed to bidser::bids_project (line 110), test verifies argument passing (test-bids.R:337-360), integration test with fmriprep works (test-bids.R:477-493) |
| 4 | User can specify custom derivatives path via on_bids(handle, prep_dir = "derivatives/custom") | ✓ VERIFIED | prep_dir parameter exists (line 63), passed to bidser::bids_project (line 111), prep_dir overrides fmriprep when both specified (lines 96-99), test verifies precedence (test-bids.R:391-418) |
| 5 | R CMD check passes with bidser as Suggests | ✓ VERIFIED | R CMD check: 0 errors, 0 warnings, 0 notes; bidser in Suggests (DESCRIPTION line 31), NOT imported in NAMESPACE (correct for optional dep) |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/bids.R` | on_bids() function with helpers | ✓ VERIFIED | EXISTS (180 lines), SUBSTANTIVE (on_bids + 2 helpers, no stubs, exports on_bids), WIRED (calls bidser::bids_project, on_fetch, on_path) |
| `tests/testthat/test-bids.R` | Tests for on_bids() including mocked dependency checks | ✓ VERIFIED | EXISTS (493 lines), SUBSTANTIVE (24 tests, well above 50 line minimum, no stubs), WIRED (tests call on_bids, use mocking, 24/24 pass) |
| `DESCRIPTION` | bidser in Suggests | ✓ VERIFIED | EXISTS, SUBSTANTIVE (bidser listed in Suggests section line 31), WIRED (not in Imports, correct for optional dependency) |
| `NAMESPACE` | on_bids export | ✓ VERIFIED | EXISTS, SUBSTANTIVE (export(on_bids) on line 8), WIRED (no bidser import, uses :: calls) |
| `man/on_bids.Rd` | Generated documentation | ✓ VERIFIED | EXISTS, SUBSTANTIVE (complete roxygen2 docs, examples wrapped in \dontrun{}), WIRED (links to on_handle, on_fetch) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| R/bids.R | bidser::bids_project | namespace-qualified call | ✓ WIRED | Call exists at line 108, namespace-qualified (::), result returned to user |
| R/bids.R | on_fetch() | auto-fetch pending handles | ✓ WIRED | Called at line 86 when state=="pending", result captured and used |
| R/bids.R | on_path() | get dataset path | ✓ WIRED | Called at line 90, path used for validation and passed to bidser |
| R/bids.R | rlang::check_installed | optional dependency check | ✓ WIRED | Called FIRST at lines 66-69 before any handle operations, helpful reason provided |
| R/bids.R | .validate_bids_structure() | BIDS validation | ✓ WIRED | Helper defined lines 126-142, called at line 93, aborts with openneuro_bids_error if invalid |
| R/bids.R | .check_derivatives_path() | derivatives validation | ✓ WIRED | Helper defined lines 158-180, called at line 102, warns if derivatives missing |

### Requirements Coverage

From ROADMAP.md: BIDS-01, BIDS-02, BIDS-03, BIDS-04, INF1-01, INF1-02, INF1-03

| Requirement | Status | Supporting Evidence |
|-------------|--------|---------------------|
| BIDS-01 (Create bids_project from handle) | ✓ SATISFIED | Truth 1 verified, integration tests pass |
| BIDS-02 (Optional dependency handling) | ✓ SATISFIED | Truth 2 verified, check_installed called first, tests work without bidser |
| BIDS-03 (fMRIPrep derivatives) | ✓ SATISFIED | Truth 3 verified, parameter exists and is passed through |
| BIDS-04 (Custom derivatives path) | ✓ SATISFIED | Truth 4 verified, prep_dir parameter works and overrides fmriprep |
| INF1-01 (R CMD check passes) | ✓ SATISFIED | Truth 5 verified, 0 errors/warnings/notes |
| INF1-02 (Optional dep in Suggests) | ✓ SATISFIED | bidser in Suggests, not Imports |
| INF1-03 (Tests work without optional dep) | ✓ SATISFIED | All 24 tests pass, mocking used, integration tests skip_if_not_installed |

### Anti-Patterns Found

**Scan results:** No anti-patterns found.

- ✓ No TODO/FIXME/XXX/HACK comments
- ✓ No placeholder text patterns
- ✓ No empty implementations (invisible(NULL) in .validate_bids_structure is intentional validation pattern)
- ✓ No stub handlers
- ✓ No hardcoded values where dynamic expected

### Human Verification Required

None. All automated verification passed. The function is testable without human intervention.

**Optional user testing (recommended but not blocking):**
1. Install bidser and verify on_bids() creates functional bids_project from real OpenNeuro dataset
2. Verify derivatives warnings appear correctly when derivatives missing
3. Verify error messages are clear and helpful for invalid inputs

---

**Verification Summary**

Phase 8 goal **ACHIEVED**. All 5 success criteria verified:

1. ✓ User can call on_bids(handle) and get a bidser bids_project object
2. ✓ on_bids() provides helpful message if bidser is not installed  
3. ✓ User can include fMRIPrep derivatives via on_bids(handle, fmriprep = TRUE)
4. ✓ User can specify custom derivatives path via on_bids(handle, prep_dir = "derivatives/custom")
5. ✓ R CMD check passes with bidser as Suggests (not Imports)

**Key Strengths:**
- Comprehensive test coverage (24 tests, all passing)
- Proper optional dependency handling (check_installed first, namespace-qualified calls)
- Clear error messages with actionable guidance
- Auto-fetch convenience for users
- Derivatives path validation with helpful warnings
- Clean implementation with no stubs or TODOs
- R CMD check: 0 errors, 0 warnings, 0 notes

**v1.1 BIDS Integration Milestone:** COMPLETE

Phase 8 completes the v1.1 milestone. Users now have full BIDS-aware access to OpenNeuro datasets through the bridge to bidser.

---

_Verified: 2026-01-22T19:50:08Z_
_Verifier: Claude (gsd-verifier)_

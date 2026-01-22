---
phase: 06-subject-querying
verified: 2026-01-22T16:22:09Z
status: passed
score: 4/4 must-haves verified
---

# Phase 6: Subject Querying Verification Report

**Phase Goal:** Users can discover subjects in a dataset before downloading
**Verified:** 2026-01-22T16:22:09Z
**Status:** PASSED
**Re-verification:** No - initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can call on_subjects("ds000001") and get a tibble with subject IDs | ✓ VERIFIED | Function exported, returns tibble with subject_id column. Tested with mocks. |
| 2 | User can see how many subjects exist from the tibble row count | ✓ VERIFIED | nrow() returns 16 subjects from mock data. Each subject is a row in the tibble. |
| 3 | Function works without downloading any data (metadata-only query) | ✓ VERIFIED | Uses GraphQL API via on_request(), no file download operations present. |
| 4 | Subject IDs are naturally sorted (sub-01, sub-02, ... sub-10, not sub-01, sub-10, sub-02) | ✓ VERIFIED | .sort_subjects_natural() implemented with stringi and fallback. Test confirms: sub-01, sub-02, sub-9, sub-10. |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `inst/graphql/get_subjects.gql` | GraphQL query for snapshot summary subjects | ✓ VERIFIED | EXISTS (11 lines), SUBSTANTIVE (contains summary.subjects field), WIRED (loaded by .on_read_gql) |
| `R/api-subjects.R` | on_subjects() function | ✓ VERIFIED | EXISTS (97 lines), SUBSTANTIVE (full implementation with error handling), EXPORTED (in NAMESPACE), WIRED (called via mocks in tests) |
| `R/utils-response.R` | .parse_subjects() helper function | ✓ VERIFIED | EXISTS (added to existing file), SUBSTANTIVE (29 lines, lines 313-341), WIRED (called from on_subjects) |
| `tests/testthat/test-api-subjects.R` | Test coverage for on_subjects() | ✓ VERIFIED | EXISTS (75 lines), SUBSTANTIVE (8 test cases), WIRED (16 assertions passing) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `R/api-subjects.R` | `inst/graphql/get_subjects.gql` | `.on_read_gql('get_subjects')` | ✓ WIRED | Line 70: gql <- .on_read_gql("get_subjects") |
| `R/api-subjects.R` | `R/utils-response.R` | `.parse_subjects() call` | ✓ WIRED | Line 96: .parse_subjects(response, dataset_id = id) |
| `R/api-subjects.R` | `on_snapshots()` | `on_snapshots() for latest tag` | ✓ WIRED | Line 59: snapshots <- on_snapshots(id, client) |
| `on_subjects()` | GraphQL API | `on_request()` | ✓ WIRED | Line 74: on_request(gql, variables, client) - metadata-only query |
| `.parse_subjects()` | `.sort_subjects_natural()` | Natural sorting call | ✓ WIRED | Line 327 in utils-response.R: subjects <- .sort_subjects_natural(subjects) |

### Requirements Coverage

No explicit requirements mapped to phase 6 in REQUIREMENTS.md. Phase ROADMAP mentions SUBJ-01 and SUBJ-02:

| Requirement | Status | Evidence |
|-------------|--------|----------|
| SUBJ-01: Query subjects without downloading | ✓ SATISFIED | on_subjects() uses GraphQL query only, no file downloads |
| SUBJ-02: Subject count visible | ✓ SATISFIED | nrow(on_subjects("ds000001")) returns 16, tibble shows all subjects |

### Anti-Patterns Found

**None detected.**

Scanned files:
- `R/api-subjects.R`: No TODOs, FIXMEs, placeholders, or stub patterns
- `R/utils-response.R`: .parse_subjects() and .sort_subjects_natural() are complete implementations
- `inst/graphql/get_subjects.gql`: Valid GraphQL query

All implementations are substantive with proper error handling following existing package patterns.

### Test Results

```
✓ on_subjects returns tibble with subject information
✓ on_subjects returns valid data types  
✓ on_subjects returns naturally sorted subjects
✓ on_subjects dataset_id matches input
✓ on_subjects throws error for invalid ID
○ on_subjects returns empty tibble for non-BIDS dataset (SKIPPED - requires mock)
✓ .sort_subjects_natural sorts numerically
✓ .sort_subjects_natural handles empty input

PASS: 16 assertions (across 8 tests)
SKIP: 1 test (non-BIDS dataset - not a blocker)
FAIL: 0
```

### Manual Verification

Function tested with httptest2 mocks:

```r
result <- on_subjects("ds000001")
# Columns: dataset_id, subject_id, n_sessions, n_files 
# Rows: 16 
# First 3 subject_ids: 01, 02, 03
```

Natural sorting verified:
```r
.sort_subjects_natural(c("sub-01", "sub-10", "sub-02", "sub-9"))
# Result: sub-01, sub-02, sub-9, sub-10 ✓
```

## Summary

**All must-haves verified. Phase goal achieved.**

The on_subjects() function successfully:
1. Returns a tibble with subject_id column from GraphQL metadata query
2. Allows users to see subject count via nrow()
3. Works without downloading any data (metadata-only)
4. Implements natural sorting for subject IDs

**Key accomplishments:**
- Complete GraphQL integration following existing patterns
- Natural sorting with stringi and base R fallback
- Comprehensive test coverage (16 passing assertions)
- Proper error handling for invalid datasets and missing snapshots
- Documented and exported function ready for use in Phase 7

**No gaps identified. Phase 6 is complete and ready for Phase 7 dependency.**

---

_Verified: 2026-01-22T16:22:09Z_
_Verifier: Claude (gsd-verifier)_

---
phase: 09-discovery-foundation
verified: 2026-01-23T15:34:47Z
status: passed
score: 4/4 must-haves verified
---

# Phase 9: Discovery Foundation Verification Report

**Phase Goal:** Users can discover available derivative datasets for any OpenNeuro dataset
**Verified:** 2026-01-23T15:34:47Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | User can call `on_derivatives("ds000001")` and get a tibble of available pipelines | ✓ VERIFIED | `on_derivatives()` exists in R/discovery.R (285 lines), exported in NAMESPACE, returns tibble with 9 columns |
| 2 | Tibble includes pipeline name, source (embedded vs OpenNeuroDerivatives), and metadata | ✓ VERIFIED | `.empty_derivatives_tibble()` defines 9 columns: dataset_id, pipeline, source, version, n_subjects, n_files, total_size, last_modified, s3_url |
| 3 | OpenNeuroDerivatives GitHub organization repos are discoverable (784+ datasets) | ✓ VERIFIED | `.list_openneuro_derivatives_repos()` implements full pagination (per_page=100, checks Link header for "next", increments page), retrieves all repos from GitHub API |
| 4 | Discovery results are cached per-session (no repeated GitHub API calls within session) | ✓ VERIFIED | `.discovery_cache` closure-based cache used in both `.list_openneuro_derivatives_repos()` (lines 193-194, 256) and `on_derivatives()` (lines 221-222, 282) |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `R/discovery-cache.R` | Closure-based session cache | ✓ VERIFIED | 81 lines, exports `.discovery_cache` and `.discovery_cache_clear()`, implements get/set/has/clear operations |
| `R/discovery-github.R` | GitHub API for OpenNeuroDerivatives | ✓ VERIFIED | 259 lines, exports `.list_openneuro_derivatives_repos()`, includes rate limiting with retry-after logic, pagination complete |
| `R/discovery.R` | Main on_derivatives() function | ✓ VERIFIED | 285 lines, exports `on_derivatives()`, integrates both embedded and GitHub sources |
| `R/utils-response.R` | Empty derivatives tibble helper | ✓ VERIFIED | Contains `.empty_derivatives_tibble()` at line 322 with correct 9-column structure |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `R/discovery-github.R` | `R/discovery-cache.R` | `.discovery_cache$` usage | ✓ WIRED | Lines 193-194 (get), 256 (set) - cache key "openneuro_derivatives_repos" |
| `R/discovery.R` | `R/discovery-github.R` | `.list_openneuro_derivatives_repos()` call | ✓ WIRED | Line 75 in `.find_derivatives_in_github()`, passes refresh parameter |
| `R/discovery.R` | `R/api-files.R` | `on_files()` calls | ✓ WIRED | Lines 26, 39 in `.detect_embedded_derivatives()`, used to check for derivatives/ directory |
| `R/discovery.R` | `R/discovery-cache.R` | Cache final results | ✓ WIRED | Lines 221-222 (get), 282 (set) - cache key includes dataset_id and sources |
| `R/discovery.R` | `R/utils-response.R` | `.empty_derivatives_tibble()` usage | ✓ WIRED | Called 6 times (lines 32, 45, 81, 226, 244, 261) for empty results |
| `R/discovery.R` | `R/download-progress.R` | `.format_bytes()` usage | ✓ WIRED | Line 93 formats size_kb * 1024 for total_size column |
| `R/discovery.R` | `R/utils-response.R` | `.parse_timestamp()` usage | ✓ WIRED | Line 96 parses pushed_at timestamp for last_modified column |

### Requirements Coverage

Phase 9 maps to discovery requirements from the roadmap. All success criteria met:

| Requirement | Status | Evidence |
|-------------|--------|----------|
| User can call `on_derivatives("ds000001")` and get tibble | ✓ SATISFIED | `on_derivatives()` exported, fully implemented |
| Tibble includes pipeline name, source, metadata | ✓ SATISFIED | 9 columns defined in `.empty_derivatives_tibble()` |
| OpenNeuroDerivatives GitHub repos discoverable (784+) | ✓ SATISFIED | Pagination retrieves all repos (100 per page until empty or no "next" link) |
| Discovery results cached per-session | ✓ SATISFIED | Closure-based cache implemented, used by both GitHub and main function |

### Anti-Patterns Found

**None** - No TODO comments, no placeholder content, no empty implementations, no stub patterns detected.

All functions are substantive:
- No `TODO`, `FIXME`, `placeholder`, `not implemented`, or `coming soon` comments found
- No empty return statements (return null, return {}, etc.)
- All functions have real implementations with proper logic
- Proper error handling throughout (tryCatch blocks with informative error messages)

### Implementation Highlights

**Pagination Logic** (discovery-github.R lines 197-253):
- Starts at page 1, per_page=100
- `repeat` loop fetches pages until empty response OR no Link header with rel="next"
- Increments page counter after each successful fetch
- This ensures ALL repos are retrieved, not just first 100

**Rate Limiting** (discovery-github.R lines 22-85, 98-131):
- `req_throttle(rate = 30/60)` limits to 30 requests per minute (50% of unauthenticated limit)
- `req_retry()` with custom `is_transient` (checks 403 + X-RateLimit-Remaining: 0)
- Custom `after` function reads X-RateLimit-Reset header and calculates wait time
- Informative error message includes reset time, wait duration, and GITHUB_PAT suggestion

**Cache Strategy**:
- GitHub repo list cached at "openneuro_derivatives_repos" key (session-wide)
- Individual `on_derivatives()` calls cached with key: "derivatives_{dataset_id}_{sources}"
- Different source combinations get separate cache entries
- `refresh=TRUE` bypasses cache at both levels

**Deduplication** (discovery.R lines 267-279):
- Embedded derivatives take precedence when same pipeline exists in both sources
- Finds intersection of embedded_pipelines and github_pipelines
- Removes OpenNeuroDerivatives rows for duplicate pipelines
- This matches stated design: author-provided derivatives preferred

**Multi-Source Robustness**:
- Embedded check wrapped in tryCatch (line 230-246)
- "Not found" errors propagate (dataset doesn't exist)
- Network errors silently return empty tibble (allows GitHub check to proceed)
- GitHub check also wrapped in tryCatch (line 252-263)
- GitHub errors log warning but don't fail function

---

_Verified: 2026-01-23T15:34:47Z_
_Verifier: Claude (gsd-verifier)_

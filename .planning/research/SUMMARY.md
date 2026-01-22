# Research Summary: BIDS Integration Milestone

**Project:** openneuroR v1.1 - BIDS Integration
**Domain:** R API wrapper for neuroimaging data repository with BIDS awareness
**Researched:** 2026-01-22
**Confidence:** HIGH

## Executive Summary

This milestone adds subject-level filtering and bidser integration to openneuroR, enabling users to query subjects before download, selectively download subsets, and convert fetched datasets into bids_project objects for analysis. The implementation is straightforward: add bidser to Suggests (not Imports), implement on_subjects() via GraphQL query, extend on_download() with subject filtering, and create on_bids() as a bridge function. The approach follows CRAN-compliant optional dependency patterns using rlang::check_installed() guards.

The key architectural insight is that all three features operate at different layers without interfering with existing download backends. on_subjects() extends the GraphQL client layer, subject filtering happens at the handle/cache layer before backend dispatch, and on_bids() is a lightweight orchestrator that fetches then delegates to bidser. This clean separation means no changes to Layer B (download backends).

Critical risks center on CRAN compliance for optional dependencies: examples must wrap bidser calls in conditional checks, tests must use skip_if_not_installed(), and all bidser-using functions need requireNamespace() guards. The research confirms this is a low-risk, high-value milestone with standard patterns for optional dependencies.

## Key Findings

### Recommended Stack

**Single change: Add bidser to Suggests** - No new hard dependencies required. The existing openneuroR stack already includes all necessary infrastructure (rlang for checks, fs for filesystem, jsonlite for parsing, httr2/ghql for GraphQL queries). bidser remains optional because core download functionality works without BIDS awareness, it has a heavy dependency chain (neuroim2, data.tree), and it's GitHub-only (not CRAN), so Imports would block CRAN submission.

**Core technologies already present:**
- rlang - for check_installed() / is_installed() guards
- httr2 + ghql - GraphQL queries for on_subjects()
- fs + jsonlite - filesystem operations and JSON parsing
- bidser (Suggests only) - BIDS project object creation

**No version constraints on bidser** since it's at 0.0.0.9000 (development).

### Expected Features

**Must have (table stakes):**
- on_subjects(dataset_id) - List subject IDs pre-download via GraphQL query
- on_download(..., subjects=) - Filter download to specified subjects
- on_bids(handle) - Fetch dataset and return bidser bids_project object
- Graceful bidser absence - Informative errors when bidser not installed

**Defer to v1.2+ (out of scope):**
- on_tasks(), on_modalities(), on_sessions() - Additional metadata queries
- Task/session filtering in downloads - Adds complexity without critical value

**Anti-features to avoid:**
- BIDS validation (separate concern, use bids-validator)
- BIDS writing (out of scope, use bidser directly)
- Custom BIDS parsing (reinvents bidser)
- Embedded bidser (forces heavy dependency)

### Architecture Approach

The three new functions fit cleanly into existing layers without requiring changes to download backends. Layer A (GraphQL Client) gains on_subjects() for querying subject lists. Layer C (Cache + Handle) extends on_download() with subject filtering before backend dispatch and adds on_bids() as an orchestrator. Layer B (Download Backends) remains untouched because filtering happens upstream.

**Major components:**
1. **on_subjects()** (Layer A) - GraphQL query for summary.subjects field, returns character vector
2. **on_download() enhancement** (Layer C) - Regex filter files by sub-XX/ pattern, validates against on_subjects()
3. **on_bids()** (Layer C) - Orchestrates on_fetch() then calls bidser::bids_project(on_path(handle))

**Data flow:** User queries subjects with on_subjects(), filters download with subjects= parameter (validates against API), downloads subset, then optionally converts to bids_project with on_bids(). Each step is independent and optional.

### Critical Pitfalls

1. **Unconditional bidser use in examples** - Examples calling bidser functions without requireNamespace() checks fail R CMD check on systems without bidser. Prevention: Wrap in \dontrun{} or conditional checks.

2. **Missing requireNamespace() guards** - Functions using bidser fail cryptically when not installed. Prevention: Use rlang::check_installed("bidser", reason = "to create BIDS projects") at function start. Already have rlang in Imports.

3. **Tests assume bidser installed** - Tests fail during R CMD check when _R_CHECK_FORCE_SUGGESTS_=FALSE. Prevention: Use testthat::skip_if_not_installed("bidser") in all bidser-related tests.

4. **Using require() instead of requireNamespace()** - Pollutes namespace, triggers CRAN NOTEs. Prevention: Always use requireNamespace() + bidser::fun() calls.

## Implications for Roadmap

Based on research, suggested 3-phase structure with clear dependency chain:

### Phase 1: Subject Querying
**Rationale:** Independent GraphQL query with no downstream dependencies. Enables exploration before download.
**Delivers:** on_subjects(dataset_id) function returning character vector of subject IDs
**Implements:** GraphQL query extension (either new query or extend get_dataset.gql)
**Avoids:** No bidser dependency yet, keeps scope minimal
**Research flag:** Standard GraphQL pattern, skip research-phase

### Phase 2: Subject Filtering
**Rationale:** Depends on on_subjects() for validation. Provides core value proposition of selective downloads.
**Delivers:** on_download(..., subjects=) parameter with regex filtering
**Uses:** on_subjects() for validation, existing download infrastructure
**Implements:** Filter file list using ^sub-(01|02|03)/ pattern before backend dispatch
**Avoids:** Changes to Layer B backends (filtering happens upstream)
**Research flag:** Standard filtering pattern, skip research-phase

### Phase 3: BIDS Bridge
**Rationale:** Requires completed download (depends on Phase 2). Cleanest separation - bidser integration isolated in single function.
**Delivers:** on_bids(handle) function and bidser integration
**Uses:** bidser (Suggests), rlang::check_installed() pattern
**Implements:** Bridge function calling bidser::bids_project(on_path(handle))
**Avoids:** All optional dependency pitfalls via requireNamespace() guards
**Research flag:** Standard optional dependency pattern, skip research-phase

### Phase Ordering Rationale

- **Dependencies naturally sequence:** on_subjects() -> subject filtering -> on_bids()
- **Incremental value delivery:** Each phase ships independently useful functionality
- **Risk isolation:** bidser integration deferred to final phase, doesn't block core features
- **Testing simplicity:** Each phase has clear inputs/outputs for testing

### Research Flags

**All phases use standard patterns (skip research-phase):**
- Phase 1: GraphQL query extension follows existing on_dataset() pattern
- Phase 2: File filtering is straightforward regex application
- Phase 3: Optional dependency pattern well-documented in R Packages (2e)

**No phases need deeper research** - All patterns have established implementations and clear documentation.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Single Suggests addition, all infrastructure present |
| Features | HIGH | Verified via bidser docs, OpenNeuro API schema, openneuro-py patterns |
| Architecture | HIGH | Clean layer separation, no backend changes needed |
| Pitfalls | HIGH | CRAN optional dependency patterns well-documented |

**Overall confidence:** HIGH

### Gaps to Address

**Minor validation needed:**
- Confirm GraphQL query field name (summary.subjects vs snapshot.summary.subjects) during Phase 1 implementation
- Test regex filter pattern against real OpenNeuro file structures during Phase 2

**No significant research gaps** - Implementation can proceed directly to coding.

## Sources

### Primary (HIGH confidence)
- R Packages (2e) - Dependencies in Practice chapter
- CRAN Repository Policy - Optional dependency requirements
- httr2 documentation - GraphQL patterns
- bidser documentation - bids_project() usage
- OpenNeuro API docs - GraphQL schema validation
- testthat documentation - skip_if_not_installed() pattern

### Secondary (MEDIUM confidence)
- openneuro-py - Subject filtering patterns
- rlang documentation - check_installed() usage

---
*Research completed: 2026-01-22*
*Ready for roadmap: yes*

# Project Research Summary

**Project:** openneuroR v1.2 — fMRIPrep Derivative Discovery
**Domain:** Neuroimaging data access API (R package extension)
**Researched:** 2026-01-23
**Confidence:** HIGH

## Executive Summary

OpenNeuro derivative discovery extends an existing R package for neuroimaging data access. The v1.2 milestone adds the ability to discover and download fMRIPrep preprocessed outputs via `on_derivatives()` and `on_download_derivatives()` functions. Research reveals that derivatives live in a **separate ecosystem** from raw data—the OpenNeuroDerivatives GitHub organization with 784+ datasets, accessed via different S3 buckets and paths.

The recommended approach leverages the existing httr2/processx stack with **zero new CRAN dependencies**. Critical finding: derivatives are NOT exposed via OpenNeuro's GraphQL API, requiring GitHub API integration for discovery and S3 backend enhancement for downloads. The architecture follows BIDS conventions by nesting derivatives under `{dataset}/derivatives/{pipeline}/` to maintain bidser compatibility.

Key risks center on fragmentation: derivatives exist in multiple locations (embedded in raw datasets, OpenNeuroDerivatives GitHub, separate S3 buckets), fMRIPrep versions have incompatible output structures, and subject filtering patterns differ from raw data. Mitigation requires dual discovery (API + GitHub), version-aware filename parsing, and clear separation between "contributor derivatives" (uploaded by dataset authors) and "OpenNeuroDerivatives" (standardized fMRIPrep processing).

## Key Findings

### Recommended Stack

The existing openneuroR stack fully supports derivative discovery without new dependencies. The 2025 R ecosystem for API wrappers is mature and stable, centered on httr2 (HTTP/GraphQL), processx (CLI tools), and r-lib infrastructure (cli, rlang, fs, withr).

**Core technologies (already in package):**
- **httr2** >= 1.2.1: HTTP requests with rate limiting, retries, parallel downloads — handles both OpenNeuro GraphQL AND GitHub API for derivative discovery
- **processx** >= 3.8.0: External process execution — extends existing DataLad/AWS CLI integration to new S3 derivative buckets
- **fs** >= 1.6.6: File system operations — cache path management for derivatives subdirectories
- **jsonlite** >= 1.8.9: JSON parsing — handles GitHub API responses and derivative metadata
- **cli** >= 3.6.0: User feedback — progress bars for derivative downloads

**Explicitly NOT adding:**
- **gh** package: Rejected because GitHub API pagination is straightforward with httr2; gh adds 3 transitive dependencies for marginal benefit
- **paws.storage**: AWS CLI via processx is already working; S3 SDK adds complexity without benefit for public buckets

**Cache architecture enhancement:** Derivatives nest under dataset root (`{dataset}/derivatives/{pipeline}/`) to maintain BIDS structure and bidser compatibility. Separate manifest tracking for derivatives prevents cache size explosion.

### Expected Features

Research identified clear tiers of features based on neuroimaging community expectations and fMRIPrep output structure.

**Must have (table stakes):**
- List available derivatives for dataset — users need discovery before download
- List derivative pipelines (fMRIPrep, MRIQC, etc.) — different pipelines produce different outputs
- Download specific derivative pipeline — users want fMRIPrep, not everything
- Subject filtering for derivatives — primary use case: "I want sub-01's preprocessed BOLD"
- Space filtering (MNI152NLin2009cAsym, T1w, fsaverage) — fMRIPrep outputs in multiple spaces
- Confounds file access — every fMRIPrep analysis needs confounds TSV
- Preprocessed BOLD access — core output users need
- Consistent API pattern with existing `on_files()`/`on_download()` — users expect familiar interface

**Should have (competitive advantage):**
- Automatic derivative type detection via `dataset_description.json`
- bidser integration for derivatives — return tibble compatible with downstream analysis
- Output type filtering (anat vs func) — users often need only functional derivatives
- OpenNeuroDerivatives discovery — access to 784+ pre-computed fMRIPrep datasets
- Task/run filtering — download specific task derivatives only
- Smart caching for derivatives — large files need aggressive caching
- Derivative size estimation — warn users before downloading 50GB

**Defer (v2+):**
- Automatic space selection — MNI variants cause confusion, require explicit parameter
- Full derivative processing pipelines — massive scope creep; fMRIPrep is separate tool
- Automatic confound selection — hotly debated in literature, no consensus
- FreeSurfer recon-all optimization — niche use case, different structure
- Cross-dataset derivative aggregation — unclear use case, storage explosion

**Critical anti-feature:** Unified derivatives API across OpenNeuro + OpenNeuroDerivatives. These have very different access patterns (GraphQL vs GitHub API vs S3); attempting to unify them creates a leaky abstraction. Separate function families are cleaner.

### Architecture Approach

Derivatives integrate via extension, not replacement. The existing four-layer architecture (GraphQL API → Download Backends → Cache/Handle → User API) accommodates derivatives through targeted enhancements at each layer.

**Major components:**
1. **Discovery Layer (NEW)** — `.discover_derivatives()` queries GitHub API for OpenNeuroDerivatives repos; `on_derivatives()` returns tibble of available pipelines with metadata
2. **S3 Backend Enhancement** — Parameterize `.download_s3()` with `bucket` and `prefix` to support `s3://openneuro-derivatives/fmriprep/{dataset}-fmriprep/`
3. **Cache Path Extension** — Derivatives nest under `{dataset}/derivatives/{pipeline}/` matching BIDS structure for bidser compatibility
4. **User API Addition** — `on_download_derivatives()` provides derivative-specific download with pipeline/space/subject filtering

**Integration points:**
- GitHub API discovery first, S3 fallback — GitHub is reliable, S3 bucket has had access issues
- Dual cache manifests — separate tracking for raw data vs derivatives prevents confusion
- Version-aware filename parsing — fMRIPrep 20.x, 21.x, 23.x have incompatible naming (confounds.tsv → confounds_regressors.tsv → timeseries.tsv)

**Build order based on dependencies:**
1. Discovery layer (`.discover_derivatives()` + `on_derivatives()`)
2. S3 backend enhancement (parameterize bucket/prefix)
3. Download integration (`on_download_derivatives()` + cache paths)
4. bidser bridge enhancement (auto-download option)

### Critical Pitfalls

Research identified 8 critical pitfalls specific to derivative discovery, beyond general R package development pitfalls.

1. **Assuming derivatives use same API/bucket as raw data** — OpenNeuro GraphQL API does NOT expose derivatives. They live in separate buckets (`s3://openneuro-derivatives/`) with different access patterns. **Prevention:** Implement GitHub API discovery; document bucket differences; handle access denied gracefully.

2. **Ignoring OpenNeuroDerivatives GitHub organization** — 784+ derivative datasets exist on GitHub that won't be found via OpenNeuro API. **Prevention:** Dual discovery (OpenNeuro API + GitHub API); provide `source` attribute in results.

3. **fMRIPrep version incompatibility** — Confounds file naming, tissue probability naming, per-session processing changed across versions. **Prevention:** Parse `dataset_description.json` → `GeneratedBy.Version`; implement version-aware filename patterns; test with 20.x, 21.x, 23.x derivatives.

4. **Treating embedded derivatives as equivalent to OpenNeuroDerivatives** — Contributors can upload non-standard derivatives to `derivatives/` folder; OpenNeuroDerivatives are standardized. **Prevention:** Separate code paths with `source` parameter; validate `DatasetType: "derivative"`; handle non-compliant derivatives gracefully.

5. **Subject filtering fails for derivatives** — Derivative paths (`derivatives/fmriprep/sub-XX/`) differ from raw paths (`sub-XX/`); existing filter logic doesn't account for this. **Prevention:** Update `._filter_files_by_subjects()` to handle derivative path patterns.

6. **Derivative file sizes not handled** — Preprocessed derivatives are 10-100x larger than raw data; existing timeouts/disk space checks fail. **Prevention:** Warn before download; increase timeouts 2-4x; implement disk space check.

7. **Failed processing subjects not handled** — Some subjects fail fMRIPrep; code assumes all subjects have complete derivatives. **Prevention:** Parse logs/HTML reports; expose status metadata; warn about failed subjects.

8. **Breaking existing API when adding derivatives** — Modifications to `on_files()`, `on_download()` could break non-derivative users. **Prevention:** Add NEW functions; keep existing functions unchanged; use opt-in parameters if extending existing functions.

## Implications for Roadmap

Based on research, the v1.2 milestone should be structured in 3 phases with clear dependencies.

### Phase 1: Derivative Discovery Foundation
**Rationale:** Discovery must exist before download can check availability. GitHub API integration is foundational because OpenNeuro GraphQL doesn't expose derivatives.

**Delivers:**
- `on_derivatives(id, pipeline)` function returning tibble of available derivative datasets
- `.discover_derivatives()` internal function for GitHub API queries
- Session-level discovery cache to avoid rate limits

**Addresses features:**
- List available derivatives for dataset (table stakes)
- List derivative pipelines (table stakes)
- OpenNeuroDerivatives discovery (competitive advantage)

**Avoids pitfalls:**
- Ignoring OpenNeuroDerivatives GitHub organization
- Assuming derivatives use same API as raw data
- GitHub API rate limits (via caching)

**Uses stack:**
- httr2 for GitHub API (`api.github.com/orgs/OpenNeuroDerivatives/repos`)
- tibble for result formatting
- cli for user messages

**Research flag:** SKIP RESEARCH — GitHub API is well-documented, patterns are standard

### Phase 2: S3 Backend and Subject Filtering
**Rationale:** S3 backend enhancement needed before download can fetch derivatives. Subject filtering must handle derivative path patterns before users can selectively download.

**Delivers:**
- Enhanced `.download_s3()` with parameterized bucket/prefix
- Updated subject filtering for derivative paths (`derivatives/{pipeline}/sub-XX/`)
- Derivative cache path structure (`{dataset}/derivatives/{pipeline}/`)

**Addresses features:**
- Subject filtering for derivatives (table stakes)
- Consistent API pattern (table stakes)

**Avoids pitfalls:**
- Wrong bucket assumptions (separate openneuro-derivatives bucket)
- Subject filtering fails for derivatives (different path patterns)
- Breaking existing API (parameterize, don't replace)

**Uses stack:**
- processx for AWS CLI with new bucket paths
- fs for derivative cache directory creation

**Research flag:** SKIP RESEARCH — S3 patterns already understood from raw data implementation

### Phase 3: Download Integration and Filtering
**Rationale:** Download function depends on discovery (Phase 1) and S3 backend (Phase 2). Advanced filtering (space, pipeline, output type) requires parsing derivative file structures.

**Delivers:**
- `on_download_derivatives(id, pipeline, subjects, space)` function
- Version-aware filename parsing for fMRIPrep outputs
- Derivative size estimation and warnings
- Space filtering (MNI152NLin2009cAsym, T1w, etc.)
- Pipeline filtering (fMRIPrep vs MRIQC)

**Addresses features:**
- Download specific derivative pipeline (table stakes)
- Space filtering (table stakes)
- Confounds file access (table stakes via filtering)
- Preprocessed BOLD access (table stakes via filtering)
- Output type filtering (competitive advantage)
- Derivative size estimation (competitive advantage)

**Avoids pitfalls:**
- fMRIPrep version incompatibility (version-aware patterns)
- Derivative file sizes not handled (size warnings, disk checks)
- Failed processing subjects (parse status, warn users)

**Uses stack:**
- jsonlite to parse `dataset_description.json` for version
- rlang for structured errors
- cli for progress bars and size warnings

**Research flag:** NEEDS RESEARCH — Complex BIDS derivative filename parsing; consider if bidser can handle this or if custom parsing is needed

### Phase Ordering Rationale

- **Discovery before download:** Cannot download without knowing where derivatives exist and which source (GitHub, S3 embedded, S3 derivatives bucket)
- **Backend before user API:** S3 backend enhancement is infrastructure; user-facing download function depends on working backend
- **Filtering last:** Advanced filtering (space, version-aware parsing) requires understanding of derivative file structures; can be iterative based on real dataset testing

**Dependencies discovered:**
- GitHub API discovery → S3 backend → download function (linear dependency chain)
- Subject filtering bridges Phase 2 and Phase 3 (needed for download, refined with advanced filters)
- Version parsing in Phase 3 informs filename patterns, may require iteration

**Architectural patterns enforced:**
- Extend existing layers, don't create parallel systems
- Maintain BIDS structure in cache for bidser compatibility
- Separate code paths for different derivative sources (embedded vs OpenNeuroDerivatives)

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 3:** BIDS derivative filename parsing — Complex entity extraction (`space-`, `desc-`, `res-`); may need bidser integration research or custom regex patterns; test with representative fMRIPrep output filenames from multiple versions

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** GitHub API is well-documented; httr2 patterns are established
- **Phase 2:** S3 backend follows existing patterns from raw data downloads; subject filtering is extension of existing logic

**Validation checkpoints:**
- After Phase 1: Verify discovery finds derivatives for known datasets (ds000001, ds002422)
- After Phase 2: Verify subject filtering works with derivative paths
- After Phase 3: Test with fMRIPrep 20.x, 21.x, 23.x derivatives to confirm version handling

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified on CRAN; httr2 1.2.1, processx 3.8.0+; zero new dependencies required; rejected alternatives documented with rationale |
| Features | MEDIUM | OpenNeuro derivatives ecosystem is evolving; some access patterns verified, others based on community sources; table stakes vs competitive features clearly delineated |
| Architecture | HIGH | Integration points verified against existing codebase; BIDS structure well-documented; bidser compatibility confirmed; build order based on clear dependencies |
| Pitfalls | HIGH | fMRIPrep version issues documented in changelog; GitHub organization structure verified; S3 bucket access issues confirmed via Neurostars; subject filtering patterns tested |

**Overall confidence:** HIGH

### Gaps to Address

Research was thorough but identified areas needing validation during implementation:

- **BIDS derivative filename parsing complexity:** Research identified entities (`space-`, `desc-`, `res-`) but actual regex patterns need testing with real fMRIPrep outputs; may discover edge cases with multi-space, multi-resolution outputs. **Handle during Phase 3 planning:** Pull representative filenames from OpenNeuroDerivatives repos; test parsing patterns; consider bidser integration if available.

- **OpenNeuroDerivatives bucket access reliability:** Neurostars discussion indicates `s3://openneuro-derivatives/` bucket has had ListObjectsV2 access issues; unclear if resolved. **Handle during Phase 2:** Test with AWS CLI; implement fallback to embedded derivatives path (`s3://openneuro/{dataset}/derivatives/`); document which access method worked for which datasets.

- **fMRIPrep version detection edge cases:** Research identified major version breaks but unclear if sub-versions have additional incompatibilities. **Handle during Phase 3:** Parse `GeneratedBy.Version` and test with granular versions (20.0.5, 20.1.1, 21.0.0, 23.1.4); document which patterns correspond to which version ranges.

- **Embedded derivatives quality/completeness:** "Contributor derivatives" in `derivatives/` folder within raw datasets may not follow BIDS Derivatives spec; unclear how common this is. **Handle during Phase 1-2:** Validate `dataset_description.json` presence; check for `DatasetType: "derivative"`; provide clear warnings when derivatives are non-compliant; document which datasets have compliant vs non-compliant embedded derivatives.

## Sources

### Primary (HIGH confidence)
- [CRAN httr2](https://cran.r-project.org/package=httr2) — Version 1.2.1 verified; GitHub API pagination patterns
- [CRAN processx](https://processx.r-lib.org/) — Version 3.8.0+ for subprocess execution
- [OpenNeuroDerivatives GitHub](https://github.com/OpenNeuroDerivatives) — 784+ repos verified; naming conventions documented
- [OpenNeuro API Documentation](https://docs.openneuro.org/api.html) — GraphQL schema verified; derivatives NOT exposed
- [fMRIPrep Outputs Documentation](https://fmriprep.org/en/stable/outputs.html) — File structure, naming conventions, output spaces
- [fMRIPrep Changelog](https://fmriprep.org/en/stable/changes.html) — Version-specific breaking changes documented
- [BIDS Derivatives Specification](https://bids-specification.readthedocs.io/en/stable/derivatives/introduction.html) — Folder conventions, entity definitions
- [bidser GitHub](https://github.com/bbuchsbaum/bidser) — BIDS project integration patterns

### Secondary (MEDIUM confidence)
- [Neurostars: OpenNeuro derivatives bucket](https://neurostars.org/t/openneuro-derivatives-bucket/26531) — S3 bucket access issues documented by community
- [Neurostars: derivatives tab vs folder](https://neurostars.org/t/derivatives-tab-on-openneuro-vs-derivatives-folder-in-files-tab/26112) — Embedded vs OpenNeuroDerivatives distinction
- [GitHub API repos endpoint](https://docs.github.com/en/rest/repos/repos) — Organization repo listing patterns
- [httr2 Wrapping APIs Vignette](https://httr2.r-lib.org/articles/wrapping-apis.html) — Request patterns, pagination
- [HTTP Testing in R Book](https://books.ropensci.org/http-testing/) — vcr/webmockr patterns for testing

### Tertiary (LOW confidence)
- [BIDS Derivatives folder discussion](https://groups.google.com/g/bids-discussion/c/0Go9T17Z3l0) — Community patterns, needs validation

### Codebase Verification
- `/Users/bbuchsbaum/code/openneuroR/R/backend-s3.R` — Existing S3 patterns verified
- `/Users/bbuchsbaum/code/openneuroR/R/backend-datalad.R` — Existing DataLad patterns verified
- `/Users/bbuchsbaum/code/openneuroR/DESCRIPTION` — Current dependencies confirmed (httr2, processx, fs, etc.)

---
*Research completed: 2026-01-23*
*Ready for roadmap: yes*

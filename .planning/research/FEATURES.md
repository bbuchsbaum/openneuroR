# Feature Research: fMRIPrep Derivative Discovery

**Domain:** Neuroimaging derivative access API (R package extension)
**Researched:** 2026-01-22
**Confidence:** MEDIUM (OpenNeuro derivatives ecosystem is evolving; some access patterns verified, others based on community patterns)

---

## Executive Summary

OpenNeuro derivatives (primarily fMRIPrep outputs) exist in two distinct ecosystems:
1. **In-dataset derivatives** - Stored in `derivatives/` folder within OpenNeuro datasets, accessible via existing GraphQL API
2. **OpenNeuroDerivatives** - Separate GitHub organization with 784+ pre-computed derivative datasets, accessible via S3 or DataLad

The existing `on_files()` and `on_download()` patterns provide a solid foundation. Derivative discovery should extend these patterns rather than create parallel APIs.

---

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| List available derivatives for dataset | Users need to know what's available before downloading | LOW | `on_files()` | Use existing tree traversal, filter for `derivatives/` directory |
| List derivative pipelines (fMRIPrep, MRIQC, etc.) | Different pipelines produce different outputs | LOW | List derivatives | Parse directory structure under `derivatives/` |
| Download specific derivative pipeline | Users want fMRIPrep, not MRIQC | MEDIUM | `on_download()` | Extend existing subject filtering to derivative paths |
| Subject filtering for derivatives | Primary use case: "I want sub-01's preprocessed BOLD" | MEDIUM | Subject filter | Existing `subjects=` parameter pattern |
| Space filtering (MNI, T1w, fsaverage) | fMRIPrep outputs in multiple spaces; users need one | MEDIUM | List derivatives | Parse BIDS `space-` entity from filenames |
| Confounds file access | Every fMRIPrep analysis needs confounds TSV | LOW | Download derivatives | `*_desc-confounds_timeseries.tsv` pattern |
| Preprocessed BOLD access | Core output users need | LOW | Download derivatives | `*_desc-preproc_bold.nii.gz` pattern |
| Consistent API pattern with on_files/on_download | Users expect familiar interface | LOW | Existing API | Follow `on_` prefix, tibble returns, same parameter names |

### Differentiators (Competitive Advantage)

Features that set the product apart from manual download or Python alternatives.

| Feature | Value Proposition | Complexity | Depends On | Notes |
|---------|-------------------|------------|------------|-------|
| Automatic derivative type detection | Parse `dataset_description.json` to identify pipeline version | MEDIUM | List derivatives | fMRIPrep vs MRIQC vs FreeSurfer detection |
| bidser integration for derivatives | Return tibble compatible with bidser for downstream analysis | MEDIUM | Download | Existing `on_bids()` pattern extends naturally |
| Output type filtering (anat vs func) | Users often need only functional derivatives | MEDIUM | List derivatives | Filter by `anat/` or `func/` subdirectories |
| OpenNeuroDerivatives discovery | Access to 784+ pre-computed fMRIPrep datasets | HIGH | New API | Requires S3 or DataLad backend, different access pattern |
| Task filtering | Download derivatives for specific task only | MEDIUM | Subject filter | Parse BIDS `task-` entity |
| Run filtering | Download specific runs only | LOW | Task filter | Parse BIDS `run-` entity |
| QA report access | fMRIPrep HTML reports for visual inspection | LOW | Download | `*.html` files in subject directories |
| Smart caching for derivatives | Derivatives are large; cache aggressively | MEDIUM | Cache system | Extend existing `on_cache_*()` pattern |
| Derivative size estimation | Warn users before downloading 50GB of data | LOW | List derivatives | Sum file sizes from API response |
| Surface file handling (GIFTI, CIFTI) | Many analyses need cortical surface data | LOW | Download | No special handling needed, just include in patterns |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create complexity, maintenance burden, or user confusion.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Automatic space selection | "Just give me the standard space" | MNI152NLin2009cAsym vs MNI152NLin6Asym vs fsLR vs fsaverage causes confusion | Require explicit `space=` parameter; list available spaces |
| Full derivative processing pipelines | "Run fMRIPrep for me" | Massive scope creep; fMRIPrep is a separate tool with complex dependencies | Focus on access, not processing |
| Automatic confound selection | "Pick the right confounds for me" | Hotly debated in literature; no consensus | Download confounds TSV, let user/downstream tool select columns |
| Unified derivatives API across OpenNeuro + OpenNeuroDerivatives | "One function for all derivatives" | Very different access patterns (GraphQL vs S3); unified API would be leaky abstraction | Separate `on_derivatives()` (in-dataset) vs `ond_*()` (OpenNeuroDerivatives) |
| FreeSurfer recon-all output support | "I need the FreeSurfer files too" | Different structure, huge files, niche use case | Support if present in `derivatives/freesurfer/`, but don't optimize for it |
| Derivative validation | "Verify my derivatives are complete" | BIDS Derivatives spec is complex; validator exists separately | Document how to use bids-validator, don't reimplement |
| Cross-dataset derivative aggregation | "Give me all fMRIPrep outputs for datasets matching X" | Massive downloads, unclear use case, storage explosion | Focus on single-dataset access; users can loop |

---

## Feature Dependencies

```
on_derivatives() [List derivatives in dataset]
    |
    +---> uses on_files() [Existing file listing]
    |         |
    |         +---> tree traversal for derivatives/ subdirectory
    |
    +---> on_derivative_pipelines() [List fMRIPrep, MRIQC, etc.]
              |
              +---> parses directory names under derivatives/

on_download_derivatives() [Download derivative files]
    |
    +---> uses on_download() [Existing download infrastructure]
    |         |
    |         +---> subjects= parameter (already exists)
    |         +---> files= regex parameter (already exists)
    |
    +---> requires on_derivatives() [Know what's available]
    |
    +---> NEW: space= parameter for BIDS space filtering
    |
    +---> NEW: pipeline= parameter to select fMRIPrep vs MRIQC

on_bids() [bidser integration]
    |
    +---> works with derivatives after download
    |
    +---> bidser has partial fMRIPrep support (extends naturally)

OpenNeuroDerivatives (ond_*) [FUTURE - separate access pattern]
    |
    +---> ond_search() - list available derivative datasets
    |
    +---> ond_download() - download from S3/DataLad
    |
    +---> DIFFERENT BACKEND - not GraphQL
```

### Dependency Notes

- **on_download_derivatives() requires on_derivatives():** Must list available derivatives before downloading
- **Space filtering requires derivative listing:** Need to parse available spaces from filenames
- **bidser integration enhances derivatives:** After download, bidser can query the local structure
- **OpenNeuroDerivatives conflicts with unified API:** Different access patterns mean separate function families are cleaner than one leaky abstraction

---

## MVP Definition

### Launch With (v1) - Minimal Viable Derivative Access

Minimum viable product - what's needed to validate the concept.

- [ ] `on_derivatives(id, tag)` - List derivatives/ directory contents (tibble with filename, size, key)
- [ ] `on_derivative_pipelines(id, tag)` - List pipeline names (fmriprep-23.1.4, mriqc-23.0.0, etc.)
- [ ] `on_download(id, files="derivatives/.*", subjects=)` - Download derivatives using existing regex
- [ ] Documentation showing derivative download workflow

**Rationale:** Users can already download derivatives with `on_download(id, files="derivatives/fmriprep/.*")`. MVP formalizes discovery, not download.

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] `on_download_derivatives(id, pipeline=, subjects=, space=)` - Convenience wrapper with derivative-specific filtering
- [ ] Space enumeration - `on_derivative_spaces(id, pipeline)` returns available output spaces
- [ ] Output type filtering - `output_type = c("anat", "func")` parameter
- [ ] Size estimation - `on_derivative_size(id, pipeline, subjects)` before download

**Trigger:** User feedback requesting cleaner derivative-specific interface

### Future Consideration (v2+)

Features to defer until pattern is validated.

- [ ] OpenNeuroDerivatives integration (`ond_*` function family)
- [ ] Pre-computed derivative search across all OpenNeuro datasets
- [ ] Confounds column extraction utilities
- [ ] Task/run filtering parameters

**Why defer:**
- OpenNeuroDerivatives is separate ecosystem with different access pattern
- Confounds extraction is analysis, not access
- Task/run filtering can use existing regex for now

---

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| `on_derivatives()` list | HIGH | LOW | P1 |
| `on_derivative_pipelines()` | HIGH | LOW | P1 |
| Subject filtering for derivatives | HIGH | LOW (exists) | P1 |
| Space filtering | MEDIUM | MEDIUM | P2 |
| `on_download_derivatives()` convenience | MEDIUM | MEDIUM | P2 |
| Output type filtering | MEDIUM | LOW | P2 |
| Size estimation | LOW | LOW | P2 |
| OpenNeuroDerivatives access | MEDIUM | HIGH | P3 |
| Confounds utilities | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch - enables basic derivative workflow
- P2: Should have - improves ergonomics for common cases
- P3: Nice to have - address after P1/P2 validated

---

## Competitor Feature Analysis

| Feature | openneuro-py (Python) | DataLad | Our Approach |
|---------|----------------------|---------|--------------|
| Derivative listing | --include/--exclude patterns | git-annex whereis | `on_derivatives()` tibble |
| Subject filtering | --include sub-01 pattern | get specific paths | `subjects=` parameter (existing) |
| Space filtering | Not explicit | Manual path selection | `space=` parameter (new) |
| OpenNeuroDerivatives | Not supported | Native DataLad access | Future ond_* family |
| BIDS integration | Via PyBIDS | Via datalad-bids | Via bidser |
| Essential files | Always downloads BIDS root | Selective get | Root files included by default |

**Our advantages:**
- R-native (no Python dependency)
- Consistent with existing on_* API
- bidser integration for downstream analysis
- Tibble returns for tidyverse compatibility

---

## User Workflow Examples

### Workflow 1: Download fMRIPrep BOLD for specific subjects

```r
# Discover what's available
derivs <- on_derivatives("ds000001")
pipelines <- on_derivative_pipelines("ds000001")
# Returns: "fmriprep-23.1.4", "mriqc-23.0.0"

# Download for specific subjects
on_download("ds000001",
  files = "derivatives/fmriprep.*",  # Regex
  subjects = c("sub-01", "sub-02")
)

# Or with convenience wrapper (v1.x)
on_download_derivatives("ds000001",
  pipeline = "fmriprep",
  subjects = c("sub-01", "sub-02"),
  space = "MNI152NLin2009cAsym"
)
```

### Workflow 2: Get confounds for analysis

```r
# Download confounds only (small files)
on_download("ds000001",
  files = "derivatives/fmriprep.*confounds.*\\.tsv$",
  subjects = c("sub-01", "sub-02")
)

# Read with bidser or data.table
library(bidser)
bids <- bids_project(on_path(handle))
confounds <- bids$derivatives$fmriprep$confounds
```

### Workflow 3: Explore available outputs

```r
# List all derivative files for a subject
derivs <- on_derivatives("ds000001", pipeline = "fmriprep")
sub01_files <- derivs[grepl("sub-01", derivs$filename), ]

# Check available spaces
spaces <- unique(stringr::str_extract(sub01_files$filename, "space-[^_]+"))
# Returns: "space-MNI152NLin2009cAsym", "space-T1w", "space-fsaverage"
```

---

## fMRIPrep Output Structure Reference

Key files users typically need (from fMRIPrep documentation):

### Functional Derivatives (`func/` folder)
- `*_desc-preproc_bold.nii.gz` - Preprocessed BOLD time series
- `*_desc-brain_mask.nii.gz` - Brain mask in output space
- `*_desc-confounds_timeseries.tsv` - Motion, physiological, and noise regressors
- `*_boldref.nii.gz` - Reference image for registration

### Anatomical Derivatives (`anat/` folder)
- `*_desc-preproc_T1w.nii.gz` - Preprocessed T1w image
- `*_desc-brain_mask.nii.gz` - Brain mask
- `*_dseg.nii.gz` - Tissue segmentation
- Transform files (`.h5`) - Native to standard space mappings

### Output Spaces (common)
- `space-MNI152NLin2009cAsym` - Default standard space
- `space-MNI152NLin6Asym` - Alternative MNI template
- `space-T1w` - Native anatomical space
- `space-fsaverage` - FreeSurfer surface space

### Confound Variables (selection from TSV)
- Motion: `trans_x`, `trans_y`, `trans_z`, `rot_x`, `rot_y`, `rot_z`
- Noise: `csf`, `white_matter`, `global_signal`
- Outliers: `framewise_displacement`, `dvars`, `motion_outlier*`
- CompCor: `a_comp_cor_*`, `t_comp_cor_*`

---

## Sources

### Official Documentation (HIGH confidence)
- [BIDS Derivatives Specification](https://bids-specification.readthedocs.io/en/stable/derivatives/introduction.html)
- [fMRIPrep Outputs Documentation](https://fmriprep.org/en/stable/outputs.html)
- [OpenNeuro API Documentation](https://docs.openneuro.org/api.html)

### OpenNeuro Ecosystem (MEDIUM confidence)
- [OpenNeuroDerivatives GitHub Organization](https://github.com/OpenNeuroDerivatives) - 784+ derivative datasets
- [OpenNeuro S3 Registry](https://registry.opendata.aws/openneuro/) - S3 bucket: openneuro.org
- [openneuro-py Python client](https://github.com/hoechenberger/openneuro-py) - include/exclude patterns

### Community Patterns (LOW confidence - needs validation)
- [BIDS Derivatives folder discussion](https://groups.google.com/g/bids-discussion/c/0Go9T17Z3l0)
- [OpenNeuro derivatives tab vs files tab](https://neurostars.org/t/derivatives-tab-on-openneuro-vs-derivatives-folder-in-files-tab/26112)
- [OpenNeuro derivatives bucket access issues](https://neurostars.org/t/openneuro-derivatives-bucket/26531) - s3://openneuro-derivatives has access restrictions

### R Ecosystem (HIGH confidence)
- [bidser package](https://github.com/bbuchsbaum/bidser) - Some fMRIPrep derivative support exists
- Existing openneuroR patterns: `on_files()`, `on_download()`, `on_subjects()`

---
*Feature research for: fMRIPrep derivative discovery*
*Researched: 2026-01-22*

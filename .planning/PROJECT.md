# openneuro

## What This Is

An R package for programmatic access to OpenNeuro — the largest open repository of neuroimaging data. Provides search, metadata queries, and multi-backend downloading with smart caching. Designed to be the best way to access OpenNeuro from any language, beating Python alternatives in API ergonomics, download reliability, and cache intelligence.

## Core Value

Researchers can find, download, and cache OpenNeuro datasets with a single pipeline-friendly API that just works — no manual CLI commands, no re-downloads, no backend headaches.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Search datasets by text query, returning tidy tibbles
- [ ] Query dataset metadata (name, created, updated, public status)
- [ ] List snapshots for a dataset with tags and timestamps
- [ ] List files within a snapshot (filename, size, annexed status)
- [ ] Create lazy handles to dataset snapshots
- [ ] Fetch data with automatic backend selection (DataLad → S3 → HTTPS)
- [ ] Cache downloads locally with manifest tracking
- [ ] Support DataLad/git-annex backend for correctness + partial retrieval
- [ ] Support S3 backend for bulk speed (anonymous, --no-sign-request)
- [ ] Support HTTPS backend as universal fallback
- [ ] Resolve URLs from GraphQL schema before probing (metadata-first)
- [ ] Return local filesystem path for fetched datasets

### Out of Scope

- OAuth/social login — API key + bearer token sufficient for v1
- Upload/write operations — read-only access for v1
- BIDS validation — separate concern, can compose with other packages
- Real-time notifications — not needed for data access
- Mobile/GUI — CLI/programmatic access only

## Context

OpenNeuro exposes three interaction surfaces:
1. **GraphQL API** at `/crn/graphql` for search, metadata, file listings
2. **DataLad/git-annex** workflow for robust, resumable downloads with integrity
3. **Public S3 bucket** (`openneuro.org`, us-east-1) for fast bulk downloads

The design uses external `.gql` documents for GraphQL queries (schema-resilient), pluggable download backends with automatic selection, and a lazy handle/fetch pattern that integrates well with targets pipelines.

Function naming uses `on_*` prefix for discoverability (type `on_` for autocomplete).

## Constraints

- **Tech stack**: R package, CRAN-compatible, tidyverse-aligned (tibbles, pipes)
- **Dependencies**: httr2, jsonlite, tibble, dplyr, tidyr, rlang, cli, fs, rappdirs
- **Backend CLIs**: DataLad/OpenNeuro CLI optional; AWS CLI optional; HTTPS always available
- **Target audience**: R neuroimaging community

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| `on_*` function prefix | Discoverability via autocomplete, brevity vs `openneuro_*` | — Pending |
| DataLad-first backend | OpenNeuro recommends DataLad for correctness + provenance | — Pending |
| GraphQL in `.gql` files | Schema changes only require updating query docs, not R code | — Pending |
| Metadata-first URL resolution | Introspect schema for URL fields before blind probing | — Pending |
| Manifest-tracked cache | Know what was downloaded, when, how — reproducibility | — Pending |

---
*Last updated: 2026-01-20 after initialization*

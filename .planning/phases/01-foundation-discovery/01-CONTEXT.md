# Phase 1: Foundation + Discovery - Context

**Gathered:** 2026-01-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Package skeleton and GraphQL-based dataset discovery. Users can search for datasets, get metadata, list snapshots, and list files. No downloading in this phase — that's Phase 2.

Delivers: on_search(), on_dataset(), on_snapshots(), on_files(), plus package infrastructure (DESCRIPTION, client, GraphQL layer).

</domain>

<decisions>
## Implementation Decisions

### Return format
- **Column set**: Practical set — id, name, created, updated, public, modalities (and similar useful fields)
- **Nested data**: List-columns are OK for complex/nested metadata
- **Naming convention**: snake_case (tidyverse convention, not camelCase from API)
- **Timestamps**: Parse to POSIXct for proper datetime handling

### Search behavior
- **Pagination**: Default to first page (e.g., limit=50), with optional `all=TRUE` parameter to auto-fetch all pages
- **Filters**: Include modality and species filters in v1 (on_search(modality="MRI", species="human"))

### Claude's Discretion
- What fields on_search() queries against (whatever API supports)
- Empty search behavior (return all vs require query)
- Error handling approach (network errors, invalid IDs)
- Client object design (global vs explicit, default URL/auth)

</decisions>

<specifics>
## Specific Ideas

- Tibbles should compose well with dplyr — filtering, selecting, arranging
- The design notes mention `on_*` prefix for discoverability (type `on_` for autocomplete)
- GraphQL queries should live in `inst/graphql/*.gql` files for schema resilience

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-discovery*
*Context gathered: 2026-01-20*

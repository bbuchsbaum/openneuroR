#' Derivative Dataset Discovery
#'
#' Functions for discovering derivative datasets (fMRIPrep, MRIQC, etc.)
#' for OpenNeuro datasets.
#'
#' @name discovery
#' @keywords internal
NULL

#' Detect Embedded Derivatives
#'
#' Checks if a dataset has derivatives embedded directly in its BIDS structure.
#' Embedded derivatives are stored in a `derivatives/` subdirectory within
#' the dataset itself.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param tag Snapshot version tag. If `NULL`, uses latest snapshot.
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return A tibble with derivative information, or empty tibble if no
#'   embedded derivatives found.
#'
#' @keywords internal
.detect_embedded_derivatives <- function(dataset_id, tag = NULL, client = NULL) {
  # Get root directory listing
  root_files <- on_files(dataset_id, tag, client = client)

  # Look for derivatives directory
  deriv_row <- root_files[root_files$directory == TRUE & root_files$filename == "derivatives", ]

  if (nrow(deriv_row) == 0) {
    return(.empty_derivatives_tibble())
  }

  # Get the key for the derivatives directory
  deriv_key <- deriv_row$key[1]

  # List contents of derivatives directory
  deriv_contents <- on_files(dataset_id, tag, tree = deriv_key, client = client)

  # Each subdirectory in derivatives/ is a pipeline
  pipelines <- deriv_contents[deriv_contents$directory == TRUE, ]

  if (nrow(pipelines) == 0) {
    return(.empty_derivatives_tibble())
  }

  # Build result tibble - one row per pipeline
  tibble::tibble(
    dataset_id = rep(dataset_id, nrow(pipelines)),
    pipeline = pipelines$filename,
    source = rep("embedded", nrow(pipelines)),
    version = rep(NA_character_, nrow(pipelines)),
    n_subjects = rep(NA_integer_, nrow(pipelines)),
    n_files = rep(NA_integer_, nrow(pipelines)),
    total_size = rep(NA_character_, nrow(pipelines)),
    last_modified = rep(as.POSIXct(NA, tz = "UTC"), nrow(pipelines)),
    s3_url = rep(NA_character_, nrow(pipelines))
  )
}

#' Find Derivatives in GitHub
#'
#' Searches the OpenNeuroDerivatives GitHub organization for repositories
#' matching the specified dataset.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param refresh If `TRUE`, bypass cache and fetch fresh data.
#'
#' @return A tibble with derivative information from GitHub repositories.
#'
#' @keywords internal
.find_derivatives_in_github <- function(dataset_id, refresh = FALSE) {
  # Get all derivative repos (cached)
  all_repos <- .list_openneuro_derivatives_repos(refresh)

  # Filter to matching dataset
  matching <- Filter(function(repo) repo$dataset_id == dataset_id, all_repos)

  if (length(matching) == 0) {
    return(.empty_derivatives_tibble())
  }

  # Build result tibble
  tibble::tibble(
    dataset_id = vapply(matching, function(r) r$dataset_id, character(1)),
    pipeline = vapply(matching, function(r) r$pipeline, character(1)),
    source = rep("openneuro-derivatives", length(matching)),
    version = rep(NA_character_, length(matching)),  # Would need additional API call for tags
    n_subjects = rep(NA_integer_, length(matching)),  # Not available from repo listing
    n_files = rep(NA_integer_, length(matching)),  # Not available from repo listing
    total_size = vapply(matching, function(r) {
      if (is.na(r$size_kb)) NA_character_ else .format_bytes(r$size_kb * 1024)
    }, character(1)),
    last_modified = vapply(matching, function(r) {
      .parse_timestamp(r$pushed_at)
    }, numeric(1)),
    s3_url = vapply(matching, function(r) {
      paste0("s3://openneuro-derivatives/", r$pipeline, "/", r$repo_name, "/")
    }, character(1))
  ) |>
    transform_timestamps_posix()
}

#' Transform Numeric Timestamps to POSIXct
#'
#' Converts numeric timestamp columns to POSIXct class.
#'
#' @param df A tibble with numeric timestamp column.
#'
#' @return The tibble with POSIXct timestamp columns.
#'
#' @keywords internal
transform_timestamps_posix <- function(df) {
  if ("last_modified" %in% names(df) && is.numeric(df$last_modified)) {
    df$last_modified <- as.POSIXct(df$last_modified, origin = "1970-01-01", tz = "UTC")
  }
  df
}

#' Discover Derivative Datasets
#'
#' Finds derivative datasets (fMRIPrep, MRIQC, etc.) available for an
#' OpenNeuro dataset. Searches both embedded derivatives within the dataset
#' and external derivatives from the OpenNeuroDerivatives GitHub organization.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000102").
#' @param sources Character vector specifying which sources to check.
#'   Default is `c("embedded", "openneuro-derivatives")` to check both.
#'   Use `"embedded"` for derivatives stored within the dataset, or

#'   `"openneuro-derivatives"` for external derivatives from GitHub.
#' @param refresh If `TRUE`, bypass cache and fetch fresh data from APIs.
#'   Default is `FALSE` to use cached results when available.
#' @param client An `openneuro_client` object for embedded derivative checks.
#'   If `NULL` (default), creates a default client.
#'
#' @return A tibble with one row per available derivative, containing:
#'   \describe{
#'     \item{dataset_id}{The dataset identifier}
#'     \item{pipeline}{Pipeline name (e.g., "fmriprep", "mriqc")}
#'     \item{source}{Where the derivative is from: "embedded" or "openneuro-derivatives"}
#'     \item{version}{Pipeline version (NA if not available)}
#'     \item{n_subjects}{Number of subjects processed (NA if not available)}
#'     \item{n_files}{Number of derivative files (NA if not available)}
#'     \item{total_size}{Human-readable size (e.g., "2.3 GB", NA if not available)}
#'     \item{last_modified}{Last modification time (POSIXct, NA if not available)}
#'     \item{s3_url}{S3 URL for OpenNeuroDerivatives sources (NA for embedded)}
#'   }
#'
#'   Returns an empty tibble with the same structure if no derivatives are found.
#'
#' @details
#' ## Derivative Sources
#'
#' **Embedded derivatives** are stored directly within the dataset's BIDS
#' structure in a `derivatives/` subdirectory. These are typically provided
#' by the dataset authors.
#'
#' **OpenNeuroDerivatives** are externally processed derivatives maintained
#' by the OpenNeuro team, available from the
#' [OpenNeuroDerivatives GitHub organization](https://github.com/OpenNeuroDerivatives).
#' These are stored on S3 and can be downloaded separately.
#'
#' ## Source Preference
#'
#' When the same pipeline exists in both sources, embedded derivatives are
#' preferred and the OpenNeuroDerivatives entry is removed from results.
#' This follows the principle that author-provided derivatives should take
#' precedence.
#'
#' ## Caching
#'
#' Results are cached per-session to minimize API calls. Use `refresh = TRUE`
#' to bypass the cache and fetch fresh data.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # Find all derivatives for a dataset
#' derivs <- on_derivatives("ds000102")
#' print(derivs)
#'
#' # Check only OpenNeuroDerivatives (GitHub)
#' github_derivs <- on_derivatives("ds000102", sources = "openneuro-derivatives")
#'
#' # Check only embedded derivatives
#' embedded_derivs <- on_derivatives("ds000102", sources = "embedded")
#'
#' # Force refresh of cached data
#' fresh_derivs <- on_derivatives("ds000102", refresh = TRUE)
#'
#' # Filter for fMRIPrep derivatives
#' fmriprep <- derivs[derivs$pipeline == "fmriprep", ]
#' }
#'
#' @seealso [on_files()] for listing files within datasets
on_derivatives <- function(dataset_id,
                           sources = c("embedded", "openneuro-derivatives"),
                           refresh = FALSE,
                           client = NULL) {
  # Validate dataset_id
 if (missing(dataset_id) || is.null(dataset_id) || !is.character(dataset_id) ||
      length(dataset_id) != 1 || nchar(dataset_id) == 0) {
    rlang::abort(
      c("Invalid dataset ID",
        "x" = "Dataset ID must be a non-empty character string"),
      class = "openneuro_validation_error"
    )
  }

  # Validate sources
  valid_sources <- c("embedded", "openneuro-derivatives")
  sources <- match.arg(sources, valid_sources, several.ok = TRUE)

  # Build cache key based on dataset and sources
  cache_key <- paste0("derivatives_", dataset_id, "_", paste(sort(sources), collapse = "_"))

  # Check cache first (unless refresh requested)
  if (!refresh && .discovery_cache$has(cache_key)) {
    return(.discovery_cache$get(cache_key))
  }

  # Initialize results
  results <- .empty_derivatives_tibble()

  # Check embedded derivatives
  if ("embedded" %in% sources) {
    embedded_result <- tryCatch(
      .detect_embedded_derivatives(dataset_id, tag = NULL, client = client),
      error = function(e) {
        # Let "not found" errors propagate with context
        if (inherits(e, "openneuro_not_found_error")) {
          rlang::abort(
            c("Dataset not found",
              "x" = paste0("Dataset '", dataset_id, "' does not exist or has no snapshots"),
              "i" = "Check the dataset ID and try again"),
            class = "openneuro_not_found_error",
            parent = e
          )
        }
        # For other errors (e.g., network), return empty and continue
        .empty_derivatives_tibble()
      }
    )
    results <- rbind(results, embedded_result)
  }

  # Check OpenNeuroDerivatives GitHub repos
  if ("openneuro-derivatives" %in% sources) {
    github_result <- tryCatch(
      .find_derivatives_in_github(dataset_id, refresh = refresh),
      error = function(e) {
        # Log warning but don't fail - GitHub may be unavailable
        rlang::warn(
          c("GitHub API error during derivative discovery",
            "i" = conditionMessage(e)),
          class = "openneuro_github_warning"
        )
        .empty_derivatives_tibble()
      }
    )
    results <- rbind(results, github_result)
  }

  # Handle duplicate pipelines: embedded takes precedence over openneuro-derivatives
  if (nrow(results) > 1) {
    # Find pipelines that exist in both sources
    embedded_pipelines <- results$pipeline[results$source == "embedded"]
    github_pipelines <- results$pipeline[results$source == "openneuro-derivatives"]
    duplicate_pipelines <- intersect(embedded_pipelines, github_pipelines)

    # Remove github entries for duplicate pipelines
    if (length(duplicate_pipelines) > 0) {
      results <- results[!(results$source == "openneuro-derivatives" &
                            results$pipeline %in% duplicate_pipelines), ]
    }
  }

  # Cache results
  .discovery_cache$set(cache_key, results)

  results
}

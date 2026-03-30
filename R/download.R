#' Download OpenNeuro Dataset
#'
#' Downloads files from an OpenNeuro dataset to local disk. Supports
#' downloading the full dataset, specific files, files matching a
#' regex pattern, or specific subjects.
#'
#' By default, files are downloaded to a CRAN-compliant cache location
#' (platform-specific, see Details). Repeat downloads of the same files
#' are skipped automatically based on manifest tracking.
#'
#' @param id Dataset identifier (e.g., "ds000001").
#' @param tag Snapshot version tag. If NULL (default), uses latest snapshot.
#' @param files Character vector of specific files to download, or a single
#'   regex pattern (detected by presence of regex metacharacters). If NULL
#'   (default), downloads all files.
#' @param subjects Character vector of subject IDs (e.g., `c("sub-01", "sub-02")`)
#'   or a regex pattern wrapped in [regex()] (e.g., `regex("sub-0[1-5]")`).
#'   Subject IDs can be specified with or without the "sub-" prefix.
#'   If NULL (default), downloads all subjects.
#' @param include_derivatives If TRUE (default) and `subjects` is specified,
#'   also include derivative outputs for matching subjects from the
#'   `derivatives/` directory.
#' @param dest_dir Destination directory. If NULL (default) and `use_cache`
#'   is TRUE, downloads to cache location. If NULL and `use_cache` is FALSE,
#'   creates `./dataset_id/` in the current working directory.
#' @param use_cache If TRUE (default) and dest_dir is NULL, downloads to
#'   CRAN-compliant cache location. Set FALSE to use current working directory.
#'   Ignored when dest_dir is explicitly provided.
#' @param quiet If TRUE, suppress all progress output. Default FALSE.
#' @param verbose If TRUE, show per-file progress in addition to overall
#'   progress. Default FALSE.
#' @param force If TRUE, re-download files even if they exist with correct
#'   size. Default FALSE.
#' @param backend Backend to use for downloading: "datalad", "s3", or "https".
#'   If NULL (default), auto-selects best available backend with priority:
#'   DataLad > S3 > HTTPS. DataLad provides git-annex integrity verification,
#'   S3 uses AWS CLI for fast parallel sync, HTTPS is the universal fallback.
#' @param client An openneuro_client object. If NULL, creates default client.
#'
#' @return Invisibly returns a list with:
#'   \describe{
#'     \item{downloaded}{Number of files downloaded}
#'     \item{skipped}{Number of files skipped (already cached or existed)}
#'     \item{failed}{Character vector of failed file names}
#'     \item{total_bytes}{Total bytes downloaded}
#'     \item{dest_dir}{Path to destination directory}
#'     \item{backend}{Backend used for download (if S3 or DataLad)}
#'   }
#'
#' @details
#' Cache locations by platform:
#' \itemize{
#'   \item Mac: ~/Library/Caches/R/openneuroR
#'   \item Linux: ~/.cache/R/openneuroR
#'   \item Windows: ~/AppData/Local/R/cache/openneuroR
#' }
#'
#' Each dataset is stored in a subdirectory by dataset ID. A manifest.json
#' file tracks downloaded files, enabling automatic skip of already-cached
#' files on repeat downloads.
#'
#' Backend selection:
#' \itemize{
#'   \item \strong{DataLad}: Clones from OpenNeuroDatasets GitHub with git-annex.
#'     Provides cryptographic integrity verification. Requires `datalad` and
#'     `git-annex` CLI tools.
#'   \item \strong{S3}: Uses AWS CLI `s3 sync` for fast parallel downloads.
#'     Requires `aws` CLI tool.
#'   \item \strong{HTTPS}: Direct file downloads via httr2. Always available,
#'     no external dependencies.
#' }
#'
#' Subject filtering:
#'
#' When `subjects` is specified, only files belonging to those subjects are
#' downloaded, plus root-level files (e.g., `dataset_description.json`,
#' `participants.tsv`). Subject IDs can be provided with or without the
#' "sub-" prefix - both `"01"` and `"sub-01"` work.
#'
#' For pattern matching, wrap the pattern in [regex()]. Patterns are
#' auto-anchored for full subject ID matching, so `regex("sub-01")` will

#' match "sub-01" but not "sub-010".
#'
#' @export
#' @examples
#' \donttest{
#' # Download to cache (default - auto-selects best backend)
#' on_download("ds000001", files = "participants.tsv")
#'
#' # Repeat download skips cached files
#' result <- on_download("ds000001", files = "participants.tsv")
#' result$skipped  # >= 1 (files already in cache)
#'
#' # Download to specific directory (bypasses cache)
#' on_download("ds000001", dest_dir = "~/data/openneuro")
#'
#' # Download to current working directory
#' on_download("ds000001", use_cache = FALSE)
#'
#' # Force re-download of cached files
#' on_download("ds000001", force = TRUE)
#'
#' # Use specific backend
#' on_download("ds000001", backend = "s3")
#' on_download("ds000001", backend = "https")  # Force HTTPS
#'
#' # Download specific subjects
#' on_download("ds000001", subjects = c("sub-01", "sub-02"))
#'
#' # Download subjects matching pattern
#' on_download("ds000001", subjects = regex("sub-0[1-5]"))
#'
#' # Download subjects without derivatives
#' on_download("ds000001", subjects = c("01", "02"), include_derivatives = FALSE)
#' }
on_download <- function(id, tag = NULL, files = NULL, subjects = NULL,
                        include_derivatives = TRUE, dest_dir = NULL,
                        use_cache = TRUE, quiet = FALSE, verbose = FALSE,
                        force = FALSE, backend = NULL, client = NULL) {
  .validate_dataset_id(id)

  # Get or create client
  client <- client %||% on_client()

  # Get all files in the dataset
  all_files <- .list_all_files(id, tag = tag, client = client)

  # Determine if using cache (for early return default paths)
  caching <- is.null(dest_dir) && use_cache
  default_dest <- if (caching) {
    .on_dataset_cache_path(id)
  } else {
    fs::path(getwd(), id)
  }

  if (nrow(all_files) == 0) {
    if (!quiet) {
      cli::cli_alert_warning("No files found in dataset {.val {id}}")
    }
    return(invisible(list(
      downloaded = 0L,
      skipped = 0L,
      failed = character(),
      total_bytes = 0,
      dest_dir = dest_dir %||% default_dest
    )))
  }

  # Filter files based on `files` parameter
  if (is.null(files)) {
    # Download all files
    filtered_files <- all_files
  } else if (.is_regex(files)) {
    # Single regex pattern - filter by grepl
    matches <- grepl(files, all_files$full_path)
    filtered_files <- all_files[matches, ]

    if (nrow(filtered_files) == 0) {
      if (!quiet) {
        cli::cli_alert_warning(
          "No files matched pattern {.val {files}} in dataset {.val {id}}"
        )
      }
      return(invisible(list(
        downloaded = 0L,
        skipped = 0L,
        failed = character(),
        total_bytes = 0,
        dest_dir = dest_dir %||% default_dest
      )))
    }
  } else {
    # Exact file paths - filter by membership
    filtered_files <- all_files[all_files$full_path %in% files, ]

    if (nrow(filtered_files) == 0) {
      if (!quiet) {
        cli::cli_alert_warning(
          "None of the specified files found in dataset {.val {id}}"
        )
      }
      return(invisible(list(
        downloaded = 0L,
        skipped = 0L,
        failed = character(),
        total_bytes = 0,
        dest_dir = dest_dir %||% default_dest
      )))
    }
  }

  # Filter by subjects if specified
  if (!is.null(subjects)) {
    # Get available subjects from API
    available <- on_subjects(id, tag = tag, client = client)
    available_ids <- available$subject_id

    if (is_regex(subjects)) {
      # Regex matching with auto-anchoring
      pattern <- as.character(subjects)
      # Match against normalized IDs (with sub- prefix)
      available_normalized <- .normalize_subject_ids(available_ids)
      matches <- .match_subjects_regex(available_normalized, pattern)
      matching <- available_normalized[matches]

      if (length(matching) == 0) {
        available_display <- if (length(available_normalized) <= 10) {
          paste(available_normalized, collapse = ", ")
        } else {
          paste(c(utils::head(available_normalized, 10), "..."), collapse = ", ")
        }
        rlang::abort(
          c("No subjects match pattern",
            "x" = paste0("Pattern '", pattern, "' matched 0 subjects"),
            "i" = paste0("Available in ", id, ": ", available_display)),
          class = "openneuro_validation_error"
        )
      }
    } else {
      # Literal IDs - validate and normalize
      matching <- .validate_subjects(subjects, available_ids, id)
    }

    # Filter files to matching subjects + root files
    filtered_files <- .filter_files_by_subjects(
      filtered_files, matching, include_derivatives
    )

    if (nrow(filtered_files) == 0) {
      if (!quiet) {
        cli::cli_alert_warning(
          "No files found for subjects {.val {matching}} in dataset {.val {id}}"
        )
      }
      return(invisible(list(
        downloaded = 0L,
        skipped = 0L,
        failed = character(),
        total_bytes = 0,
        dest_dir = dest_dir %||% default_dest
      )))
    }
  }

  # Set up destination directory
  if (caching) {
    # Use cache location
    dest_dir <- .on_dataset_cache_path(id)
    fs::dir_create(dest_dir, recurse = TRUE)
  } else {
    # Use specified directory or cwd/dataset_id
    dest_dir <- .ensure_dest_dir(dest_dir, id)
  }

  # Try backend dispatch (S3 or DataLad)
  # Returns NULL if HTTPS should be used (fallback or explicit)
  # Pass file list if filtering was applied (files or subjects specified)
  files_for_backend <- if (is.null(files) && is.null(subjects)) {
    NULL
  } else {
    filtered_files$full_path
  }
  backend_result <- .download_with_backend(
    dataset_id = id,
    dest_dir = dest_dir,
    files = files_for_backend,
    backend = backend,
    quiet = quiet
  )

  if (!is.null(backend_result) && isTRUE(backend_result$success)) {
    # S3 or DataLad succeeded - batch update manifest
    if (caching) {
      file_entries <- lapply(seq_len(nrow(filtered_files)), function(i) {
        list(path = filtered_files$full_path[i], size = filtered_files$size[i])
      })
      .batch_update_manifest(
        dataset_dir = dest_dir,
        file_entries = file_entries,
        dataset_id = id,
        snapshot_tag = tag,
        backend = backend_result$backend
      )
    }

    # Build result - S3/DataLad don't track individual skipped files
    total_bytes <- sum(filtered_files$size, na.rm = TRUE)
    result <- list(
      downloaded = nrow(filtered_files),
      skipped = 0L,
      failed = character(),
      total_bytes = total_bytes,
      dest_dir = dest_dir,
      backend = backend_result$backend
    )

    # Print summary
    .print_completion_summary(result, quiet)

    return(invisible(result))
  }

  # HTTPS fallback - use existing progress-based download
  result <- .download_with_progress(
    files_df = filtered_files,
    dest_dir = dest_dir,
    dataset_id = id,
    tag = tag,
    quiet = quiet,
    verbose = verbose,
    force = force,
    use_cache = caching
  )

  # Add backend to result
  result$backend <- "https"

  invisible(result)
}


#' Check if String Contains Regex Metacharacters
#'
#' Detects if a string appears to be a regex pattern by checking for
#' common metacharacters.
#'
#' @param x Character string to check.
#'
#' @return `TRUE` if `x` appears to be a regex pattern, `FALSE` otherwise.
#'
#' @keywords internal
.is_regex <- function(x) {
  # Character class with regex metacharacters

  # Note: ] must be first in character class to be literal
  length(x) == 1 && grepl("[][()*+?^${}|]", x)
}

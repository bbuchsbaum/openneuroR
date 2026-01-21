#' Download OpenNeuro Dataset
#'
#' Downloads files from an OpenNeuro dataset to local disk. Supports
#' downloading the full dataset, specific files, or files matching a
#' regex pattern.
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
#' @param client An openneuro_client object. If NULL, creates default client.
#'
#' @return Invisibly returns a list with:
#'   \describe{
#'     \item{downloaded}{Number of files downloaded}
#'     \item{skipped}{Number of files skipped (already cached or existed)}
#'     \item{failed}{Character vector of failed file names}
#'     \item{total_bytes}{Total bytes downloaded}
#'     \item{dest_dir}{Path to destination directory}
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
#' @export
#' @examples
#' \dontrun{
#' # Download to cache (default)
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
#' }
on_download <- function(id, tag = NULL, files = NULL, dest_dir = NULL,
                        use_cache = TRUE, quiet = FALSE, verbose = FALSE,
                        force = FALSE, client = NULL) {
  # Validate id
  if (missing(id) || !is.character(id) || length(id) != 1 || nchar(id) == 0) {
    rlang::abort(
      c("Invalid dataset identifier",
        "x" = "`id` must be a non-empty character string",
        "i" = 'Example: on_download("ds000001")'),
      class = "openneuro_validation_error"
    )
  }

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

  # Set up destination directory
  if (caching) {
    # Use cache location
    dest_dir <- .on_dataset_cache_path(id)
    fs::dir_create(dest_dir, recurse = TRUE)
  } else {
    # Use specified directory or cwd/dataset_id
    dest_dir <- .ensure_dest_dir(dest_dir, id)
  }

  # Download with progress (manifest tracking handled inside)
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
  length(x) == 1 && grepl("[\\[\\]\\*\\+\\?\\^\\$\\{\\|\\(\\)]", x)
}

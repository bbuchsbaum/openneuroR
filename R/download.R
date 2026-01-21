#' Download OpenNeuro Dataset
#'
#' Downloads files from an OpenNeuro dataset to local disk. Supports
#' downloading the full dataset, specific files, or files matching a
#' regex pattern.
#'
#' @param id Dataset identifier (e.g., "ds000001").
#' @param tag Snapshot version tag. If NULL (default), uses latest snapshot.
#' @param files Character vector of specific files to download, or a single
#'   regex pattern (detected by presence of regex metacharacters). If NULL
#'   (default), downloads all files.
#' @param dest_dir Destination directory. If NULL (default), creates
#'   `./dataset_id/` in the current working directory.
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
#'     \item{skipped}{Number of files skipped (already existed)}
#'     \item{failed}{Character vector of failed file names}
#'     \item{total_bytes}{Total bytes downloaded}
#'     \item{dest_dir}{Path to destination directory}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Download full dataset
#' on_download("ds000001")
#'
#' # Download specific file
#' on_download("ds000001", files = "participants.tsv")
#'
#' # Download files matching pattern (first 3 subjects)
#' on_download("ds000001", files = "sub-0[1-3].*")
#'
#' # Download to specific directory
#' on_download("ds000001", dest_dir = "~/data/openneuro")
#'
#' # Force re-download of existing files
#' on_download("ds000001", force = TRUE)
#' }
on_download <- function(id, tag = NULL, files = NULL, dest_dir = NULL,
                        quiet = FALSE, verbose = FALSE, force = FALSE,
                        client = NULL) {
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

  if (nrow(all_files) == 0) {
    if (!quiet) {
      cli::cli_alert_warning("No files found in dataset {.val {id}}")
    }
    return(invisible(list(
      downloaded = 0L,
      skipped = 0L,
      failed = character(),
      total_bytes = 0,
      dest_dir = dest_dir %||% fs::path(getwd(), id)
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
        dest_dir = dest_dir %||% fs::path(getwd(), id)
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
        dest_dir = dest_dir %||% fs::path(getwd(), id)
      )))
    }
  }

  # Set up destination directory
  dest_dir <- .ensure_dest_dir(dest_dir, id)

  # Download with progress
  result <- .download_with_progress(
    files_df = filtered_files,
    dest_dir = dest_dir,
    dataset_id = id,
    tag = tag,
    quiet = quiet,
    verbose = verbose,
    force = force
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

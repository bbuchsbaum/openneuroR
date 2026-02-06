#' List All Files in a Dataset Recursively
#'
#' Recursively traverses the directory structure of a dataset and returns
#' all files with their full paths from the dataset root.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param tag Snapshot version tag. If `NULL`, uses the most recent snapshot.
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{filename}{Name of the file (basename only)}
#'     \item{full_path}{Full path from dataset root (e.g., "sub-01/anat/T1w.nii.gz")}
#'     \item{size}{File size in bytes (numeric)}
#'     \item{annexed}{TRUE if file is stored in git-annex (logical)}
#'   }
#'
#' @details
#' This function makes multiple API calls (one per directory) to build the
#' complete file listing. For large datasets with many directories, this may
#' take some time. A progress indicator is shown in interactive sessions.
#'
#' @keywords internal
.list_all_files <- function(dataset_id, tag = NULL, client = NULL) {
  client <- client %||% on_client()

  # Resolve snapshot tag once to avoid redundant on_snapshots() calls
  # in each recursive on_files() invocation
  if (is.null(tag)) {
    snapshots <- on_snapshots(dataset_id, client)
    if (nrow(snapshots) == 0) {
      rlang::abort(
        c("No snapshots available",
          "x" = paste0("Dataset ", dataset_id, " has no snapshots")),
        class = "openneuro_not_found_error"
      )
    }
    tag <- snapshots$tag[1]
  }

  # Start progress indicator for interactive sessions
  if (interactive()) {
    cli::cli_progress_step("Scanning files in {dataset_id}...", spinner = TRUE)
  }

  # Get root listing (tag is now always resolved, no redundant on_snapshots() call)
  root_files <- on_files(dataset_id, tag = tag, client = client)

  if (nrow(root_files) == 0) {
    if (interactive()) cli::cli_progress_done()
    return(tibble::tibble(
      filename = character(),
      full_path = character(),
      size = numeric(),
      annexed = logical()
    ))
  }

  # Collect results in a list and bind once at the end (avoids O(n^2) growth)
  parts <- list()

  # Process each root entry
  for (i in seq_len(nrow(root_files))) {
    entry <- root_files[i, ]

    if (!entry$directory) {
      # It's a file at root level
      parts[[length(parts) + 1L]] <- tibble::tibble(
        filename = entry$filename,
        full_path = entry$filename,
        size = as.numeric(entry$size),
        annexed = entry$annexed
      )
    } else {
      # It's a directory - recurse into it
      subfiles <- .list_directory(
        dataset_id = dataset_id,
        tag = tag,
        key = entry$key,
        parent_path = entry$filename,
        client = client
      )
      if (nrow(subfiles) > 0) parts[[length(parts) + 1L]] <- subfiles
    }
  }

  result <- if (length(parts) > 0) dplyr::bind_rows(parts) else tibble::tibble(
    filename = character(), full_path = character(),
    size = numeric(), annexed = logical()
  )

  if (interactive()) cli::cli_progress_done()

  # Sort by full path for consistent output
  result <- dplyr::arrange(result, .data$full_path)
  result
}


#' List Files in a Directory (Helper)
#'
#' Recursively lists files in a subdirectory, building full paths.
#'
#' @param dataset_id Dataset identifier.
#' @param tag Snapshot version tag.
#' @param key Directory key for the API call.
#' @param parent_path Path prefix for building full paths.
#' @param client An `openneuro_client` object.
#'
#' @return A tibble with the same structure as `.list_all_files()`.
#'
#' @keywords internal
.list_directory <- function(dataset_id, tag, key, parent_path, client) {
  # Get files in this directory
  dir_files <- on_files(dataset_id, tag = tag, tree = key, client = client)

  if (nrow(dir_files) == 0) {
    return(tibble::tibble(
      filename = character(),
      full_path = character(),
      size = numeric(),
      annexed = logical()
    ))
  }

  parts <- list()

  for (i in seq_len(nrow(dir_files))) {
    entry <- dir_files[i, ]
    entry_full_path <- fs::path(parent_path, entry$filename)

    if (!entry$directory) {
      # It's a file
      parts[[length(parts) + 1L]] <- tibble::tibble(
        filename = entry$filename,
        full_path = as.character(entry_full_path),
        size = as.numeric(entry$size),
        annexed = entry$annexed
      )
    } else {
      # Recurse into subdirectory
      subfiles <- .list_directory(
        dataset_id = dataset_id,
        tag = tag,
        key = entry$key,
        parent_path = as.character(entry_full_path),
        client = client
      )
      if (nrow(subfiles) > 0) parts[[length(parts) + 1L]] <- subfiles
    }
  }

  if (length(parts) > 0) dplyr::bind_rows(parts) else tibble::tibble(
    filename = character(), full_path = character(),
    size = numeric(), annexed = logical()
  )
}

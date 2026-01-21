#' Download Files with Progress Reporting
#'
#' Batch downloads files with progress bar and completion summary.
#'
#' @param files_df A tibble with columns `filename`, `full_path`, `size`, `annexed`.
#' @param dest_dir Destination directory path.
#' @param dataset_id Dataset identifier for URL construction.
#' @param tag Snapshot version tag (can be NULL).
#' @param quiet If `TRUE`, suppress all output.
#' @param verbose If `TRUE`, show per-file progress in addition to overall progress.
#' @param force If `TRUE`, re-download files even if they exist with correct size.
#'
#' @return A list with components:
#'   \describe{
#'     \item{downloaded}{Number of files downloaded}
#'     \item{skipped}{Number of files skipped (already existed)}
#'     \item{failed}{Character vector of failed file names}
#'     \item{total_bytes}{Total bytes downloaded}
#'     \item{dest_dir}{Path to destination directory}
#'   }
#'
#' @keywords internal
.download_with_progress <- function(files_df, dest_dir, dataset_id, tag = NULL,
                                     quiet = FALSE, verbose = FALSE, force = FALSE) {
  n_files <- nrow(files_df)

  # Initialize counters
  downloaded_count <- 0L
  skipped_count <- 0L
  failed_files <- character()
  total_bytes <- 0

  # Determine if we should show progress
  show_progress <- interactive() && !quiet

  # Create progress bar if appropriate
  if (show_progress && n_files > 0) {
    cli::cli_progress_bar(
      name = "Downloading",
      total = n_files,
      format = "{cli::pb_bar} {cli::pb_current}/{cli::pb_total} files",
      clear = FALSE
    )
  }

  # Process each file
  for (i in seq_len(n_files)) {
    file_info <- files_df[i, ]
    dest_path <- fs::path(dest_dir, file_info$full_path)

    # Check if file exists with correct size (skip unless force=TRUE)
    if (!force && .validate_existing_file(dest_path, file_info$size)) {
      skipped_count <- skipped_count + 1L
      if (show_progress) {
        cli::cli_progress_update()
      }
      next
    }

    # Construct download URL
    url <- .construct_download_url(dataset_id, file_info$full_path)

    # Attempt download
    tryCatch(
      {
        # Ensure parent directory exists
        fs::dir_create(fs::path_dir(dest_path))

        # Download using atomic pattern (temp file + move)
        .download_atomic(
          url = url,
          final_path = dest_path,
          download_fn = function(u, p, ...) {
            .download_single_file(
              url = u,
              dest_path = p,
              expected_size = file_info$size,
              resume = TRUE,
              quiet = !verbose || quiet
            )
          }
        )

        downloaded_count <- downloaded_count + 1L
        total_bytes <- total_bytes + file_info$size

        if (verbose && !quiet) {
          cli::cli_alert_success("Downloaded {file_info$full_path}")
        }
      },
      error = function(e) {
        failed_files <<- c(failed_files, file_info$full_path)
        if (verbose && !quiet) {
          cli::cli_alert_warning("Failed: {file_info$full_path}")
        }
      }
    )

    if (show_progress) {
      cli::cli_progress_update()
    }
  }

  if (show_progress && n_files > 0) {
    cli::cli_progress_done()
  }

  # Build result

  result <- list(
    downloaded = downloaded_count,
    skipped = skipped_count,
    failed = failed_files,
    total_bytes = total_bytes,
    dest_dir = dest_dir
  )

  # Print completion summary
  .print_completion_summary(result, quiet)

  result
}


#' Format Bytes as Human-Readable String
#'
#' Converts bytes to human-readable format (B, KB, MB, GB).
#'
#' @param bytes Number of bytes.
#'
#' @return A character string with formatted size.
#'
#' @keywords internal
.format_bytes <- function(bytes) {
  if (bytes < 1024) {
    return(paste0(bytes, " B"))
  } else if (bytes < 1024^2) {
    return(paste0(round(bytes / 1024, 1), " KB"))
  } else if (bytes < 1024^3) {
    return(paste0(round(bytes / 1024^2, 1), " MB"))
  } else {
    return(paste0(round(bytes / 1024^3, 1), " GB"))
  }
}


#' Print Download Completion Summary
#'
#' Prints a summary message after batch download completes.
#'
#' @param result A list with download results (downloaded, skipped, failed, total_bytes, dest_dir).
#' @param quiet If `TRUE`, suppress all output.
#'
#' @return Invisibly returns `NULL`.
#'
#' @keywords internal
.print_completion_summary <- function(result, quiet = FALSE) {
  if (quiet) {
    return(invisible(NULL))
  }


  # Main success message
  size_str <- .format_bytes(result$total_bytes)
  cli::cli_alert_success(
    "Downloaded {result$downloaded} file{?s} ({size_str}) to {.path {result$dest_dir}}"
  )

  # Skipped files info
  if (result$skipped > 0) {
    cli::cli_alert_info("Skipped {result$skipped} existing file{?s}")
  }

  # Failed files warning
  if (length(result$failed) > 0) {
    cli::cli_alert_warning(
      "Failed to download {length(result$failed)} file{?s}: {.file {result$failed}}"
    )
  }

  invisible(NULL)
}

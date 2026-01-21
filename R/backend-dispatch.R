#' Backend Auto-Selection and Dispatch
#'
#' Internal functions for selecting the best available backend
#' and dispatching downloads with automatic fallback.
#'
#' @name backend-dispatch
#' @keywords internal
NULL


#' Select Best Available Backend
#'
#' Selects the best available download backend based on priority:
#' DataLad > S3 > HTTPS. If a preferred backend is specified,
#' attempts to use it, falling back with a warning if unavailable.
#'
#' @param preferred Character string: Preferred backend ("datalad", "s3", or "https").
#'   If NULL (default), auto-selects best available.
#'
#' @return Character string: Selected backend name.
#'
#' @keywords internal
.select_backend <- function(preferred = NULL) {
  # Backend priority order
  priority <- c("datalad", "s3", "https")

  # If preferred backend specified

  if (!is.null(preferred)) {
    preferred <- tolower(preferred)

    if (!preferred %in% priority) {
      rlang::warn(
        c("Unknown backend requested",
          "x" = paste0("Backend '", preferred, "' not recognized"),
          "i" = paste0("Valid backends: ", paste(priority, collapse = ", "))),
        class = "openneuro_warning"
      )
    } else if (.backend_status(preferred)) {
      return(preferred)
    } else {
      rlang::warn(
        c(paste0("Requested backend '", preferred, "' not available, falling back"),
          "i" = "Install required CLI tools or use a different backend"),
        class = "openneuro_warning"
      )
    }
  }

  # Auto-select by priority
  for (backend in priority) {
    if (.backend_status(backend)) {
      return(backend)
    }
  }

  # HTTPS is always available, so we should never reach here
  "https"
}


#' Download with Backend and Fallback
#'
#' Executes download using the selected backend with automatic
#' fallback on failure. Falls back through the priority chain:
#' DataLad -> S3 -> HTTPS.
#'
#' @param dataset_id Character string: Dataset identifier (e.g., "ds000001").
#' @param dest_dir Character string: Destination directory path.
#' @param files Character vector: Specific files to download. If NULL, downloads all.
#' @param backend Character string: Backend to use. If NULL, auto-selects.
#' @param quiet Logical: If TRUE, suppress progress output.
#' @param timeout Numeric: Timeout in seconds for backend operations.
#'
#' @return A list with:
#'   \describe{
#'     \item{success}{Logical: TRUE if download succeeded}
#'     \item{backend}{Character: Backend that was used}
#'   }
#'   Returns NULL if HTTPS fallback should be used (signals caller to use
#'   existing HTTPS flow).
#'
#' @keywords internal
.download_with_backend <- function(dataset_id, dest_dir, files = NULL,
                                    backend = NULL, quiet = FALSE,
                                    timeout = 1800) {
  # Select backend
  selected <- .select_backend(backend)

  if (!quiet) {
    cli::cli_alert_info("Using {.val {selected}} backend")
  }

  # If HTTPS selected, signal caller to use existing flow
  if (selected == "https") {
    return(NULL)
  }

  # Execute download with fallback
  tryCatch(
    {
      result <- switch(selected,
        "datalad" = .download_datalad(dataset_id, dest_dir, files, quiet, timeout),
        "s3" = .download_s3(dataset_id, dest_dir, files, quiet, timeout)
      )
      result
    },
    openneuro_backend_error = function(e) {
      # Determine fallback backend
      fallback <- switch(selected,
        "datalad" = "s3",
        "s3" = "https"
      )

      if (!quiet) {
        cli::cli_alert_warning("{.val {selected}} backend failed, falling back to {.val {fallback}}")
      }

      # Recursive call with fallback
      .download_with_backend(
        dataset_id = dataset_id,
        dest_dir = dest_dir,
        files = files,
        backend = fallback,
        quiet = quiet,
        timeout = timeout
      )
    }
  )
}

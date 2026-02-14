#' Download a Single File
#'
#' Downloads a file from a URL to a destination path with progress reporting,
#' automatic retry on transient failures, and resume support for large files.
#'
#' @param url URL to download from.
#' @param dest_path Destination path for the downloaded file.
#' @param expected_size Expected file size in bytes for resume logic. If `NULL`,
#'   resume is disabled.
#' @param resume Logical. If `TRUE` (default), attempt to resume partial
#'   downloads for files >= 10 MB.
#' @param quiet Logical. If `TRUE`, suppress progress bar. Default is `FALSE`.
#'
#' @return A list with components:
#'   \describe{
#'     \item{success}{Logical indicating download success}
#'     \item{path}{Path to the downloaded file}
#'     \item{bytes}{Size of the downloaded file in bytes}
#'   }
#'
#' @keywords internal
.download_single_file <- function(url, dest_path, expected_size = NULL,
                                   resume = TRUE, quiet = FALSE) {
  # Threshold for resume: 10 MB


  resume_threshold <- 10 * 1024 * 1024

  # Check if we should attempt resume
  existing_bytes <- .get_file_size(dest_path)
  should_resume <- resume &&
    !is.null(expected_size) &&
    expected_size >= resume_threshold &&
    existing_bytes > 0 &&
    existing_bytes < expected_size

  # Show progress only if interactive and not quiet
  show_progress <- interactive() && !quiet

  tryCatch(
    {
      if (should_resume) {
        # Use resumable download for large partially-downloaded files
        result <- .download_resumable(url, dest_path, existing_bytes, show_progress)
      } else {
        # Standard download
        req <- httr2::request(url) |>
          httr2::req_retry(
            max_tries = 3,
            retry_on_failure = TRUE,
            is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
          )

        if (show_progress) {
          req <- req |> httr2::req_progress(type = "down")
        }

        httr2::req_perform(req, path = dest_path)
      }

      # Return success info
      final_size <- as.numeric(fs::file_size(dest_path))
      if (!is.null(expected_size) && !is.na(expected_size) && final_size != expected_size) {
        rlang::abort(
          c("Download size mismatch",
            "x" = paste0("Expected ", expected_size, " bytes, got ", final_size)),
          class = "openneuro_download_error"
        )
      }
      list(
        success = TRUE,
        path = dest_path,
        bytes = final_size
      )
    },
    error = function(e) {
      # Clean up partial file on failure
      if (fs::file_exists(dest_path)) {
        fs::file_delete(dest_path)
      }
      rlang::abort(
        c("Download failed",
          "x" = paste0("Download failed for ", basename(dest_path), ": ", conditionMessage(e))),
        class = "openneuro_download_error",
        parent = e
      )
    }
  )
}


#' Download with Resume Support
#'
#' Downloads a file using HTTP Range headers to resume from a partial download.
#' Only used for files >= 10 MB with existing partial content.
#'
#' @param url URL to download from.
#' @param dest_path Destination path (existing partial file).
#' @param existing_bytes Number of bytes already downloaded.
#' @param show_progress Logical. If `TRUE`, show progress bar.
#'
#' @return Invisibly returns `TRUE` on success.
#'
#' @details
#' The function handles two server responses:
#' - HTTP 206 (Partial Content): Server supports Range, appends remaining bytes
#' - HTTP 200 (OK): Server ignored Range, replaces file with full download
#'
#' @keywords internal
.download_resumable <- function(url, dest_path, existing_bytes, show_progress = FALSE) {
  # Download remaining content to temp file
  temp_path <- fs::file_temp(ext = fs::path_ext(dest_path))

  tryCatch(
    {
      req <- httr2::request(url) |>
        httr2::req_headers("Range" = paste0("bytes=", existing_bytes, "-")) |>
        httr2::req_retry(
          max_tries = 3,
          retry_on_failure = TRUE,
          is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
        )

      if (show_progress) {
        req <- req |> httr2::req_progress(type = "down")
      }

      resp <- httr2::req_perform(req, path = temp_path)
      status <- httr2::resp_status(resp)

      if (status == 206L) {
        # Partial Content: append temp content to existing file in chunks
        chunk_size <- 16L * 1024L * 1024L  # 16 MB chunks
        src <- file(temp_path, "rb")
        dest <- file(dest_path, "ab")  # append binary
        tryCatch(
          {
            repeat {
              chunk <- readBin(src, "raw", n = chunk_size)
              if (length(chunk) == 0L) break
              writeBin(chunk, dest)
            }
          },
          finally = {
            close(src)
            close(dest)
          }
        )
        fs::file_delete(temp_path)
      } else if (status == 200L) {
        # Server ignored Range header, returned full file
        # Replace existing with the complete download
        fs::file_move(temp_path, dest_path)
      } else {
        # Unexpected status
        rlang::abort(
          c("Unexpected HTTP status during resume",
            "x" = paste0("Expected 200 or 206, got ", status)),
          class = "openneuro_download_error"
        )
      }

      invisible(TRUE)
    },
    error = function(e) {
      # Clean up temp file
      if (fs::file_exists(temp_path)) {
        fs::file_delete(temp_path)
      }
      stop(e)
    }
  )
}


#' Get File Size Safely
#'
#' Returns the size of a file in bytes, or 0 if the file doesn't exist.
#'
#' @param path Path to the file.
#'
#' @return Numeric file size in bytes, or 0 if file doesn't exist.
#'
#' @keywords internal
.get_file_size <- function(path) {
  if (!fs::file_exists(path)) {
    return(0)
  }
  as.numeric(fs::file_size(path))
}

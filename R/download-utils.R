#' Construct S3 Download URL for OpenNeuro File
#'
#' Builds the direct S3 HTTPS URL for downloading a file from OpenNeuro.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param file_path Path to file within the dataset (e.g., "sub-01/anat/T1w.nii.gz").
#'
#' @return A URL string for downloading the file.
#'
#' @keywords internal
.construct_download_url <- function(dataset_id, file_path) {
  base_url <- "https://s3.amazonaws.com/openneuro.org"
  # URL-encode each path segment separately to preserve forward slashes
  path_parts <- strsplit(file_path, "/", fixed = TRUE)[[1]]
  path_parts_encoded <- vapply(path_parts, utils::URLencode, character(1), reserved = TRUE)
  path_encoded <- paste(path_parts_encoded, collapse = "/")
  paste0(base_url, "/", dataset_id, "/", path_encoded)
}


#' Download File Atomically
#'
#' Downloads a file to a temporary location and moves to final destination
#' only on success. Ensures no partial/corrupt files remain on failure.
#'
#' @param url URL to download from.
#' @param final_path Final destination path for the file.
#' @param download_fn Function to perform the actual download. Should accept
#'   `url` and `dest_path` as arguments. If `NULL`, uses `.download_single_file`.
#' @param ... Additional arguments passed to `download_fn`.
#'
#' @return Invisibly returns the final path on success.
#'
#' @keywords internal
.download_atomic <- function(url, final_path, download_fn = NULL, ...) {
  # Create temp file with same extension
  temp_path <- fs::file_temp(ext = fs::path_ext(final_path))

  # Use provided download function or default
  if (is.null(download_fn)) {
    download_fn <- function(u, p, ...) {
      httr2::request(u) |>
        httr2::req_retry(
          max_tries = 3,
          retry_on_failure = TRUE,
          is_transient = \(resp) httr2::resp_status(resp) %in% c(429L, 500L, 502L, 503L, 504L)
        ) |>
        httr2::req_perform(path = p)
    }
  }

  tryCatch(
    {
      # Download to temp location
      download_fn(url, temp_path, ...)

      # Ensure destination directory exists
      fs::dir_create(fs::path_dir(final_path))

      # Move to final location (atomic on same filesystem)
      tryCatch(
        {
          fs::file_move(temp_path, final_path)
        },
        error = function(e) {
          # Cross-filesystem fallback: copy then delete
          fs::file_copy(temp_path, final_path, overwrite = TRUE)
          fs::file_delete(temp_path)
        }
      )

      invisible(final_path)
    },
    error = function(e) {
      # Clean up temp file on any failure
      if (fs::file_exists(temp_path)) {
        fs::file_delete(temp_path)
      }
      rlang::abort(
        c("Download failed",
          "x" = paste0("Failed to download: ", basename(final_path)),
          "i" = conditionMessage(e)),
        class = "openneuro_download_error",
        parent = e
      )
    }
  )
}


#' Validate Existing File
#'
#' Checks if a file exists and has the expected size.
#'
#' @param path Path to the file to check.
#' @param expected_size Expected file size in bytes.
#'
#' @return `TRUE` if file exists with correct size, `FALSE` otherwise.
#'
#' @keywords internal
.validate_existing_file <- function(path, expected_size) {
  if (!fs::file_exists(path)) {
    return(FALSE)
  }

  actual_size <- as.numeric(fs::file_size(path))
  actual_size == expected_size
}


#' Ensure Destination Directory Exists
#'
#' Sets up the destination directory for downloads. If no directory is
#' specified, uses the current working directory with the dataset ID as
#' a subdirectory.
#'
#' @param dest_dir Destination directory path, or `NULL` to use default.
#' @param dataset_id Dataset identifier for default directory naming.
#'
#' @return Absolute path to the destination directory.
#'
#' @keywords internal
.ensure_dest_dir <- function(dest_dir, dataset_id) {
  if (is.null(dest_dir)) {
    dest_dir <- fs::path(getwd(), dataset_id)
  }

  # Create directory if it doesn't exist

  fs::dir_create(dest_dir)


# Return absolute path
  fs::path_abs(dest_dir)
}

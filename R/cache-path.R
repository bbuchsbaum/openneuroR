#' Validate Dataset ID Format
#'
#' Checks that a dataset ID matches the expected OpenNeuro format (ds followed
#' by 6 digits, e.g., "ds000001"). Used at public API entry points to prevent
#' path traversal and malformed requests.
#'
#' @param id A string to validate as a dataset ID.
#'
#' @return `TRUE` invisibly if valid; aborts with an error if invalid.
#'
#' @keywords internal
.validate_dataset_id <- function(id) {
  if (missing(id) || !is.character(id) || length(id) != 1 || nchar(id) == 0) {
    rlang::abort(
      c("Invalid dataset identifier",
        "x" = "`id` must be a non-empty character string",
        "i" = 'Example: on_download("ds000001")'),
      class = "openneuro_validation_error"
    )
  }
  if (!grepl("^ds\\d{6}$", id)) {
    rlang::abort(
      c("Invalid dataset identifier format",
        "x" = paste0("Got: ", id),
        "i" = "Expected format: ds followed by 6 digits (e.g., ds000001)"),
      class = "openneuro_validation_error"
    )
  }
  invisible(TRUE)
}


#' Validate Path is Under Expected Root
#'
#' Verifies that a resolved path does not escape the expected parent directory
#' (prevents path traversal attacks via ".." segments).
#'
#' @param path The path to validate.
#' @param root The expected parent directory.
#'
#' @return `TRUE` invisibly if safe; aborts if path escapes root.
#'
#' @keywords internal
.validate_path_under_root <- function(path, root) {
  norm_path <- fs::path_norm(fs::path_abs(path))
  norm_root <- fs::path_norm(fs::path_abs(root))

  # Normalize separators and enforce path-segment boundary matching.
  # This prevents prefix collisions (e.g., /cache_root_evil matching /cache_root).
  path_chr <- gsub("\\\\", "/", as.character(norm_path))
  root_chr <- gsub("\\\\", "/", as.character(norm_root))
  under_root <- startsWith(paste0(path_chr, "/"), paste0(root_chr, "/"))

  if (!under_root) {
    rlang::abort(
      c("Path traversal detected",
        "x" = "Resolved path escapes the expected directory",
        "i" = paste0("Root: ", norm_root)),
      class = "openneuro_validation_error"
    )
  }
  invisible(TRUE)
}


#' Get Cache Root Directory
#'
#' Returns the root directory for openneuroR cache storage, using
#' CRAN-compliant location via `tools::R_user_dir()`. Creates the
#' directory if it doesn't exist.
#'
#' Platform-appropriate paths:
#' - Mac: ~/Library/Caches/R/openneuroR
#' - Linux: ~/.cache/R/openneuroR
#' - Windows: ~/AppData/Local/R/cache/openneuroR
#'
#' @section Options:
#' The cache root can be overridden by setting the `openneuro.cache_root` option:
#' \preformatted{
#' options(openneuro.cache_root = "/custom/path")
#' }
#'
#' @return Path to the cache root directory.
#'
#' @keywords internal
.on_cache_root <- function() {
  cache_root <- getOption("openneuro.cache_root",
                          default = tools::R_user_dir("openneuro", "cache"))
  fs::dir_create(cache_root, recurse = TRUE)
  cache_root
}


#' Get Dataset Cache Path
#'
#' Returns the cache directory path for a specific dataset.
#' Does NOT auto-create the directory.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#'
#' @return Path to the dataset cache directory.
#'
#' @keywords internal
.on_dataset_cache_path <- function(dataset_id) {
  .validate_dataset_id(dataset_id)
  cache_root <- .on_cache_root()
  fs::path(cache_root, dataset_id)
}


#' Get File Cache Path
#'
#' Returns the full cache path for a specific file within a dataset.
#' Does NOT auto-create the directory.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param file_path Path to file within the dataset (e.g., "sub-01/anat/T1w.nii.gz").
#'
#' @return Full path to the cached file location.
#'
#' @keywords internal
.on_file_cache_path <- function(dataset_id, file_path) {
  .validate_dataset_id(dataset_id)
  dataset_path <- .on_dataset_cache_path(dataset_id)
  fs::path(dataset_path, file_path)
}

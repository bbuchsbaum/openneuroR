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
#' @return Path to the cache root directory.
#'
#' @keywords internal
.on_cache_root <- function() {
  cache_root <- tools::R_user_dir("openneuroR", "cache")
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
  dataset_path <- .on_dataset_cache_path(dataset_id)
  fs::path(dataset_path, file_path)
}

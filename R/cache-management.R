#' List Cached Datasets
#'
#' Returns a tibble of all datasets currently in the openneuroR cache.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{dataset_id}{Dataset identifier (e.g., "ds000001")}
#'     \item{snapshot_tag}{Cached snapshot version (may be NA if unknown)}
#'     \item{n_files}{Number of cached files}
#'     \item{total_size}{Total size in bytes}
#'     \item{size_formatted}{Human-readable size (e.g., "1.2 GB")}
#'     \item{cached_at}{When first cached (ISO 8601 timestamp)}
#'     \item{type}{Type of cached data: "raw" for raw dataset files,
#'       "derivative" for fMRIPrep/MRIQC outputs, or "raw+derivative"
#'       if both are cached}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # List all cached datasets
#' on_cache_list()
#'
#' # Check total cache usage
#' cached <- on_cache_list()
#' sum(cached$total_size)  # total bytes
#'
#' # Filter to only derivatives
#' cached[grepl("derivative", cached$type), ]
#' }
on_cache_list <- function() {
  cache_root <- .on_cache_root()

  # List directories in cache (each is a dataset)
  if (!fs::dir_exists(cache_root)) {
    return(.empty_cache_tibble())
  }

  dataset_dirs <- fs::dir_ls(cache_root, type = "directory")

  if (length(dataset_dirs) == 0) {
    return(.empty_cache_tibble())
  }

  # Build list of dataset info
  results <- lapply(dataset_dirs, function(dir) {
    dataset_id <- fs::path_file(dir)
    manifest <- .read_manifest(dir)

    if (is.null(manifest)) {
      # No manifest - count files directly
      files <- fs::dir_ls(dir, recurse = TRUE, type = "file")
      files <- files[fs::path_file(files) != "manifest.json"]

      if (length(files) == 0) {
        return(NULL)  # Empty directory, skip
      }

      sizes <- vapply(files, function(f) as.numeric(fs::file_size(f)), numeric(1))
      total_size <- sum(sizes)
      n_files <- length(files)
      snapshot_tag <- NA_character_
      cached_at <- NA_character_
      type_str <- "raw"  # No manifest = legacy data, assume raw
    } else {
      # Use manifest data
      n_files <- length(manifest$files)
      total_size <- sum(vapply(manifest$files, function(f) f$size %||% 0, numeric(1)))
      snapshot_tag <- manifest$snapshot_tag %||% NA_character_
      cached_at <- manifest$cached_at %||% NA_character_

      # Determine type from manifest entries (default to "raw" for backward compat)
      types <- vapply(manifest$files, function(f) f$type %||% "raw", character(1))
      has_raw <- "raw" %in% types
      has_deriv <- "derivative" %in% types
      type_str <- if (has_raw && has_deriv) {
        "raw+derivative"
      } else if (has_deriv) {
        "derivative"
      } else {
        "raw"
      }
    }

    list(
      dataset_id = dataset_id,
      snapshot_tag = snapshot_tag,
      n_files = n_files,
      total_size = total_size,
      size_formatted = .format_bytes(total_size),
      cached_at = cached_at,
      type = type_str
    )
  })

  # Remove NULL entries
  results <- results[!vapply(results, is.null, logical(1))]

  if (length(results) == 0) {
    return(.empty_cache_tibble())
  }

  # Convert to tibble
  tibble::tibble(
    dataset_id = vapply(results, function(x) x$dataset_id, character(1)),
    snapshot_tag = vapply(results, function(x) x$snapshot_tag, character(1)),
    n_files = vapply(results, function(x) as.integer(x$n_files), integer(1)),
    total_size = vapply(results, function(x) x$total_size, numeric(1)),
    size_formatted = vapply(results, function(x) x$size_formatted, character(1)),
    cached_at = vapply(results, function(x) x$cached_at, character(1)),
    type = vapply(results, function(x) x$type, character(1))
  )
}


#' Get Cache Information
#'
#' Returns information about the openneuroR cache location and total size.
#'
#' @return A list with:
#'   \describe{
#'     \item{cache_path}{Path to cache directory}
#'     \item{n_datasets}{Number of cached datasets}
#'     \item{total_size}{Total size in bytes}
#'     \item{size_formatted}{Human-readable total size (e.g., "5.3 GB")}
#'   }
#'
#' @export
#' @examples
#' \dontrun{
#' # Get cache info
#' info <- on_cache_info()
#' info$cache_path    # Where cache is stored
#' info$n_datasets    # How many datasets
#' info$size_formatted  # Human-readable size
#' }
on_cache_info <- function() {
  cache_root <- .on_cache_root()
  cached <- on_cache_list()

  n_datasets <- nrow(cached)
  total_size <- sum(cached$total_size)

  list(
    cache_path = cache_root,
    n_datasets = n_datasets,
    total_size = total_size,
    size_formatted = .format_bytes(total_size)
  )
}


#' Clear Cache
#'
#' Removes cached datasets. Can clear a specific dataset or all cached data.
#'
#' @param dataset_id Dataset identifier to clear (e.g., "ds000001"), or
#'   NULL to clear all cached datasets.
#' @param confirm If TRUE (default in interactive sessions), asks for
#'   confirmation before clearing. Set FALSE to skip confirmation.
#'
#' @return Invisibly returns the number of datasets cleared.
#'
#' @export
#' @examples
#' \dontrun{
#' # Clear specific dataset (with confirmation)
#' on_cache_clear("ds000001")
#'
#' # Clear specific dataset without confirmation
#' on_cache_clear("ds000001", confirm = FALSE)
#'
#' # Clear all cached datasets
#' on_cache_clear()
#' }
on_cache_clear <- function(dataset_id = NULL, confirm = interactive()) {

  cache_root <- .on_cache_root()

  if (!is.null(dataset_id)) {
    # Clear specific dataset
    dataset_path <- fs::path(cache_root, dataset_id)

    if (!fs::dir_exists(dataset_path)) {
      cli::cli_alert_warning("Dataset {.val {dataset_id}} is not in cache")
      return(invisible(0L))
    }

    if (confirm) {
      msg <- paste0("Clear cached dataset '", dataset_id, "'?")
      if (!.confirm_action(msg)) {
        cli::cli_alert_info("Cache clear cancelled")
        return(invisible(0L))
      }
    }

    fs::dir_delete(dataset_path)
    cli::cli_alert_success("Cleared cache for dataset {.val {dataset_id}}")
    return(invisible(1L))
  }

  # Clear all datasets
  cached <- on_cache_list()
  n_datasets <- nrow(cached)

  if (n_datasets == 0) {
    cli::cli_alert_info("Cache is already empty")
    return(invisible(0L))
  }

  if (confirm) {
    total_size <- .format_bytes(sum(cached$total_size))
    msg <- paste0("Clear all ", n_datasets, " cached dataset(s) (", total_size, ")?")
    if (!.confirm_action(msg)) {
      cli::cli_alert_info("Cache clear cancelled")
      return(invisible(0L))
    }
  }

  # Delete each dataset directory (not the cache root itself)
  for (ds_id in cached$dataset_id) {
    fs::dir_delete(fs::path(cache_root, ds_id))
  }

  cli::cli_alert_success(
    "Cleared {n_datasets} cached dataset{?s}"
  )

  invisible(as.integer(n_datasets))
}


#' Confirm User Action
#'
#' Prompts user for confirmation in interactive sessions.
#'
#' @param message Message to display.
#'
#' @return TRUE if user confirms, FALSE otherwise.
#'
#' @keywords internal
.confirm_action <- function(message) {
  if (!interactive()) {
    return(TRUE)
  }

  response <- readline(prompt = paste0(message, " [y/N]: "))
  tolower(response) %in% c("y", "yes")
}


#' Create Empty Cache Tibble
#'
#' Returns an empty tibble with the correct column structure for cache list.
#'
#' @return An empty tibble with cache list columns.
#'
#' @keywords internal
.empty_cache_tibble <- function() {
  tibble::tibble(
    dataset_id = character(),
    snapshot_tag = character(),
    n_files = integer(),
    total_size = numeric(),
    size_formatted = character(),
    cached_at = character(),
    type = character()
  )
}

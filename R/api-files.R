#' List Files in a Snapshot
#'
#' Lists all files in a dataset snapshot. Can list the root directory or
#' drill into subdirectories using the `tree` parameter.
#'
#' @param id Dataset identifier (e.g., "ds000001").
#' @param tag Snapshot version tag (e.g., "1.0.0"). If `NULL` (default),
#'   uses the most recent snapshot.
#' @param tree Subdirectory key for listing nested files. Use the `key`
#'   column from a previous call to explore subdirectories. Default `NULL`
#'   lists the root directory.
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{filename}{Name of the file or directory}
#'     \item{size}{File size in bytes (numeric), may be NA for directories}
#'     \item{directory}{TRUE if this entry is a directory (logical)}
#'     \item{annexed}{TRUE if file is stored in git-annex (logical). Annexed
#'       files are typically larger and require special download handling.}
#'     \item{key}{Unique key for this entry. Use with `tree` parameter to
#'       explore subdirectories.}
#'   }
#'
#'   Returns an empty tibble with the same column structure if the snapshot
#'   has no files.
#'
#' @details
#' OpenNeuro stores datasets using git-annex, where large files are stored
#' separately from the git repository. The `annexed` column indicates which
#' files use this storage method.
#'
#' To explore a directory structure:
#' 1. Call `on_files()` to get the root listing
#' 2. Filter for `directory == TRUE` entries
#' 3. Use the `key` from a directory to call `on_files(tree = key)`
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # List root files using latest snapshot
#' files <- on_files("ds000001")
#' print(files)
#'
#' # List files in a specific snapshot
#' files <- on_files("ds000001", tag = "1.0.0")
#'
#' # Explore a subdirectory
#' dirs <- files[files$directory, ]
#' if (nrow(dirs) > 0) {
#'   subfiles <- on_files("ds000001", tree = dirs$key[1])
#'   print(subfiles)
#' }
#'
#' # Find all annexed (large) files
#' annexed_files <- files[files$annexed & !files$directory, ]
#' }
#'
#' @seealso [on_snapshots()] to list available snapshots
on_files <- function(id, tag = NULL, tree = NULL, client = NULL) {
  if (missing(id) || is.null(id) || !is.character(id) || nchar(id) == 0) {
    rlang::abort(
      c("Invalid dataset ID",
        "x" = "Dataset ID must be a non-empty character string"),
      class = "openneuro_validation_error"
    )
  }

  client <- client %||% on_client()

  # If no tag provided, get the latest snapshot
  if (is.null(tag)) {
    snapshots <- on_snapshots(id, client)
    if (nrow(snapshots) == 0) {
      rlang::abort(
        c("No snapshots available",
          "x" = paste0("Dataset ", id, " has no snapshots")),
        class = "openneuro_not_found_error"
      )
    }
    tag <- snapshots$tag[1]  # Most recent
  }

  gql <- .on_read_gql("get_files")
  variables <- list(datasetId = id, tag = tag)
  if (!is.null(tree)) variables$tree <- tree

  # Handle errors
  response <- tryCatch(
    on_request(gql, variables, client),
    openneuro_api_error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("does not exist|not found", msg, ignore.case = TRUE)) {
        rlang::abort(
          c("Snapshot not found",
            "x" = paste0("No snapshot '", tag, "' for dataset ", id)),
          class = "openneuro_not_found_error"
        )
      }
      rlang::cnd_signal(e)
    }
  )

  if (is.null(response$snapshot)) {
    rlang::abort(
      c("Snapshot not found",
        "x" = paste0("No snapshot '", tag, "' for dataset ", id)),
      class = "openneuro_not_found_error"
    )
  }

  .parse_files(response)
}

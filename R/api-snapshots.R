#' List Dataset Snapshots
#'
#' Retrieves all snapshots (versioned releases) for a dataset. Snapshots are
#' immutable versions of the dataset that can be referenced by tag.
#'
#' @param id Dataset identifier (e.g., "ds000001").
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{tag}{Snapshot version tag (e.g., "1.0.0")}
#'     \item{created}{Timestamp when snapshot was created (POSIXct)}
#'     \item{size}{Total size of the snapshot in bytes (numeric)}
#'   }
#'
#'   Rows are ordered with most recent snapshot first. Returns an empty tibble
#'   with the same column structure if the dataset has no snapshots.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # List all snapshots for a dataset
#' snaps <- on_snapshots("ds000001")
#' print(snaps)
#'
#' # Get the latest snapshot tag
#' latest_tag <- snaps$tag[1]
#'
#' # Calculate total size in GB
#' snaps$size_gb <- snaps$size / (1024^3)
#' }
#'
#' @seealso [on_files()] to list files in a snapshot, [on_dataset()] for metadata
on_snapshots <- function(id, client = NULL) {
  if (missing(id) || is.null(id) || !is.character(id) || nchar(id) == 0) {
    rlang::abort(
      c("Invalid dataset ID",
        "x" = "Dataset ID must be a non-empty character string"),
      class = "openneuro_validation_error"
    )
  }

  client <- client %||% on_client()
  gql <- .on_read_gql("get_snapshots")

  # Handle dataset not found errors
  response <- tryCatch(
    on_request(gql, list(id = id), client),
    openneuro_api_error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("does not exist", msg, ignore.case = TRUE)) {
        rlang::abort(
          c("Dataset not found",
            "x" = paste0("No dataset with id: ", id)),
          class = "openneuro_not_found_error"
        )
      }
      rlang::cnd_signal(e)
    }
  )

  if (is.null(response$dataset)) {
    rlang::abort(
      c("Dataset not found",
        "x" = paste0("No dataset with id: ", id)),
      class = "openneuro_not_found_error"
    )
  }

  .parse_snapshots(response)
}

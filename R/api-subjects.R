#' List Subjects in a Dataset
#'
#' Returns the subject IDs present in a dataset snapshot without downloading
#' any data. This is a metadata-only query using the OpenNeuro GraphQL API.
#'
#' @param id Dataset identifier (e.g., "ds000001").
#' @param tag Snapshot version tag (e.g., "1.0.0"). If `NULL` (default),
#'   uses the most recent snapshot.
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{dataset_id}{The dataset identifier}
#'     \item{subject_id}{Subject identifier (e.g., "sub-01")}
#'     \item{n_sessions}{Number of sessions in the dataset (same for all rows)}
#'     \item{n_files}{Estimated files per subject (same for all rows)}
#'   }
#'
#'   Returns an empty tibble with the same column structure if the dataset
#'   has no BIDS subjects (e.g., non-BIDS datasets).
#'
#' @details
#' Subject IDs are returned in natural sort order, so "sub-10" comes after
#' "sub-9" rather than after "sub-1".
#'
#' The n_sessions and n_files columns provide dataset-level context. Per-subject
#' session and file counts are not available from the OpenNeuro API.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # List subjects in a dataset
#' subjects <- on_subjects("ds000001")
#' print(subjects)
#'
#' # List subjects in a specific snapshot
#' subjects <- on_subjects("ds000001", tag = "1.0.0")
#'
#' # Get subject count
#' nrow(subjects)
#' }
#'
#' @seealso [on_files()] to list files, [on_download()] to download data
on_subjects <- function(id, tag = NULL, client = NULL) {
  .validate_dataset_id(id)

  client <- client %||% on_client()

  # Resolve latest snapshot if no tag provided
  if (is.null(tag)) {
    snapshots <- on_snapshots(id, client)
    if (nrow(snapshots) == 0) {
      rlang::abort(
        c("No snapshots available",
          "x" = paste0("Dataset ", id, " has no snapshots")),
        class = "openneuro_not_found_error"
      )
    }
    tag <- snapshots$tag[1]
  }

  gql <- .on_read_gql("get_subjects")
  variables <- list(datasetId = id, tag = tag)

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

  .parse_subjects(response, dataset_id = id)
}

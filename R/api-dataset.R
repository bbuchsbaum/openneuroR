#' Get Dataset Metadata
#'
#' Retrieves detailed metadata for a single OpenNeuro dataset.
#'
#' @param id Dataset identifier (e.g., "ds000001").
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return A tibble with one row containing:
#'   \describe{
#'     \item{id}{Dataset identifier}
#'     \item{name}{Dataset title}
#'     \item{created}{Timestamp when dataset was created (POSIXct)}
#'     \item{public}{Whether the dataset is publicly accessible (logical)}
#'     \item{latest_snapshot}{Tag of the most recent snapshot (if any)}
#'   }
#'
#' @export
#'
#' @examples
#' \donttest{
#' # Get metadata for a specific dataset
#' ds <- on_dataset("ds000001")
#' print(ds)
#'
#' # Access fields
#' ds$name
#' ds$created
#' }
#'
#' @seealso [on_search()] to find datasets, [on_snapshots()] for version history
on_dataset <- function(id, client = NULL) {
  .validate_dataset_id(id)

  client <- client %||% on_client()
  gql <- .on_read_gql("get_dataset")

  # Try to get dataset, handling "not found" errors
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
      rlang::cnd_signal(e)  # Re-raise other API errors
    }
  )

  if (is.null(response$dataset)) {
    rlang::abort(
      c("Dataset not found",
        "x" = paste0("No dataset with id: ", id)),
      class = "openneuro_not_found_error"
    )
  }

  .parse_single_dataset(response$dataset)
}

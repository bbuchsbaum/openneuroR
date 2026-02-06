#' Search OpenNeuro Datasets
#'
#' Searches the OpenNeuro database for datasets. When a text query is provided,
#' uses the search endpoint if available. Otherwise lists datasets with optional
#' filtering.
#'
#' @param query Text query to search for. Note: The OpenNeuro search API may
#'   have limited availability. If search returns no results, consider using
#'   `query = NULL` with `modality` filter instead.
#' @param modality Filter by modality (e.g., "MRI", "EEG", "MEG", "iEEG", "PET").
#'   Case-insensitive matching is attempted.
#' @param limit Maximum number of results to return per page (default 50).
#' @param all If `TRUE`, paginate through all matching results. If `FALSE`
#'   (default), return only the first page.
#' @param client An `openneuro_client` object. If `NULL`, creates a default client.
#'
#' @return A tibble with columns:
#'   \describe{
#'     \item{id}{Dataset identifier (e.g., "ds000001")}
#'     \item{name}{Dataset title}
#'     \item{created}{Timestamp when dataset was created (POSIXct)}
#'     \item{public}{Whether the dataset is publicly accessible (logical)}
#'     \item{modalities}{List of modalities in the dataset}
#'     \item{n_subjects}{Number of subjects in the dataset}
#'     \item{tasks}{List of tasks in the dataset}
#'   }
#'
#'   Returns an empty tibble with the same column structure if no matches found.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' # List datasets (most reliable)
#' results <- on_search(limit = 10)
#'
#' # Filter by modality
#' mri_datasets <- on_search(modality = "MRI", limit = 25)
#' eeg_datasets <- on_search(modality = "EEG", limit = 25)
#'
#' # Text search (may have limited availability)
#' results <- on_search("visual cortex", limit = 10)
#'
#' # Get all datasets (may be slow)
#' all_datasets <- on_search(all = TRUE)
#' }
#'
#' @seealso [on_dataset()] for detailed metadata on a single dataset
on_search <- function(query = NULL,
                      modality = NULL,
                      limit = 50,
                      all = FALSE,
                      client = NULL) {
  client <- client %||% on_client()

  # If no query, use list_datasets endpoint
  if (is.null(query)) {
    return(.on_list_datasets(modality = modality, limit = limit, all = all, client = client))
  }

  # Try search endpoint first
  gql <- .on_read_gql("search_datasets")
  variables <- list(q = query, first = as.integer(limit))

  if (!all) {
    # Single page
    response <- on_request(gql, variables, client)
    result <- .parse_search_results(response)

    # If search returns empty but we got a response, the search API may be unavailable
    if (nrow(result) == 0 && is.null(response$search)) {
      cli::cli_warn(c(
        "Text search returned no results",
        "i" = "The OpenNeuro search API may have limited availability",
        "i" = "Try using on_search(modality = ...) to filter by modality instead"
      ))
    }
    return(result)
  }

  # Paginate through all results
  results <- list()
  cursor <- NULL

  repeat {
    variables$after <- cursor
    response <- on_request(gql, variables, client)
    page_result <- .parse_search_results(response)
    results <- c(results, list(page_result))

    page_info <- response$search$pageInfo
    if (is.null(page_info) || !isTRUE(page_info$hasNextPage)) break
    cursor <- page_info$endCursor
    if (length(results) >= 200L) break  # safety limit
  }

  if (length(results) == 0) return(.empty_datasets_tibble())
  dplyr::bind_rows(results)
}

#' List Datasets (Internal)
#'
#' Lists datasets without a search query, supporting modality filter.
#'
#' @param modality Filter by modality.
#' @param limit Maximum results per page.
#' @param all Paginate through all results.
#' @param client OpenNeuro client.
#'
#' @return A tibble of datasets.
#'
#' @keywords internal
.on_list_datasets <- function(modality = NULL, limit = 50, all = FALSE, client = NULL) {
  client <- client %||% on_client()
  gql <- .on_read_gql("list_datasets")

  variables <- list(first = as.integer(limit))
  if (!is.null(modality)) variables$modality <- modality

  if (!all) {
    # Single page
    response <- on_request(gql, variables, client)
    return(.parse_datasets_response(response))
  }

  # Paginate through all results
  results <- list()
  cursor <- NULL

  repeat {
    variables$after <- cursor
    response <- on_request(gql, variables, client)
    page_result <- .parse_datasets_response(response)
    results <- c(results, list(page_result))

    page_info <- response$datasets$pageInfo
    if (!isTRUE(page_info$hasNextPage)) break
    cursor <- page_info$endCursor
    if (length(results) >= 200L) break  # safety limit
  }

  if (length(results) == 0) return(.empty_datasets_tibble())
  dplyr::bind_rows(results)
}

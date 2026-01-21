#' Response Parsing Utilities
#'
#' Internal helper functions for parsing GraphQL API responses.
#'
#' @name utils-response
#' @keywords internal
NULL

#' Convert NULL to NA
#'
#' Safely converts NULL values to NA for use in tibble columns.
#'
#' @param x A value that may be NULL.
#' @param type The NA type to return. One of "character", "real", "integer", "logical".
#'
#' @return The original value, or NA of the appropriate type if NULL.
#'
#' @keywords internal
.null_to_na <- function(x, type = "character") {
  if (is.null(x)) {
    switch(type,
      "character" = NA_character_,
      "real" = NA_real_,
      "integer" = NA_integer_,
      "logical" = NA,
      NA
    )
  } else {
    x
  }
}

#' Parse ISO Timestamp to POSIXct
#'
#' Parses ISO 8601 timestamps from the OpenNeuro API to POSIXct objects.
#'
#' @param x A character string containing an ISO timestamp, or NULL.
#'
#' @return A POSIXct object, or NA if input is NULL or invalid.
#'
#' @keywords internal
.parse_timestamp <- function(x) {
  if (is.null(x) || is.na(x) || x == "") {
    return(NA_real_)
  }
  # Try ISO 8601 format with timezone
  result <- tryCatch(
    as.POSIXct(x, format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
    error = function(e) NA_real_
  )
  # Handle milliseconds if present
  if (is.na(result)) {
    result <- tryCatch(
      as.POSIXct(sub("\\.\\d+", "", x), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC"),
      error = function(e) NA_real_
    )
  }
  result
}

#' Extract Nested Value Safely
#'
#' Extracts a value from a nested list structure, returning NA if not found.
#'
#' @param x A list object.
#' @param ... Names of nested elements to traverse.
#' @param default Default value if path not found.
#'
#' @return The value at the specified path, or the default value.
#'
#' @keywords internal
.extract_nested <- function(x, ..., default = NA) {
  path <- c(...)
  result <- x
  for (key in path) {
    if (is.null(result) || !is.list(result) || !(key %in% names(result))) {
      return(default)
    }
    result <- result[[key]]
  }
  if (is.null(result)) default else result
}

#' Parse Search Results Response
#'
#' Converts the search() query response to a tibble.
#'
#' @param response The parsed response from on_request().
#'
#' @return A tibble with dataset information.
#'
#' @keywords internal
.parse_search_results <- function(response) {
  edges <- response$search$edges

  if (length(edges) == 0) {
    return(.empty_datasets_tibble())
  }

  # Extract nodes, handling union type (search returns SearchResult which may include non-datasets)
  nodes <- lapply(edges, function(x) x$node)
  # Filter out NULL nodes (non-dataset results in union)
  nodes <- Filter(function(n) !is.null(n) && !is.null(n$id), nodes)

  if (length(nodes) == 0) {
    return(.empty_datasets_tibble())
  }

  tibble::tibble(
    id = vapply(nodes, function(x) .null_to_na(x$id), character(1)),
    name = vapply(nodes, function(x) .null_to_na(x$name), character(1)),
    created = vapply(nodes, function(x) .parse_timestamp(x$created), numeric(1)),
    public = vapply(nodes, function(x) .null_to_na(x$public, "logical"), logical(1)),
    modalities = lapply(nodes, function(x) {
      .extract_nested(x, "latestSnapshot", "summary", "modalities", default = list())
    }),
    n_subjects = vapply(nodes, function(x) {
      val <- .extract_nested(x, "latestSnapshot", "summary", "subjects", default = list())
      if (is.list(val)) as.integer(length(val)) else as.integer(.null_to_na(val, "integer"))
    }, integer(1)),
    tasks = lapply(nodes, function(x) {
      .extract_nested(x, "latestSnapshot", "summary", "tasks", default = list())
    })
  ) |>
    transform_timestamps()
}

#' Parse Datasets List Response
#'
#' Converts the datasets() query response to a tibble.
#'
#' @param response The parsed response from on_request().
#'
#' @return A tibble with dataset information.
#'
#' @keywords internal
.parse_datasets_response <- function(response) {
  edges <- response$datasets$edges

  if (length(edges) == 0) {
    return(.empty_datasets_tibble())
  }

  nodes <- lapply(edges, function(x) x$node)

  tibble::tibble(
    id = vapply(nodes, function(x) .null_to_na(x$id), character(1)),
    name = vapply(nodes, function(x) .null_to_na(x$name), character(1)),
    created = vapply(nodes, function(x) .parse_timestamp(x$created), numeric(1)),
    public = vapply(nodes, function(x) .null_to_na(x$public, "logical"), logical(1)),
    modalities = lapply(nodes, function(x) {
      .extract_nested(x, "latestSnapshot", "summary", "modalities", default = list())
    }),
    n_subjects = vapply(nodes, function(x) {
      val <- .extract_nested(x, "latestSnapshot", "summary", "subjects", default = list())
      if (is.list(val)) as.integer(length(val)) else as.integer(.null_to_na(val, "integer"))
    }, integer(1)),
    tasks = lapply(nodes, function(x) {
      .extract_nested(x, "latestSnapshot", "summary", "tasks", default = list())
    })
  ) |>
    transform_timestamps()
}

#' Parse Single Dataset Response
#'
#' Converts a single dataset to a tibble row.
#'
#' @param dataset The dataset object from response.
#'
#' @return A tibble with one row.
#'
#' @keywords internal
.parse_single_dataset <- function(dataset) {
  tibble::tibble(
    id = .null_to_na(dataset$id),
    name = .null_to_na(dataset$name),
    created = .parse_timestamp(dataset$created),
    public = .null_to_na(dataset$public, "logical"),
    latest_snapshot = .null_to_na(
      .extract_nested(dataset, "latestSnapshot", "tag", default = NA_character_)
    )
  ) |>
    transform_timestamps()
}

#' Create Empty Datasets Tibble
#'
#' Returns a tibble with the correct structure but zero rows.
#'
#' @return An empty tibble with dataset columns.
#'
#' @keywords internal
.empty_datasets_tibble <- function() {
  tibble::tibble(
    id = character(),
    name = character(),
    created = as.POSIXct(character(), tz = "UTC"),
    public = logical(),
    modalities = list(),
    n_subjects = integer(),
    tasks = list()
  )
}

#' Transform Timestamps to POSIXct
#'
#' Converts numeric timestamp columns to POSIXct class.
#'
#' @param df A tibble with numeric timestamp columns.
#'
#' @return The tibble with POSIXct timestamp columns.
#'
#' @keywords internal
transform_timestamps <- function(df) {
  if ("created" %in% names(df) && is.numeric(df$created)) {
    df$created <- as.POSIXct(df$created, origin = "1970-01-01", tz = "UTC")
  }
  df
}

#' Parse Snapshots Response
#'
#' Converts the snapshots query response to a tibble.
#'
#' @param response The parsed response from on_request().
#'
#' @return A tibble with snapshot information.
#'
#' @keywords internal
.parse_snapshots <- function(response) {
  snapshots <- response$dataset$snapshots

  if (length(snapshots) == 0) {
    return(tibble::tibble(
      tag = character(),
      created = as.POSIXct(character(), tz = "UTC"),
      size = numeric()
    ))
  }

  tibble::tibble(
    tag = vapply(snapshots, function(x) .null_to_na(x$tag), character(1)),
    created = vapply(snapshots, function(x) .parse_timestamp(x$created), numeric(1)),
    size = vapply(snapshots, function(x) .null_to_na(x$size, "real"), numeric(1))
  ) |>
    transform_timestamps()
}

#' Parse Files Response
#'
#' Converts the files query response to a tibble.
#'
#' @param response The parsed response from on_request().
#'
#' @return A tibble with file information.
#'
#' @keywords internal
.parse_files <- function(response) {
  files <- response$snapshot$files

  if (length(files) == 0) {
    return(tibble::tibble(
      filename = character(),
      size = numeric(),
      directory = logical(),
      annexed = logical(),
      key = character()
    ))
  }

  tibble::tibble(
    filename = vapply(files, function(x) .null_to_na(x$filename), character(1)),
    size = vapply(files, function(x) .null_to_na(x$size, "real"), numeric(1)),
    directory = vapply(files, function(x) .null_to_na(x$directory, "logical"), logical(1)),
    annexed = vapply(files, function(x) .null_to_na(x$annexed, "logical"), logical(1)),
    key = vapply(files, function(x) .null_to_na(x$key), character(1))
  )
}

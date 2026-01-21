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

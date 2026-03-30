#' Mark String as Regex Pattern for Subject Filtering
#'
#' Creates a regex pattern object for use with the `subjects` parameter in
#' [on_download()]. Patterns are auto-anchored to match complete subject IDs.
#'
#' @param pattern A single non-empty character string containing a regex pattern.
#'
#' @return A character vector with class `c("on_regex", "character")`.
#'
#' @export
#'
#' @examples
#' # Match subjects sub-01 through sub-05
#' regex("sub-0[1-5]")
#'
#' # Match any subject starting with sub-1
#' regex("sub-1.*")
#'
#' \dontrun{
#' # Use in on_download()
#' on_download("ds000001", subjects = regex("sub-0[1-5]"))
#' }
#'
#' @seealso [on_download()] for downloading with subject filters
regex <- function(pattern) {
  if (is.null(pattern) || !is.character(pattern) || length(pattern) != 1 ||
      nchar(pattern) == 0) {
    rlang::abort(
      c("Invalid regex pattern",
        "x" = "`pattern` must be a single non-empty character string",
        "i" = 'Example: regex("sub-0[1-5]")'),
      class = "openneuro_validation_error"
    )
  }

  structure(pattern, class = c("on_regex", "character"))
}


#' Check if Object is a Regex Pattern
#'
#' Tests whether an object was created by [regex()].
#'
#' @param x Object to test.
#'
#' @return `TRUE` if `x` inherits from `"on_regex"`, `FALSE` otherwise.
#'
#' @keywords internal
is_regex <- function(x) {
  inherits(x, "on_regex")
}


#' Normalize a Single Subject ID
#'
#' Ensures subject ID has "sub-" prefix.
#'
#' @param id A single subject ID string.
#'
#' @return Character string with "sub-" prefix.
#'
#' @keywords internal
.normalize_subject_id <- function(id) {
  if (startsWith(id, "sub-")) {
    id
  } else {
    paste0("sub-", id)
  }
}


#' Normalize Subject IDs
#'
#' Vectorized wrapper for [.normalize_subject_id()].
#'
#' @param ids Character vector of subject IDs.
#'
#' @return Character vector with all IDs prefixed with "sub-".
#'
#' @keywords internal
.normalize_subject_ids <- function(ids) {
  if (length(ids) == 0) return(character(0))
  ifelse(startsWith(ids, "sub-"), ids, paste0("sub-", ids))
}


#' Validate Subject IDs Against Available Subjects
#'
#' Checks that requested subject IDs exist in the dataset.
#'
#' @param requested Character vector of requested subject IDs.
#' @param available Character vector of available subject IDs from API.
#' @param dataset_id Dataset identifier for error messages.
#'
#' @return Character vector of normalized requested IDs (with "sub-" prefix).
#'
#' @keywords internal
.validate_subjects <- function(requested, available, dataset_id) {
  # Normalize both sets for comparison
  requested_norm <- .normalize_subject_ids(requested)
  available_norm <- .normalize_subject_ids(available)

  # Find invalid IDs
  invalid <- requested_norm[!requested_norm %in% available_norm]

  if (length(invalid) > 0) {
    # Build helpful error message with available subjects
    available_display <- if (length(available_norm) <= 10) {
      paste(available_norm, collapse = ", ")
    } else {
      paste(c(utils::head(available_norm, 10), "..."), collapse = ", ")
    }

    rlang::abort(
      c("Invalid subject IDs",
        "x" = paste0("Subject(s) not found: ", paste(invalid, collapse = ", ")),
        "i" = paste0("Available in ", dataset_id, ": ", available_display)),
      class = "openneuro_validation_error"
    )
  }

  requested_norm
}


#' Match Subjects Against Regex Pattern
#'
#' Matches subject IDs against a regex pattern with auto-anchoring.
#'
#' @param subject_ids Character vector of subject IDs to match.
#' @param pattern Regex pattern string (without anchors).
#'
#' @return Logical vector indicating which subjects match.
#'
#' @keywords internal
.match_subjects_regex <- function(subject_ids, pattern) {
 # Auto-anchor pattern for full match
  anchored_pattern <- paste0("^", pattern, "$")
  grepl(anchored_pattern, subject_ids)
}


#' Filter Files by Subjects
#'
#' Filters a file tibble to only include files for matching subjects
#' plus root-level files.
#'
#' @param files_df Tibble from [.list_all_files()] with `full_path` column.
#' @param matching_subjects Character vector of subject IDs (with "sub-" prefix).
#' @param include_derivatives If TRUE, include derivatives/*/sub-XX/ files.
#'
#' @return Filtered tibble.
#'
#' @keywords internal
.filter_files_by_subjects <- function(files_df, matching_subjects,
                                       include_derivatives = TRUE) {
  paths <- files_df$full_path

  # Root-level files (no directory separator) are always included
  is_root <- !grepl("/", paths, fixed = TRUE)

  # Build a single alternation regex for all subjects (vectorized matching)
  subj_alt <- paste(matching_subjects, collapse = "|")

  # Direct subject directory: sub-XX/...
  subj_pattern <- paste0("^(", subj_alt, ")/")
  is_subject_file <- grepl(subj_pattern, paths)

  # Derivatives directory: derivatives/*/sub-XX/...
  if (include_derivatives) {
    deriv_pattern <- paste0("^derivatives/[^/]+/(", subj_alt, ")/")
    is_deriv_file <- grepl(deriv_pattern, paths)
  } else {
    is_deriv_file <- logical(length(paths))
  }

  files_df[is_root | is_subject_file | is_deriv_file, ]
}

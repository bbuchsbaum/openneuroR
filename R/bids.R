# BIDS Bridge Functions
# Provides integration between OpenNeuro handles and bidser BIDS projects

#' Create BIDS Project from OpenNeuro Handle
#'
#' Converts a fetched OpenNeuro dataset handle into a bidser `bids_project`
#' object, enabling BIDS-aware data access to subjects, sessions, files,
#' and derivatives.
#'
#' @param handle An `openneuro_handle` object, typically created with
#'   [on_handle()] and fetched with [on_fetch()]. If the handle is in
#'   "pending" state, it will be automatically fetched first.
#' @param fmriprep Logical. If `TRUE`, include fMRIPrep derivatives from
#'   the default `derivatives/fmriprep` path. Ignored if `prep_dir` is
#'   specified. Default is `FALSE`.
#' @param prep_dir Character. Path to derivatives directory relative to
#'   the dataset root. If specified, takes precedence over `fmriprep`.
#'   Default is `"derivatives/fmriprep"`.
#'
#' @return A `bids_project` object from the bidser package.
#'
#' @details
#' This function provides a bridge between OpenNeuro's download system
#' and bidser's BIDS-aware data structures. The resulting `bids_project`
#' object exposes:
#' - Subject and session information
#' - BIDS file listings by modality

#' - Derivatives access (if available)
#'
#' The bidser package is required but listed as an optional dependency
#' (Suggests). If not installed, a helpful message guides installation.
#'
#' @section Derivatives Handling:
#' When `fmriprep = TRUE`, the function looks for derivatives at
#' `derivatives/fmriprep` within the dataset. You can specify a custom
#' derivatives path with `prep_dir`.
#'
#' If `prep_dir` is set to a non-default value, it takes precedence over
#' `fmriprep = TRUE`. A warning is issued if the requested derivatives
#' path does not exist.
#'
#' @export
#' @seealso [on_handle()] to create a handle, [on_fetch()] to download data.
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' handle <- on_handle("ds000001")
#' handle <- on_fetch(handle)
#' bids <- on_bids(handle)
#'
#' # Auto-fetch if needed
#' handle <- on_handle("ds000002")
#' bids <- on_bids(handle)  # Fetches automatically
#'
#' # Include fMRIPrep derivatives
#' bids <- on_bids(handle, fmriprep = TRUE)
#'
#' # Custom derivatives path
#' bids <- on_bids(handle, prep_dir = "derivatives/custom-pipeline")
#' }
on_bids <- function(handle, fmriprep = FALSE, prep_dir = "derivatives/fmriprep") {
  # Check for bidser availability first

rlang::check_installed(
    "bidser",
    reason = "to create BIDS project objects from OpenNeuro datasets"
  )

  # Validate input is an openneuro_handle
  if (!inherits(handle, "openneuro_handle")) {
    rlang::abort(
      c(
        "Expected an `openneuro_handle` object",
        "x" = paste0("Got object of class: ", paste(class(handle), collapse = ", ")),
        "i" = "Create a handle with on_handle(), then fetch with on_fetch()"
      ),
      class = "openneuro_validation_error"
    )
  }

  # Auto-fetch if handle is pending
  if (handle$state == "pending") {
    cli::cli_alert_info("Handle not yet fetched, fetching now...")
    handle <- on_fetch(handle)
  }

  # Get the dataset path
  path <- on_path(handle)

  # Validate BIDS structure
  .validate_bids_structure(path)

  # Determine derivatives handling
  # prep_dir wins if it's non-default, otherwise use fmriprep flag
  default_prep_dir <- "derivatives/fmriprep"
  use_custom_prep <- !identical(prep_dir, default_prep_dir)
  use_fmriprep <- if (use_custom_prep) FALSE else fmriprep

  # Check derivatives path if derivatives are requested
  deriv_exists <- .check_derivatives_path(path, fmriprep, prep_dir)

  # Info message
  cli::cli_alert_info("Creating BIDS project from {.val {handle$dataset_id}}")

  # Create and return the bids_project
  bidser::bids_project(
    path = path,
    fmriprep = use_fmriprep,
    prep_dir = prep_dir
  )
}


#' Validate BIDS Structure
#'
#' Internal helper to validate that a directory has basic BIDS structure.
#'
#' @param path Path to the dataset root directory.
#'
#' @return NULL invisibly (errors if invalid).
#'
#' @keywords internal
#' @noRd
.validate_bids_structure <- function(path) {
  desc_file <- fs::path(path, "dataset_description.json")

  if (!fs::file_exists(desc_file)) {
    rlang::abort(
      c(
        "Not a valid BIDS dataset",
        "x" = "Missing required file: dataset_description.json",
        "i" = "BIDS datasets must contain a dataset_description.json file at the root",
        "i" = paste0("Checked path: ", path)
      ),
      class = "openneuro_bids_error"
    )
  }

  invisible(NULL)
}


#' Check Derivatives Path
#'
#' Internal helper to check if requested derivatives path exists.
#'
#' @param path Path to the dataset root directory.
#' @param fmriprep Logical indicating if fmriprep derivatives requested.
#' @param prep_dir Path to derivatives directory relative to dataset root.
#'
#' @return TRUE if derivatives exist, FALSE if requested but missing,
#'   NULL if derivatives not requested.
#'
#' @keywords internal
#' @noRd
.check_derivatives_path <- function(path, fmriprep, prep_dir) {
  # Check if derivatives are being requested
  default_prep_dir <- "derivatives/fmriprep"
  requesting_derivatives <- fmriprep || !identical(prep_dir, default_prep_dir)

  if (!requesting_derivatives) {
    return(NULL)
  }

  # Build the full derivatives path
  deriv_path <- fs::path(path, prep_dir)

  if (!fs::dir_exists(deriv_path)) {
    cli::cli_warn(c(
      "Derivatives path does not exist",
      "x" = "Path not found: {.path {deriv_path}}",
      "i" = "The BIDS project will be created but derivatives may not be available"
    ))
    return(FALSE)
  }

  TRUE
}

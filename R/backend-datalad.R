#' Determine DataLad Action for Directory
#'
#' Checks whether a destination directory needs to be cloned or can be updated.
#'
#' @param dest_dir Path to the destination directory.
#'
#' @return Character string: "clone" if directory doesn't exist or is empty,
#'   "update" if directory is already a DataLad dataset. Aborts if directory
#'   exists but is not a DataLad dataset.
#'
#' @keywords internal
.datalad_action <- function(dest_dir) {
  datalad_dir <- fs::path(dest_dir, ".datalad")

  if (fs::dir_exists(datalad_dir)) {
    # Already a DataLad dataset - use update/get
    return("update")
  } else if (fs::dir_exists(dest_dir) && length(fs::dir_ls(dest_dir)) > 0) {
    # Non-empty directory that's not a DataLad dataset
    rlang::abort(
      c("Destination exists but is not a DataLad dataset",
        "x" = paste0("Directory not empty: ", dest_dir),
        "i" = "Use a different destination or clear the directory"),
      class = "openneuro_backend_error"
    )
  }

  "clone"
}


#' Download Dataset via DataLad
#'
#' Downloads a dataset using the DataLad CLI with git-annex integrity
#' verification. Clones the dataset from the OpenNeuroDatasets GitHub
#' repository and retrieves file content with checksums.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param dest_dir Destination directory for the dataset.
#' @param files Character vector of specific files to retrieve. If `NULL`
#'   (default), retrieves all files.
#' @param quiet Logical. If `TRUE`, suppress progress output. Default is `FALSE`.
#' @param timeout Timeout in seconds for the get operation. Default is 1800
#'   (30 minutes) to accommodate large datasets.
#'
#' @return A list with components:
#'   \describe{
#'     \item{success}{Logical indicating success (`TRUE`)}
#'     \item{backend}{Character string `"datalad"`}
#'   }
#'
#' @details
#' The function performs two operations:
#' 1. **Clone** (if needed): Clones the dataset from
#'    `https://github.com/OpenNeuroDatasets/{dataset_id}.git`
#' 2. **Get**: Retrieves file content with integrity verification via git-annex
#'
#' If the destination is already a DataLad dataset (has `.datalad/` directory),
#' the clone step is skipped and only the get operation runs.
#'
#' @keywords internal
.download_datalad <- function(dataset_id, dest_dir, files = NULL,
                               quiet = FALSE, timeout = 1800) {
  # Construct GitHub URL for OpenNeuroDatasets

github_url <- paste0("https://github.com/OpenNeuroDatasets/", dataset_id, ".git")

  # Determine action: clone or update
  action <- .datalad_action(dest_dir)

  # Clone if needed (new dataset)
  if (action == "clone") {
    clone_result <- processx::run(
      command = "datalad",
      args = c("clone", github_url, dest_dir),
      error_on_status = FALSE,
      timeout = 300  # 5 minutes for clone
    )

    if (clone_result$status != 0) {
      rlang::abort(
        c("DataLad clone failed",
          "x" = clone_result$stderr,
          "i" = paste0("URL: ", github_url)),
        class = "openneuro_backend_error"
      )
    }
  }

  # Build get arguments
  if (is.null(files)) {
    get_args <- c("get", ".")
  } else {
    get_args <- c("get", files)
  }

  # Run datalad get from within the dataset directory
  get_result <- processx::run(
    command = "datalad",
    args = get_args,
    wd = dest_dir,
    error_on_status = FALSE,
    timeout = timeout
  )

  if (get_result$status != 0) {
    rlang::abort(
      c("DataLad get failed",
        "x" = get_result$stderr,
        "i" = paste0("Dataset: ", dataset_id)),
      class = "openneuro_backend_error"
    )
  }

  list(success = TRUE, backend = "datalad")
}

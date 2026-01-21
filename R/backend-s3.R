#' S3 Backend for AWS CLI Downloads
#'
#' Internal functions for downloading OpenNeuro datasets via AWS CLI.
#'
#' @name backend-s3
#' @keywords internal
NULL


#' Download Dataset via S3 Backend
#'
#' Uses AWS CLI `s3 sync` command to download datasets from the
#' OpenNeuro S3 bucket. Supports selective file downloads via
#' include/exclude patterns.
#'
#' @param dataset_id Character string: Dataset identifier (e.g., "ds000001").
#' @param dest_dir Character string: Destination directory path.
#' @param files Character vector: Specific files/patterns to download.
#'   If NULL, downloads all files. Patterns support glob syntax.
#' @param quiet Logical: If TRUE, suppress progress output.
#' @param timeout Numeric: Timeout in seconds. Default 1800 (30 minutes).
#'
#' @return Invisibly returns a list with:
#'   \describe{
#'     \item{success}{Logical: TRUE if download succeeded}
#'     \item{backend}{Character: "s3"}
#'   }
#'
#' @details
#' Uses `--no-sign-request` for anonymous access to the public
#' OpenNeuro S3 bucket (`s3://openneuro.org`).
#'
#' When `files` is provided, the function first excludes all files
#' (`--exclude "*"`) then includes only the specified patterns.
#' This is the correct order for AWS CLI include/exclude logic.
#'
#' @keywords internal
.download_s3 <- function(dataset_id, dest_dir, files = NULL, quiet = FALSE,
                          timeout = 1800) {
  # Find AWS CLI
  aws_path <- .find_aws_cli()
  if (!nzchar(aws_path)) {
    rlang::abort(
      c("AWS CLI not found",
        "x" = "The 'aws' command is not available in PATH",
        "i" = "Install AWS CLI: https://aws.amazon.com/cli/"),
      class = "openneuro_backend_error"
    )
  }

  # Construct S3 URI
  s3_uri <- paste0("s3://openneuro.org/", dataset_id)

  # Build args vector
  args <- c("s3", "sync", "--no-sign-request", s3_uri, dest_dir)

  # Add include patterns if specific files requested
  if (!is.null(files)) {
    # Exclude everything first, then include specific patterns
    args <- c(args, "--exclude", "*")
    for (f in files) {
      args <- c(args, "--include", f)
    }
  }

  # Suppress progress if quiet
  if (quiet) {
    args <- c(args, "--only-show-errors")
  }

  # Execute via processx
  result <- processx::run(
    command = aws_path,
    args = args,
    error_on_status = FALSE,
    timeout = timeout
  )

  # Check result
  if (result$status != 0) {
    rlang::abort(
      c("S3 download failed",
        "x" = if (nzchar(result$stderr)) result$stderr else "Unknown error",
        "i" = paste0("Command: aws ", paste(args, collapse = " "))),
      class = "openneuro_backend_error"
    )
  }

  invisible(list(success = TRUE, backend = "s3"))
}

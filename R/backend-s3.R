#' S3 Backend for AWS CLI Downloads
#'
#' Internal functions for downloading OpenNeuro datasets via AWS CLI.
#'
#' @name backend-s3
#' @keywords internal
NULL


#' Download Dataset via S3 Backend
#'
#' Uses AWS CLI `s3 sync` command to download datasets from an
#' OpenNeuro S3 bucket. Supports selective file downloads via
#' include/exclude patterns.
#'
#' @param dataset_id Character string: Dataset identifier (e.g., "ds000001").
#'   For derivatives, caller constructs path as `<pipeline>/<dataset_id>-<pipeline>`.
#' @param dest_dir Character string: Destination directory path.
#' @param files Character vector: Specific files/patterns to download.
#'   If NULL, downloads all files. Patterns support glob syntax.
#' @param quiet Logical: If TRUE, suppress progress output.
#' @param timeout Numeric: Timeout in seconds. Default 1800 (30 minutes).
#' @param bucket Character string: S3 bucket name. Default "openneuro.org".
#'   Use "openneuro-derivatives" for derivative datasets.
#'
#' @return Invisibly returns a list with:
#'   \describe{
#'     \item{success}{Logical: TRUE if download succeeded}
#'     \item{backend}{Character: "s3"}
#'   }
#'
#' @details
#' Uses `--no-sign-request` for anonymous access to public S3 buckets.
#'
#' Supported buckets:
#' \itemize{
#'   \item `openneuro.org` - Raw datasets (default)
#'   \item `openneuro-derivatives` - Pre-computed derivatives (fMRIPrep, MRIQC, etc.)
#' }
#'
#' When `files` is provided, the function first excludes all files
#' (`--exclude "*"`) then includes only the specified patterns.
#' This is the correct order for AWS CLI include/exclude logic.
#'
#' @keywords internal
.download_s3 <- function(dataset_id, dest_dir, files = NULL, quiet = FALSE,
                          timeout = 1800, bucket = "openneuro.org") {
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

  # Construct S3 URI with parameterized bucket
  s3_uri <- paste0("s3://", bucket, "/", dataset_id)

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
        "i" = paste0("Bucket: ", bucket),
        "i" = paste0("Command: aws ", paste(args, collapse = " "))),
      class = "openneuro_backend_error"
    )
  }

  invisible(list(success = TRUE, backend = "s3"))
}


#' Probe S3 Bucket Accessibility
#'
#' Tests whether an S3 bucket is accessible via anonymous access.
#' Results are cached per-session to avoid repeated network probes.
#'
#' @param bucket Character string: S3 bucket name (e.g., "openneuro.org").
#' @param test_path Character string: Optional path within bucket to test.
#'   Useful for buckets with restricted ListObjectsV2 permissions.
#'   If NULL, probes bucket root.
#' @param refresh Logical: If TRUE, bypass cache and probe again.
#'
#' @return Logical: TRUE if bucket is accessible, FALSE otherwise.
#'
#' @details
#' Uses `aws s3 ls --no-sign-request` to test bucket access.
#' The probe has a 10-second timeout to avoid blocking on network issues.
#'
#' Results are cached in `.discovery_cache` with key format
#' `s3_bucket_probe_<bucket>` (or `s3_bucket_probe_<bucket>_<test_path>`
#' if test_path is provided).
#'
#' @keywords internal
.probe_s3_bucket <- function(bucket, test_path = NULL, refresh = FALSE) {
  # Build cache key
  cache_key <- if (is.null(test_path)) {
    paste0("s3_bucket_probe_", bucket)
  } else {
    paste0("s3_bucket_probe_", bucket, "_", gsub("/", "_", test_path))
  }

  # Check cache unless refresh requested
  if (!refresh && .discovery_cache$has(cache_key)) {
    return(.discovery_cache$get(cache_key))
  }

  # Find AWS CLI
  aws_path <- .find_aws_cli()
  if (!nzchar(aws_path)) {
    cli::cli_alert_warning("Cannot probe S3 bucket: AWS CLI not found")
    .discovery_cache$set(cache_key, FALSE)
    return(FALSE)
  }

  # Construct S3 URI
  s3_uri <- if (is.null(test_path)) {
    paste0("s3://", bucket, "/")
  } else {
    paste0("s3://", bucket, "/", test_path)
  }

  cli::cli_alert_info("Probing S3 bucket accessibility: {.val {s3_uri}}")

  # Build args
  args <- c("s3", "ls", "--no-sign-request", s3_uri, "--max-items", "1")

  # Execute probe with short timeout
  result <- tryCatch(
    {
      processx::run(
        command = aws_path,
        args = args,
        error_on_status = FALSE,
        timeout = 10
      )
    },
    error = function(e) {
      # Timeout or other error
      list(status = -1, stderr = conditionMessage(e))
    }
  )

  # Determine accessibility
  accessible <- result$status == 0

  if (accessible) {
    cli::cli_alert_success("S3 bucket {.val {bucket}} is accessible")
  } else {
    cli::cli_alert_warning(
      "S3 bucket {.val {bucket}} not accessible: {result$stderr}"
    )
  }

  # Cache result
  .discovery_cache$set(cache_key, accessible)
  accessible
}

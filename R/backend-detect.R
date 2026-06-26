#' Backend Availability Detection
#'
#' Internal functions for detecting available download backends.
#'
#' @name backend-detect
#' @keywords internal
NULL


#' Wrapper for Sys.which
#'
#' Wraps Sys.which to enable mocking in tests.
#'
#' @param names Character vector of command names to find.
#'
#' @return Named character vector with paths (or empty strings).
#'
#' @keywords internal
.sys_which <- function(names) {
  Sys.which(names)
}


#' Check if Specific Backend is Available
#'
#' Checks if the required CLI tools for a backend are installed
#' and accessible in the system PATH.
#'
#' @param backend Character string: "s3", "datalad", or "https".
#'
#' @return Logical: TRUE if backend is available, FALSE otherwise.
#'
#' @keywords internal
.backend_available <- function(backend) {
  switch(backend,
    "s3" = {
      aws_path <- .find_aws_cli()
      nzchar(aws_path) && .aws_cli_works(aws_path)
    },
    "datalad" = nzchar(.sys_which("datalad")) && nzchar(.sys_which("git-annex")),
    "https" = TRUE,  # Always available
    FALSE  # Unknown backend
  )
}


#' Check that the AWS CLI Actually Runs
#'
#' A binary named `aws` on the PATH is not sufficient: broken installations
#' (for example a Python entry point whose `awscli` module is missing) are
#' present but non-functional. This invokes `aws --version` and reports
#' success only when the command exits cleanly, so backend auto-selection
#' never picks an S3 backend that cannot run.
#'
#' @param aws_path Path to the AWS CLI executable.
#'
#' @return Logical: TRUE if `aws --version` exits with status 0, else FALSE.
#'
#' @keywords internal
.aws_cli_works <- function(aws_path) {
  if (!nzchar(aws_path)) {
    return(FALSE)
  }
  tryCatch(
    {
      result <- processx::run(
        aws_path,
        args = "--version",
        timeout = 5,
        error_on_status = FALSE
      )
      isTRUE(result$status == 0)
    },
    error = function(e) FALSE
  )
}


#' Session-Cached Backend Status
#'
#' Caches backend availability detection results for the session
#' to avoid repeated Sys.which() calls.
#'
#' @param backend Character string: "s3", "datalad", or "https".
#' @param refresh Logical: If TRUE, re-check availability even if cached.
#'
#' @return Logical: TRUE if backend is available, FALSE otherwise.
#'
#' @keywords internal
.backend_status <- local({
  cache <- list()
  function(backend, refresh = FALSE) {
    if (refresh || is.null(cache[[backend]])) {
      cache[[backend]] <<- .backend_available(backend)
    }
    cache[[backend]]
  }
})


#' Find AWS CLI Executable
#'
#' Searches for the AWS CLI in PATH and common installation locations.
#'
#' @return Character string: Path to AWS CLI, or empty string if not found.
#'
#' @keywords internal
.find_aws_cli <- function() {
  # Check PATH first
  path <- .sys_which("aws")
  if (nzchar(path)) {
    return(as.character(path))
  }

  # Check common installation locations
  common_paths <- c(
    "/usr/local/bin/aws",
    "/opt/homebrew/bin/aws",
    path.expand("~/.local/bin/aws")
  )

  # Add Windows-specific paths
  if (.Platform$OS.type == "windows") {
    common_paths <- c(
      common_paths,
      "C:/Program Files/Amazon/AWSCLIV2/aws.exe",
      "C:/Program Files/Amazon/AWSCLI/bin/aws.exe"
    )
  }

  for (p in common_paths) {
    if (file.exists(p)) {
      return(p)
    }
  }

  ""  # Not found
}

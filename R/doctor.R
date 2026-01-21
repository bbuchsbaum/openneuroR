#' OpenNeuro Backend Diagnostics
#'
#' Reports the status of all available download backends, showing which
#' are installed, their versions, and readiness for use.
#'
#' @return Invisibly returns an object of class `openneuro_doctor` containing:
#'   \describe{
#'     \item{https}{List with available (always TRUE), version (NA)}
#'     \item{s3}{List with available (logical), version (character or NA)}
#'     \item{datalad}{List with available (logical), version (character or NA)}
#'   }
#'
#' @export
#' @examples
#' on_doctor()
on_doctor <- function() {
  # Gather status for each backend with refresh to ensure current state
  https_available <- .backend_status("https", refresh = TRUE)
  s3_available <- .backend_status("s3", refresh = TRUE)
  datalad_available <- .backend_status("datalad", refresh = TRUE)

  # Get versions for available backends
  s3_version <- if (s3_available) .get_aws_version() else NA_character_
  datalad_version <- if (datalad_available) .get_datalad_version() else NA_character_

  # Build result structure
  result <- structure(
    list(
      https = list(available = TRUE, version = NA_character_),
      s3 = list(available = s3_available, version = s3_version),
      datalad = list(available = datalad_available, version = datalad_version)
    ),
    class = "openneuro_doctor"
  )

  # Print and return invisibly
  print(result)
  invisible(result)
}


#' Get AWS CLI Version
#'
#' Runs `aws --version` and parses the output to extract version string.
#'
#' @return Character string with version, or NA_character_ on failure.
#'
#' @keywords internal
.get_aws_version <- function() {
  aws_path <- .find_aws_cli()
  if (!nzchar(aws_path)) {
    return(NA_character_)
  }

  tryCatch(
    {
      result <- processx::run(
        aws_path,
        args = "--version",
        timeout = 5,
        error_on_status = FALSE
      )

      if (result$status == 0 && nzchar(result$stdout)) {
        # Parse version from output like "aws-cli/2.15.0 Python/3.11.6 ..."
        version_match <- regmatches(
          result$stdout,
          regexpr("aws-cli/([0-9]+\\.[0-9]+\\.[0-9]+)", result$stdout)
        )
        if (length(version_match) > 0) {
          return(sub("aws-cli/", "", version_match))
        }
      }
      NA_character_
    },
    error = function(e) NA_character_
  )
}


#' Get DataLad Version
#'
#' Runs `datalad --version` and parses the output to extract version string.
#'
#' @return Character string with version, or NA_character_ on failure.
#'
#' @keywords internal
.get_datalad_version <- function() {
  datalad_path <- Sys.which("datalad")
  if (!nzchar(datalad_path)) {
    return(NA_character_)
  }

  tryCatch(
    {
      result <- processx::run(
        datalad_path,
        args = "--version",
        timeout = 5,
        error_on_status = FALSE
      )

      if (result$status == 0 && nzchar(result$stdout)) {
        # Parse version from output like "datalad 0.19.3" or just "0.19.3"
        version_match <- regmatches(
          result$stdout,
          regexpr("[0-9]+\\.[0-9]+\\.[0-9]+", result$stdout)
        )
        if (length(version_match) > 0) {
          return(version_match)
        }
      }
      NA_character_
    },
    error = function(e) NA_character_
  )
}


#' Print Method for OpenNeuro Doctor
#'
#' Displays styled CLI output showing backend availability and versions.
#'
#' @param x An `openneuro_doctor` object.
#' @param ... Additional arguments (ignored).
#'
#' @return `x` invisibly.
#'
#' @export
print.openneuro_doctor <- function(x, ...) {
  cli::cli_h1("OpenNeuro Backend Status")
  cli::cli_text("")

  # Required backends section
  cli::cli_text("{.strong Required:}")

  # HTTPS is always available
  cli::cli_text("  {cli::col_green(cli::symbol$tick)} HTTPS         {.emph (always available)}")

  cli::cli_text("")

  # Optional backends section
  cli::cli_text("{.strong Optional:}")

  # S3 / AWS CLI status
  if (x$s3$available) {
    version_str <- if (!is.na(x$s3$version)) x$s3$version else "version unknown"
    cli::cli_text("  {cli::col_green(cli::symbol$tick)} AWS CLI       {.val {version_str}}")
  } else {
    cli::cli_text("  {cli::col_red(cli::symbol$cross)} AWS CLI       {.emph not installed}")
    cli::cli_text("    {.emph Install: {.url https://aws.amazon.com/cli/}}")
  }

  # DataLad status
  if (x$datalad$available) {
    version_str <- if (!is.na(x$datalad$version)) x$datalad$version else "version unknown"
    cli::cli_text("  {cli::col_green(cli::symbol$tick)} DataLad       {.val {version_str}}")
  } else {
    cli::cli_text("  {cli::col_red(cli::symbol$cross)} DataLad       {.emph not installed}")
    cli::cli_text("    {.emph Install: {.code pip install datalad}}")
  }

  invisible(x)
}

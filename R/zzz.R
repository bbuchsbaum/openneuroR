# Package load hooks and internal state

.onLoad <- function(libname, pkgname) {

  # Store package version for User-Agent header
  op <- options()
  op_openneuro <- list(
    openneuro.version = utils::packageVersion(pkgname)
  )
  toset <- !(names(op_openneuro) %in% names(op))
  if (any(toset)) options(op_openneuro[toset])

  invisible()
}

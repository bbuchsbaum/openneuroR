#' Create Lazy Handle to OpenNeuro Dataset
#'
#' Creates a lazy handle that references an OpenNeuro dataset without
#' triggering an immediate download. The handle can be fetched later
#' when the data is actually needed.
#'
#' @param dataset_id Dataset identifier (e.g., "ds000001").
#' @param tag Snapshot version tag. If NULL, uses latest snapshot when fetched.
#' @param files Character vector of specific files to download when fetched,
#'   or a regex pattern. If NULL, downloads all files when fetched.
#' @param backend Backend to use when fetching: "datalad", "s3", or "https".
#'   If NULL, auto-selects best available backend.
#'
#' @return An S3 object of class `openneuro_handle` with state "pending".
#'
#' @details
#' Handles support a lazy evaluation pattern:
#' 1. Create handle with `on_handle()` - no download occurs
#' 2. Fetch data with `on_fetch()` - download happens here
#' 3. Get path with `on_path()` - returns filesystem path
#'
#' This is useful for pipelines where dataset references need to be
#' defined early but data should only be downloaded when needed.
#'
#' @section Important:
#' S3 objects have copy semantics. You must capture the return value
#' of `on_fetch()`:
#' \preformatted{
#' # WRONG - handle not updated
#' on_fetch(handle)
#' handle$state  # Still "pending"!
#'
#' # CORRECT - capture returned handle
#' handle <- on_fetch(handle)
#' handle$state  # Now "ready"
#' }
#'
#' @export
#' @seealso [on_fetch()] to materialize the download, [on_path()] to get path.
#'
#' @examples
#' \dontrun{
#' # Create lazy handle - no download yet
#' handle <- on_handle("ds000001", files = "participants.tsv")
#' print(handle)  # Shows state: pending
#'
#' # Fetch when data is needed
#' handle <- on_fetch(handle)
#' print(handle)  # Shows state: ready
#'
#' # Get filesystem path
#' path <- on_path(handle)
#' }
on_handle <- function(dataset_id, tag = NULL, files = NULL, backend = NULL) {
  # Validate dataset_id
  if (missing(dataset_id) || !is.character(dataset_id) ||
      length(dataset_id) != 1 || nchar(dataset_id) == 0) {
    rlang::abort(
      c("Invalid dataset identifier",
        "x" = "`dataset_id` must be a non-empty character string",
        "i" = 'Example: on_handle("ds000001")'),
      class = "openneuro_validation_error"
    )
  }

  # Validate backend if provided
  if (!is.null(backend)) {
    valid_backends <- c("datalad", "s3", "https")
    if (!backend %in% valid_backends) {
      rlang::abort(
        c("Invalid backend",
          "x" = paste0("`backend` must be one of: ",
                       paste(valid_backends, collapse = ", ")),
          "i" = paste0("Got: ", backend)),
        class = "openneuro_validation_error"
      )
    }
  }

  # Create lazy handle - no download occurs here
  structure(
    list(
      dataset_id = dataset_id,
      tag = tag,
      files = files,
      backend = backend,
      state = "pending",
      path = NULL,
      fetch_time = NULL
    ),
    class = c("openneuro_handle", "list")
  )
}


#' Fetch Handle (Materialize Download)
#'
#' Materializes a lazy handle by downloading the referenced dataset.
#' If the handle is already in "ready" state, returns it unchanged
#' unless `force = TRUE`.
#'
#' @param handle An object to fetch. For `openneuro_handle` objects,
#'   triggers the download.
#' @param ... Additional arguments passed to methods.
#'
#' @return The handle with updated state. For `openneuro_handle`,
#'   returns the handle with `state = "ready"`, `path` set to the
#'   download location, and `fetch_time` set to current time.
#'
#' @section Important:
#' You must capture the return value! S3 objects have copy semantics:
#' \preformatted{
#' # CORRECT
#' handle <- on_fetch(handle)
#'
#' # WRONG - changes are lost
#' on_fetch(handle)
#' }
#'
#' @export
#' @seealso [on_handle()] to create a handle, [on_path()] to get path.
#'
#' @examples
#' \dontrun{
#' handle <- on_handle("ds000001", files = "participants.tsv")
#' handle <- on_fetch(handle)  # Downloads now
#' handle$state  # "ready"
#' }
on_fetch <- function(handle, ...) {
  UseMethod("on_fetch")
}


#' @rdname on_fetch
#' @param quiet If TRUE, suppress progress output during download.
#' @param force If TRUE, re-download even if handle is already "ready".
#' @export
on_fetch.openneuro_handle <- function(handle, quiet = FALSE, force = FALSE, ...) {
  # If already ready and not forcing, return unchanged
  if (handle$state == "ready" && !force) {
    if (!quiet) {
      cli::cli_alert_info("Handle already fetched (use force = TRUE to re-fetch)")
    }
    return(handle)
  }

  # Perform download
  result <- on_download(
    id = handle$dataset_id,
    tag = handle$tag,
    files = handle$files,
    backend = handle$backend,
    quiet = quiet,
    force = force
  )

  # Update handle state
  handle$state <- "ready"
  handle$path <- result$dest_dir
  handle$fetch_time <- Sys.time()

  handle
}


#' Get Path from Handle
#'
#' Returns the filesystem path for a fetched handle. Raises an error
#' if the handle has not been fetched yet.
#'
#' @param handle An object to get the path from. For `openneuro_handle`
#'   objects, returns the download location.
#'
#' @return Character string with the filesystem path.
#'
#' @export
#' @seealso [on_handle()] to create a handle, [on_fetch()] to materialize.
#'
#' @examples
#' \dontrun{
#' handle <- on_handle("ds000001")
#' handle <- on_fetch(handle)
#' path <- on_path(handle)
#' list.files(path)
#' }
on_path <- function(handle) {
  UseMethod("on_path")
}


#' @rdname on_path
#' @export
on_path.openneuro_handle <- function(handle) {
  if (handle$state != "ready") {
    rlang::abort(
      c("Handle not yet fetched",
        "i" = "Call on_fetch(handle) first"),
      class = "openneuro_handle_error"
    )
  }
  handle$path
}


#' Print Method for OpenNeuro Handle
#'
#' @param x An `openneuro_handle` object.
#' @param ... Additional arguments (ignored).
#'
#' @return `x` invisibly.
#'
#' @export
print.openneuro_handle <- function(x, ...) {
  cli::cli_text("{.cls openneuro_handle}")

  # Build bullet points
  bullets <- c(
    " " = "Dataset: {.val {x$dataset_id}}",
    " " = "Tag: {.val {x$tag %||% 'latest'}}",
    " " = "State: {.val {x$state}}"
  )

  # Add path or placeholder based on state
  if (x$state == "ready" && !is.null(x$path)) {
    bullets <- c(bullets, " " = "Path: {.path {x$path}}")
  } else {
    bullets <- c(bullets, " " = "Path: <not fetched>")
  }

  # Add files info if specified
  if (!is.null(x$files)) {
    if (length(x$files) == 1) {
      bullets <- c(bullets, " " = "Files: {.val {x$files}}")
    } else {
      bullets <- c(bullets, " " = "Files: {.val {length(x$files)}} specified")
    }
  }

  # Add backend if specified
  if (!is.null(x$backend)) {
    bullets <- c(bullets, " " = "Backend: {.val {x$backend}}")
  }

  cli::cli_bullets(bullets)
  invisible(x)
}

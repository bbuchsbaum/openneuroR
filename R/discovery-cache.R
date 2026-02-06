#' Discovery Session Cache
#'
#' Internal session cache for storing GitHub API results and other
#' discovery-related data. Uses closure-based caching to avoid
#' namespace lock issues when package is loaded.
#'
#' @name discovery-cache
#' @keywords internal
NULL

#' Create Discovery Cache Store
#'
#' Creates a closure-based cache store. This pattern avoids namespace
#' lock issues by capturing mutable state in a function environment
#' rather than the package namespace.
#'
#' @return A list with cache operations:
#'   \describe{
#'     \item{get(key)}{Returns cached value or NULL if not found}
#'     \item{set(key, value)}{Stores value, returns value invisibly}
#'     \item{has(key)}{Returns TRUE if key exists, FALSE otherwise}
#'     \item{clear()}{Clears all cache entries, returns TRUE invisibly}
#'   }
#'
#' @references
#' Based on R-hub blog closure caching pattern:
#' \url{https://blog.r-hub.io/2021/07/30/cache/}
#'
#' @keywords internal
.discovery_cache_store <- function() {
  # Private cache environment captured by closure
  cache <- new.env(parent = emptyenv())

  list(
    get = function(key) {
      if (exists(key, envir = cache, inherits = FALSE)) {
        get(key, envir = cache, inherits = FALSE)
      } else {
        NULL
      }
    },

    set = function(key, value) {
      assign(key, value, envir = cache)
      invisible(value)
    },

    has = function(key) {
      exists(key, envir = cache, inherits = FALSE)
    },

    clear = function() {
      rm(list = ls(cache, all.names = TRUE), envir = cache)
      invisible(TRUE)
    }
  )
}

# Initialize cache at package load time
# This creates a fresh cache for each R session
.discovery_cache <- .discovery_cache_store()

#' Clear Discovery Cache
#'
#' Clears all cached discovery data from the current session.
#' Useful for testing or when you want to force a refresh of
#' GitHub API data.
#'
#' @return Invisibly returns `TRUE`.
#'
#' @examples
#' \dontrun{
#' # Force refresh of cached data
#' .discovery_cache_clear()
#' }
#'
#' @keywords internal
.discovery_cache_clear <- function() {
  .discovery_cache$clear()
}

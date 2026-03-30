# Create Discovery Cache Store

Creates a closure-based cache store. This pattern avoids namespace lock
issues by capturing mutable state in a function environment rather than
the package namespace.

## Usage

``` r
.discovery_cache_store()
```

## Value

A list with cache operations:

- get(key):

  Returns cached value or NULL if not found

- set(key, value):

  Stores value, returns value invisibly

- has(key):

  Returns TRUE if key exists, FALSE otherwise

- clear():

  Clears all cache entries, returns TRUE invisibly

## References

Based on R-hub blog closure caching pattern:
<https://blog.r-hub.io/2021/07/30/cache/>

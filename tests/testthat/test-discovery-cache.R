# Tests for discovery-cache.R - discovery session cache

test_that(".discovery_cache_store supports get/set/has/clear", {
  cache <- .discovery_cache_store()

  expect_false(cache$has("k"))
  expect_null(cache$get("k"))

  cache$set("k", 123)
  expect_true(cache$has("k"))
  expect_equal(cache$get("k"), 123)

  cache$clear()
  expect_false(cache$has("k"))
  expect_null(cache$get("k"))
})

test_that(".discovery_cache_clear clears the global discovery cache", {
  .discovery_cache$set("tmp_key", "value")
  expect_true(.discovery_cache$has("tmp_key"))

  .discovery_cache_clear()
  expect_false(.discovery_cache$has("tmp_key"))
})


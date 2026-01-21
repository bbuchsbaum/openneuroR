# Tests for client.R - on_client() functionality

test_that("on_client creates openneuro_client object with correct class", {
  client <- on_client()
  expect_s3_class(client, "openneuro_client")
})

test_that("on_client uses default OpenNeuro API URL", {
  client <- on_client()
  expect_equal(client$url, "https://openneuro.org/crn/graphql")
})

test_that("on_client accepts custom URL", {
  custom_url <- "https://staging.openneuro.org/crn/graphql"
  client <- on_client(url = custom_url)
  expect_equal(client$url, custom_url)
})

test_that("on_client reads OPENNEURO_API_KEY env var when present", {
  withr::local_envvar(OPENNEURO_API_KEY = "test-token-12345")
  client <- on_client()
  expect_equal(client$token, "test-token-12345")
})

test_that("on_client handles missing token gracefully", {
  withr::local_envvar(OPENNEURO_API_KEY = NA)
  client <- on_client()
  expect_null(client$token)
})

test_that("on_client handles empty string token", {
  withr::local_envvar(OPENNEURO_API_KEY = "")
  client <- on_client()
  expect_null(client$token)
})

test_that("on_client explicit token overrides env var", {
  withr::local_envvar(OPENNEURO_API_KEY = "env-token")
  client <- on_client(token = "explicit-token")
  expect_equal(client$token, "explicit-token")
})

test_that("print.openneuro_client returns invisibly", {
  client <- on_client()
  # print method should return client invisibly
  result <- print(client)
  expect_identical(result, client)
})

test_that("print.openneuro_client has URL in structure", {
  client <- on_client()
  # Verify the printed client has the URL field
  expect_true("url" %in% names(client))
  expect_match(client$url, "openneuro.org")
})

test_that("on_client structure includes token field", {
  withr::local_envvar(OPENNEURO_API_KEY = NA)
  client <- on_client()
  # token field should exist (even if NULL)
  expect_true("token" %in% names(client))
})

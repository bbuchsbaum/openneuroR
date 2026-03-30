# Discovery Session Cache

Internal session cache for storing GitHub API results and other
discovery-related data. Uses closure-based caching to avoid namespace
lock issues when package is loaded.

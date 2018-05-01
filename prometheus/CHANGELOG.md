# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


## [1.0.0] - 2018-01-10
### Added
- Support for counter, gauge and histogram metrics
- Exporting metrics to a prometheus plaintext format
- Serving metrics via tarantool 'http' module
- Collecting basic tarantool stats: memory, request count and tuple counts by space
- Luarock-based packaging
- Basic unit tests

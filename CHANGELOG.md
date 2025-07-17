# Changelog

## [Unreleased]

### Added

- `Regexp::match_` : return a `MatchResult?` for better experience
- `MatchResult::before` and `MatchResult::after` : getting both sides of matched
  value, similar to partition

### Changed

- `Regexp::execute_with_remainder` is deprecated as the semantic is confusing.
  Use `Regexp::execute` together with `MatchResult::before` and
  `MatchResult::after` instead.

## [0.3.0]

### Changed

- `MatchResult::groups` now returns `Map[String, @string.View]` instead of
  `Map[String, @string.View?]` to avoid the extra wrap.

### Fixed

- The case insensitive check for `A-Z` did not include `a-z` correctly.

## [0.2.1]

### Changed

- Updated syntax to 0.6.20

### Fixed

- Updated code in `prebuild` to use the updated API

## [0.2.0]

### Changed

- Renamed `Error_` to `RegexpError`, and renamed field `data` to
  `source_fragment`.
- Renamed `Engine` to `Regexp`.
- Renamed `MatchResult::group` to `MatchResult::get`.
- Replaced `MatchResult::group_by_name` with `MatchResult::results` that returns
  a whole `Map`.
- `MatchResult::results` now returns an `Array` instead of `Iter`.
- `Regexp::group_names` now returns an `Array` instead of `Iter`.
- Replaced `MatchResult::rest` with `Regexp::execute_with_remainder`.

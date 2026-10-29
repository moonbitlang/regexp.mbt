# Changelog

## [Unreleased]

### Changed

- Migrate the Unicode 16.0.0 table generator to native MoonBit with pinned,
  checksum-verified inputs and CI regeneration checks. Generated tables and
  regexp behavior are unchanged.
- Replace the deprecated module `exclude` setting with `.moonignore`.

## [0.3.6]

### Changed

- Updated to moon 0.1.20261012: `Int32`/`UInt32` spelling, manifests migrated
  to `moon.mod`/`moon.pkg`, deprecated APIs replaced. Tests and README examples
  use `debug_inspect`; the printed text of `RegexpError` is unchanged.
- CI now fails on warnings (`moon check --deny-warn`).

## [0.3.5]

### Changed

- The unicode data are now stored as `Map` again thanks to the compiler's
  improvement (#11)
- Updated syntax to v0.7.2 (#15)

## [0.3.4]

### Fixed

- #8 made the RegexpError abstract to the users. (#10)

## [0.3.3]

### Changed

- The internal structure is reorganized. (#8)
- The escaped surrogates are no longer allowed. (#9)
- Updated syntax to v0.6.30+07d9d2445. (#9)

## [0.3.2]

### Changed

- The unicode data are now stored as `String` to improve the native build time.
  (#6)

### Fixed

- The escaped chars in char class ranges were incorrectly handled as single
  characters. (#7)

## [0.3.1]

### Added

- `Regexp::match_` : return a `MatchResult?` for better experience
- `MatchResult::before` and `MatchResult::after` : getting both sides of matched
  value, similar to partition

### Changed

- `Regexp::execute_with_remainder` is deprecated as the semantic is confusing.
  Use `Regexp::execute` together with `MatchResult::before` and
  `MatchResult::after` instead.
- Updated syntax to v0.6.24+012953835 (#4)

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

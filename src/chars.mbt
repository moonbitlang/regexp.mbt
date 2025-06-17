// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///|
fn is_word_char(c : Char) -> Bool {
  // Check if the character is a word character (alphanumeric or underscore)
  return (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_'
}

///|
/// Use binary search to check if a character is within any of the ranges.
/// The chars array contains pairs of characters [start1, end1, start2, end2, ...] 
/// representing ranges [start1-end1], [start2-end2], etc.
/// Assumes the ranges are sorted and non-overlapping.
fn char_in_ranges(ch : Char, chars : Array[Char]) -> Bool {
  let mut left = 0
  let mut right = chars.length() / 2 - 1
  while left <= right {
    let mid = (left + right) / 2
    let start = chars[mid * 2]
    let end = chars[mid * 2 + 1]
    if ch < start {
      right = mid - 1
    } else if ch > end {
      left = mid + 1
    } else {
      // ch is within the range [start, end]
      return true
    }
  }
  return false
}

///|
/// Simplifies a character class by merging overlapping ranges and removing duplicates.
/// Input: Array of characters representing ranges [start1, end1, start2, end2, ...]
/// Output: Simplified array with non-overlapping ranges in sorted order
fn simplify_char_ranges(chars : Array[Char]) -> Array[Char] {
  if chars.length() == 0 {
    return []
  }

  // Convert chars to array of ranges (start, end) pairs
  let ranges = []
  for i = 0; i < chars.length(); i = i + 2 {
    let start = chars[i]
    let end = chars[i + 1]
    ranges.push((start, end))
  }
  if ranges.length() == 0 {
    return []
  }

  // Sort ranges by start character
  ranges.sort_by_key(range => range.0)

  // Simplify ranges by merging overlapping or adjacent ranges
  let simplified = []
  let mut current_start = '\u{0}'
  let mut current_end = '\u{0}'
  if ranges.length() > 0 {
    current_start = ranges[0].0
    current_end = ranges[0].1
    for range in ranges[1:] {
      let (next_start, next_end) = range

      // Check if ranges overlap or are adjacent
      if next_start <= (current_end.to_int() + 1).unsafe_to_char() {
        // Merge ranges
        current_end = if current_end > next_end {
          current_end
        } else {
          next_end
        }
      } else {
        // Add current range to result and start new range
        simplified.push(current_start)
        simplified.push(current_end)
        current_start = next_start
        current_end = next_end
      }
    }

    // Add the last range
    simplified.push(current_start)
    simplified.push(current_end)
  }
  simplified
}

///|
/// Computes the complement of a character class.
/// Input: Array of characters representing ranges [start1, end1, start2, end2, ...]
/// Output: Array representing the complement ranges
fn compute_char_class_complement(chars : Array[Char]) -> Array[Char] {
  // First simplify the input ranges
  let simplified = simplify_char_ranges(chars)
  if simplified.length() == 0 {
    // Empty character class, complement is everything
    return ['\u{0}', '\u{10FFFF}']
  }
  let complement = []
  let min_char = '\u{0}'
  let max_char = '\u{10FFFF}'

  // Add range before first range if it doesn't start at minimum
  if simplified[0] > min_char {
    complement.push(min_char)
    complement.push((simplified[0].to_int() - 1).unsafe_to_char())
  }

  // Add gaps between ranges
  for i = 0; i < simplified.length() / 2 - 1; i = i + 1 {
    let current_end = simplified[i * 2 + 1]
    let next_start = simplified[(i + 1) * 2]
    let gap_start = (current_end.to_int() + 1).unsafe_to_char()
    let gap_end = (next_start.to_int() - 1).unsafe_to_char()
    if gap_start <= gap_end {
      complement.push(gap_start)
      complement.push(gap_end)
    }
  }

  // Add range after last range if it doesn't end at maximum
  let last_end = simplified[simplified.length() - 1]
  if last_end < max_char {
    complement.push((last_end.to_int() + 1).unsafe_to_char())
    complement.push(max_char)
  }
  complement
}

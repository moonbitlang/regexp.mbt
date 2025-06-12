///|
enum Regex {
  Empty
  Literal(String)
  /// Anything that can be interpreted as range (inclusive) pair list, e.g. `.` (0..=0x10FFFF)
  CharClass(Array[Char], neg~ : Bool)
  Assertion(Predicate)
  Capture(Regex, name~ : String?)
  ZeroOrMore(Regex, lazy~ : Bool)
  OneOrMore(Regex, lazy~ : Bool)
  ZeroOrOne(Regex, lazy~ : Bool)
  /// Matches a specific number of repetitions.
  Repeat(Regex, lazy~ : Bool, min~ : UInt, max~ : UInt?)
  Concat(Array[Regex])
  Alternate(Regex, Regex)
} derive(Show)

///|
struct Matcher {
  instructions : Array[Instruction]
  map : Map[String, Int]
  mut capture : Int
}

///|
/// Returns the result of capture groups. e.g. [0, 4, 0, 4] for `(abc)` matching `abc`.
/// 
/// If it is empty, it means that the regex did not match.
pub fn Matcher::execute(self : Matcher, input : @string.View) -> Array[Int] {
  vm(self.instructions, input, self.capture)
}

///|
/// @returns next capture
fn Regex::compile_aux(regex : Self, matcher : Matcher) -> Unit {
  let { instructions, capture, .. } = matcher
  match regex {
    Empty => ()
    Literal(s) =>
      for ch in s {
        instructions.push(Char([ch, ch]))
      }
    CharClass(chars, neg~) =>
      if neg {
        // compute the complement of the character class
        let complement = compute_char_class_complement(chars)
        instructions.push(Char(complement))
      } else {
        instructions.push(Char(chars))
      }
    Assertion(pred) => instructions.push(Assertion(pred))
    Capture(inner, name~) => {
      if name is Some(name) {
        guard matcher.map.get(name) is None
        matcher.map[name] = capture
      }
      instructions.push(Save(capture * 2))
      matcher.capture += 1
      inner.compile_aux(matcher)
      instructions.push(Save(capture * 2 + 1))
    }
    ZeroOrMore(inner, lazy~) => {
      // [ ..., split, inner, jmp, ... ]
      //          ^ -- instructions.length() at the beginning
      //                            ^ -- instructions.length() at the end
      let split_pos = instructions.length()
      // placeholder for split
      instructions.push(Split(-1, -1))
      inner.compile_aux(matcher)
      instructions.push(Jump(split_pos))
      if lazy {
        instructions[split_pos] = Split(instructions.length(), split_pos + 1)
      } else {
        instructions[split_pos] = Split(split_pos + 1, instructions.length())
      }
    }
    OneOrMore(inner, lazy~) => {
      // [ ..., inner, split, inner, jmp, ... ]
      //                  ^ -- instructions.length() at the beginning
      //                                   ^ -- instructions.length() at the end
      inner.compile_aux(matcher)
      let split_pos = instructions.length()
      // placeholder for split
      instructions.push(Split(-1, -1))
      matcher.capture = capture
      inner.compile_aux(matcher)
      instructions.push(Jump(split_pos))
      if lazy {
        instructions[split_pos] = Split(instructions.length(), split_pos + 1)
      } else {
        instructions[split_pos] = Split(split_pos + 1, instructions.length())
      }
    }
    ZeroOrOne(inner, lazy~) => {
      // [ ..., split, inner, ... ]
      //          ^ -- instructions.length() at the beginning
      //                        ^ -- instructions.length() at the end
      let split_pos = instructions.length()
      // for taking up position
      instructions.push(Split(-1, -1))
      inner.compile_aux(matcher)
      if lazy {
        instructions[split_pos] = Split(instructions.length(), split_pos + 1)
      } else {
        instructions[split_pos] = Split(split_pos + 1, instructions.length())
      }
    }
    Repeat(lazy~, min~, max~, inner) =>
      if max is Some(max) {
        // [ ..., inner * min, [ split, inner ] * (max - min), ... ]
        for i in 0U..<min {
          matcher.capture = capture
          inner.compile_aux(matcher)
        }
        let split_pos = []
        for i in 0U..<(max - min) {
          // placeholder for split
          split_pos.push(instructions.length())
          instructions.push(Split(-1, -1))
          matcher.capture = capture
          inner.compile_aux(matcher) |> ignore
        }
        let jmp_pos = instructions.length()
        if lazy {
          for pos in split_pos {
            instructions[pos] = Split(jmp_pos, pos + 1)
          }
        } else {
          for pos in split_pos {
            instructions[pos] = Split(pos + 1, jmp_pos)
          }
        }
      } else {
        // [ ..., inner * min, split, inner, jmp, ... ]
        //                      ^ -- instructions.length() at the beginning
        //                                         ^ -- instructions.length() at the end
        for i in 0U..<min {
          matcher.capture = capture
          inner.compile_aux(matcher)
        }
        let split_pos = instructions.length()
        // placeholder for split
        instructions.push(Split(-1, -1))
        matcher.capture = capture
        inner.compile_aux(matcher)
        instructions.push(Jump(split_pos))
        if lazy {
          instructions[split_pos] = Split(instructions.length(), split_pos + 1)
        } else {
          instructions[split_pos] = Split(split_pos + 1, instructions.length())
        }
      }
    Concat(regexs) =>
      for regex in regexs {
        regex.compile_aux(matcher)
      }
    Alternate(left, right) => {
      // [ ..., split, left, jmp, right, ... ]
      //          ^ -- instructions.length() at the beginning
      //                      ^ -- instructions.length() at the middle
      //                                   ^ -- instructions.length() at the end
      let split_pos = instructions.length()
      // for taking up position
      instructions.push(Split(-1, -1))
      left.compile_aux(matcher)
      let { capture: next_capture, .. } = matcher
      let jmp_pos = instructions.length()
      // placeholder for jump
      instructions.push(Jump(-1))
      matcher.capture = capture
      right.compile_aux(matcher)
      instructions[split_pos] = Split(split_pos + 1, jmp_pos + 1)
      instructions[jmp_pos] = Jump(instructions.length())
      matcher.capture = @math.maximum(next_capture, matcher.capture)
    }
  }
}

///|
/// Compiles a regex into a matcher.
pub fn Regex::compile(self : Self) -> Matcher {
  // for leftmost matching
  let instructions = [Split(3, 1), Char(['\u{0}', '\u{10FFFF}']), Jump(0)]
  // start matching
  instructions.push(Save(0))
  let matcher = { instructions, map: {}, capture: 1 }
  self.compile_aux(matcher)
  instructions.push(Save(1))
  instructions.push(Matched)
  matcher
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

  // Sort ranges by start character using a simple bubble sort
  for i = 0; i < ranges.length() - 1; i = i + 1 {
    for j = 0; j < ranges.length() - 1 - i; j = j + 1 {
      let (start_j, _) = ranges[j]
      let (start_j1, _) = ranges[j + 1]
      if start_j > start_j1 {
        let temp = ranges[j]
        ranges[j] = ranges[j + 1]
        ranges[j + 1] = temp
      }
    }
  }
  let simplified = []
  let mut current_start = '\u{0}'
  let mut current_end = '\u{0}'
  if ranges.length() > 0 {
    current_start = ranges[0].0
    current_end = ranges[0].1
    for i = 1; i < ranges.length(); i = i + 1 {
      let (next_start, next_end) = ranges[i]

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

///|
test "literal" {
  let regex = Regex::Literal("abc".to_string())
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
}

///|
test "char_class" {
  // ([ac])
  let regex = Regex::ZeroOrMore(
    Regex::CharClass(['a', 'c'], neg=false),
    lazy=false,
  )
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
  // ([a])
  let regex = Regex::ZeroOrMore(
    Regex::CharClass(['a', 'a'], neg=false),
    lazy=false,
  )
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 1]")
  // ([^ac])
  let regex = Regex::ZeroOrMore(
    Regex::CharClass(['a', 'c'], neg=true),
    lazy=false,
  )
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 0]")
}

///|
test "capture" {
  let regex = Regex::Capture(Regex::Literal("abc".to_string()), name=None)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3, 0, 3]")
  let regex = Regex::Capture(
    Regex::Literal("abc".to_string()),
    name=Some("group1"),
  )
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3, 0, 3]")
  inspect(
    "abc".view(
      start_offset=result[map.get("group1").unwrap() * 2],
      end_offset=result[map.get("group1").unwrap() * 2 + 1],
    ),
    content="abc",
  )
}

///|
test "zero_or_more" {
  let regex = Regex::ZeroOrMore(Regex::Literal("abc".to_string()), lazy=false)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcabcab".view(), capture_count)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[0, 0]")
  let regex = Regex::ZeroOrMore(Regex::Literal("abc".to_string()), lazy=true)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcabcab".view(), capture_count)
  inspect(result, content="[0, 0]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[0, 0]")
}

///|
test "one_or_more" {
  let regex = Regex::OneOrMore(Regex::Literal("abc".to_string()), lazy=false)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcabcab".view(), capture_count)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[]")
  let regex = Regex::OneOrMore(Regex::Literal("abc".to_string()), lazy=true)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcabcab".view(), capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[]")
}

///|
test "zero_or_one" {
  let regex = Regex::ZeroOrOne(Regex::Literal("abc".to_string()), lazy=false)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[0, 0]")
  let regex = Regex::ZeroOrOne(Regex::Literal("abc".to_string()), lazy=true)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 0]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[0, 0]")
}

///|
test "repeat" {
  let regex = Regex::Repeat(
    min=2,
    max=Some(4),
    Regex::Literal("abc".to_string()),
    lazy=false,
  )
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcabcabcabc".view(), capture_count)
  inspect(result, content="[0, 12]")
  let result = vm(instructions, "abcabc".view(), capture_count)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[]")
  let regex = Regex::Repeat(
    min=2,
    max=Some(4),
    Regex::Literal("abc".to_string()),
    lazy=true,
  )
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcabcabcabc".view(), capture_count)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "abcabc".view(), capture_count)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[]")
}

///|
test "concat" {
  let regex = Regex::Concat([
    Regex::Literal("abc".to_string()),
    Regex::Literal("def".to_string()),
  ])
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcdef".view(), capture_count)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[]")
}

///|
test "alternate" {
  let regex = Regex::Alternate(
    Regex::Literal("abc".to_string()),
    Regex::Literal("def".to_string()),
  )
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "def".view(), capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "xyz".view(), capture_count)
  inspect(result, content="[]")
}

///|
test "empty" {
  let regex = Regex::Alternate(Regex::Literal("abc".to_string()), Regex::Empty)
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "xyz".view(), capture_count)
  inspect(result, content="[0, 0]")
}

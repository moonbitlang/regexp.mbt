///|
enum Regex {
  Empty
  Literal(String)
  /// Anything that can be interpreted as range (inclusive) pair list, e.g. `.` (0..=0x10FFFF)
  CharClass(Array[Char])
  Capture(Regex)
  ZeroOrMore(Regex)
  OneOrMore(Regex)
  ZeroOrOne(Regex)
  /// Matches a specific number of repetitions.
  Repeat(min~ : UInt, max~ : UInt?, Regex)
  Concat(Array[Regex])
  Alternate(Regex, Regex)
} derive(Show)

///|
struct Matcher {
  instructions : Array[Instruction]
  capture_count : Int
}

///|
/// Returns the result of capture groups. e.g. [0, 4, 0, 4] for `(abc)` matching `abc`.
/// 
/// If it is empty, it means that the regex did not match.
pub fn Matcher::execute(self : Matcher, input : @string.View) -> Array[Int] {
  vm(self.instructions, input, self.capture_count)
}

///|
/// @returns next capture
fn Regex::compile_aux(
  regex : Self,
  capture : Int,
  target : Array[Instruction]
) -> Int {
  match regex {
    Empty => return capture
    Literal(s) => {
      for ch in s {
        target.push(Char([ch, ch]))
      }
      return capture
    }
    CharClass(chars) => {
      target.push(Char(chars))
      return capture
    }
    Capture(inner) => {
      target.push(Save(capture * 2))
      let next_capture = inner.compile_aux(capture + 1, target)
      target.push(Save(capture * 2 + 1))
      next_capture
    }
    ZeroOrMore(inner) => {
      // [ ..., split, inner, jmp, ... ]
      //          ^ -- target.length() at the beginning
      //                            ^ -- target.length() at the end
      let split_pos = target.length()
      // placeholder for split
      target.push(Split(-1, -1))
      let next_capture = inner.compile_aux(capture, target)
      target.push(Jump(split_pos))
      target[split_pos] = Split(split_pos + 1, target.length())
      next_capture
    }
    OneOrMore(inner) => {
      // [ ..., inner, split, inner, jmp, ... ]
      //                  ^ -- target.length() at the beginning
      //                                   ^ -- target.length() at the end
      let _ = inner.compile_aux(capture, target)
      let split_pos = target.length()
      // placeholder for split
      target.push(Split(-1, -1))
      let next_capture = inner.compile_aux(capture, target)
      target.push(Jump(split_pos))
      target[split_pos] = Split(split_pos + 1, target.length())
      next_capture
    }
    ZeroOrOne(inner) => {
      // [ ..., split, inner, ... ]
      //          ^ -- target.length() at the beginning
      //                        ^ -- target.length() at the end
      let split_pos = target.length()
      // for taking up position
      target.push(Split(-1, -1))
      let next_capture = inner.compile_aux(capture, target)
      target[split_pos] = Split(split_pos + 1, target.length())
      next_capture
    }
    Repeat(min~, max~, inner) =>
      if max is Some(max) {
        // [ ..., inner * min, [ split, inner ] * (max - min), ... ]
        for i in 0U..<min {
          inner.compile_aux(capture, target) |> ignore
        }
        let split_pos = []
        for i in 0U..<(max - min) {
          // placeholder for split
          split_pos.push(target.length())
          target.push(Split(-1, -1))
          inner.compile_aux(capture, target) |> ignore
        }
        let jmp_pos = target.length()
        for pos in split_pos {
          target[pos] = Split(pos + 1, jmp_pos)
        }
        inner.compile_aux(capture, [])
      } else {
        // [ ..., inner * min, split, inner, jmp, ... ]
        //                      ^ -- target.length() at the beginning
        //                                         ^ -- target.length() at the end
        for i in 0U..<min {
          inner.compile_aux(capture, target) |> ignore
        }
        let split_pos = target.length()
        // placeholder for split
        target.push(Split(-1, -1))
        let next_capture = inner.compile_aux(capture, target)
        target.push(Jump(split_pos))
        target[split_pos] = Split(split_pos + 1, target.length())
        next_capture
      }
    Concat(regexs) => {
      let mut next_capture = capture
      for regex in regexs {
        next_capture = regex.compile_aux(next_capture, target)
      }
      next_capture
    }
    Alternate(left, right) => {
      // [ ..., split, left, jmp, right, ... ]
      //          ^ -- target.length() at the beginning
      //                      ^ -- target.length() at the middle
      //                                   ^ -- target.length() at the end
      let split_pos = target.length()
      // for taking up position
      target.push(Split(-1, -1))
      let next_capture = left.compile_aux(capture, target)
      let jmp_pos = target.length()
      // placeholder for jump
      target.push(Jump(-1))
      let next_capture2 = right.compile_aux(capture, target)
      target[split_pos] = Split(split_pos + 1, jmp_pos + 1)
      target[jmp_pos] = Jump(target.length())
      @math.maximum(next_capture, next_capture2)
    }
  }
}

///|
/// Compiles a regex into a matcher.
pub fn Regex::compile(self : Self) -> Matcher {
  let instructions = []
  instructions.push(Save(0))
  let capture_count = self.compile_aux(1, instructions)
  instructions.push(Save(1))
  instructions.push(Matched)
  { instructions, capture_count }
}

///|
test "literal" {
  let regex = Regex::Literal("abc".to_string())
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
}

///|
test "char_class" {
  let regex = Regex::ZeroOrMore(Regex::CharClass(['a', 'c']))
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
  let regex = Regex::ZeroOrMore(Regex::CharClass(['a', 'a']))
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 1]")
}

///|
test "capture" {
  let regex = Regex::Capture(Regex::Literal("abc".to_string()))
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3, 0, 3]")
}

///|
test "zero_or_more" {
  let regex = Regex::ZeroOrMore(Regex::Literal("abc".to_string()))
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abcabcab".view(), capture_count)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[0, 0]")
}

///|
test "one_or_more" {
  let regex = Regex::OneOrMore(Regex::Literal("abc".to_string()))
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abcabcab".view(), capture_count)
  inspect(result, content="[0, 6]")
  let regex = Regex::OneOrMore(Regex::Literal("abc".to_string()))
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[]")
}

///|
test "zero_or_one" {
  let regex = Regex::ZeroOrOne(Regex::Literal("abc".to_string()))
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "ab".view(), capture_count)
  inspect(result, content="[0, 0]")
}

///|
test "repeat" {
  let regex = Regex::Repeat(
    min=2,
    max=Some(4),
    Regex::Literal("abc".to_string()),
  )
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abcabcabcabc".view(), capture_count)
  inspect(result, content="[0, 12]")
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
  let { instructions, capture_count } = regex.compile()
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
  let { instructions, capture_count } = regex.compile()
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
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "abc".view(), capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "xyz".view(), capture_count)
  inspect(result, content="[0, 0]")
}

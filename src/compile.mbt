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
priv enum Regex {
  Empty
  Literal(String)
  /// Anything that can be interpreted as range (inclusive) pair list, e.g. `.` (0..=0x10FFFF)
  CharClass(Array[Char], neg~ : Bool)
  Assertion(Predicate)
  Capture(Regex, index~ : Int)
  ZeroOrMore(Regex, greedy~ : Bool)
  OneOrMore(Regex, greedy~ : Bool)
  ZeroOrOne(Regex, greedy~ : Bool)
  /// Matches a specific number of repetitions.
  Repeat(Regex, greedy~ : Bool, min~ : UInt, max~ : UInt?)
  Concat(Array[Regex])
  Alternate(Regex, Regex)
  Backreference(Int)
} derive(Show)

///|
impl ToJson for Regex with to_json(self) {
  match self {
    Empty => "Empty"
    Literal(s) => ["Literal", s]
    CharClass(chars, neg~) => ["CharClass neg=\{neg}", chars.map(c => repr(c))]
    Assertion(pred) => "Assertion \{pred}"
    Capture(inner, index~) => ["Capture \{index}", inner]
    ZeroOrMore(inner, greedy~) => ["ZeroOrMore greedy=\{greedy}", inner]
    OneOrMore(inner, greedy~) => ["OneOrMore greedy=\{greedy}", inner]
    ZeroOrOne(inner, greedy~) => ["ZeroOrOne greedy=\{greedy}", inner]
    Repeat(greedy~, min~, max~, inner) =>
      if max is Some(max) {
        ["Repeat {\{min}, \{max}} greedy=\{greedy}", inner]
      } else {
        ["Repeat {\{min},} greedy=\{greedy}", inner]
      }
    Concat(regexs) => [..regexs.map(_.to_json())]
    Alternate(left, right) => ["Alternate", left, right]
    Backreference(i) => ["Backreference", i]
  }
}

///|
struct Engine {
  instructions : Array[Instruction]
  map : Map[String, Int]
  capture : Int
}

///|
/// @returns next capture
fn Regex::compile_aux(regex : Self, instructions : Array[Instruction]) -> Unit {
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
        // simplify and sort the character ranges for binary search
        let simplified = simplify_char_ranges(chars)
        instructions.push(Char(simplified))
      }
    Assertion(pred) => instructions.push(Assertion(pred))
    Capture(inner, index=capture) => {
      instructions.push(Save(capture * 2))
      inner.compile_aux(instructions)
      instructions.push(Save(capture * 2 + 1))
    }
    ZeroOrMore(inner, greedy~) => {
      // Compiles to (a+)?
      // See https://github.com/golang/go/issues/46123
      // [ ..., split, inner, split, ... ]
      //          ^ -- instructions.length() at the beginning
      //                            ^ -- instructions.length() at the end
      let split_pos = instructions.length()
      // placeholder for split
      instructions.push(Split(-1, -1))
      inner.compile_aux(instructions)
      let next_pos = instructions.length()
      if not(greedy) {
        instructions.push(Split(next_pos + 1, split_pos + 1))
        instructions[split_pos] = Split(next_pos + 1, split_pos + 1)
      } else {
        instructions.push(Split(split_pos + 1, next_pos + 1))
        instructions[split_pos] = Split(split_pos + 1, next_pos + 1)
      }
    }
    OneOrMore(inner, greedy~) => {
      // [ ..., inner, split, ... ]
      //         ^ -- instructions.length() at the beginning
      let jmp_pos = instructions.length()
      inner.compile_aux(instructions)
      let next_pos = instructions.length()
      if not(greedy) {
        instructions.push(Split(next_pos + 1, jmp_pos))
      } else {
        instructions.push(Split(jmp_pos, next_pos + 1))
      }
    }
    ZeroOrOne(inner, greedy~) => {
      // [ ..., split, inner, ... ]
      //          ^ -- instructions.length() at the beginning
      //                        ^ -- instructions.length() at the end
      let split_pos = instructions.length()
      // for taking up position
      instructions.push(Split(-1, -1))
      inner.compile_aux(instructions)
      if not(greedy) {
        instructions[split_pos] = Split(instructions.length(), split_pos + 1)
      } else {
        instructions[split_pos] = Split(split_pos + 1, instructions.length())
      }
    }
    Repeat(greedy~, min~, max~, inner) =>
      if max is Some(max) {
        // [ ..., inner * min, [ split, inner ] * (max - min), ... ]
        for i in 0U..<min {
          inner.compile_aux(instructions)
        }
        let split_pos = []
        for i in 0U..<(max - min) {
          // placeholder for split
          split_pos.push(instructions.length())
          instructions.push(Split(-1, -1))
          inner.compile_aux(instructions) |> ignore
        }
        let jmp_pos = instructions.length()
        if not(greedy) {
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
          inner.compile_aux(instructions)
        }
        let split_pos = instructions.length()
        // placeholder for split
        instructions.push(Split(-1, -1))
        inner.compile_aux(instructions)
        instructions.push(Jump(split_pos))
        if not(greedy) {
          instructions[split_pos] = Split(instructions.length(), split_pos + 1)
        } else {
          instructions[split_pos] = Split(split_pos + 1, instructions.length())
        }
      }
    Concat(regexs) =>
      for regex in regexs {
        regex.compile_aux(instructions)
      }
    Alternate(left, right) => {
      // [ ..., split, left, jmp, right, ... ]
      //          ^ -- instructions.length() at the beginning
      //                      ^ -- instructions.length() at the middle
      //                                   ^ -- instructions.length() at the end
      let split_pos = instructions.length()
      // for taking up position
      instructions.push(Split(-1, -1))
      left.compile_aux(instructions)
      let jmp_pos = instructions.length()
      // placeholder for jump
      instructions.push(Jump(-1))
      right.compile_aux(instructions)
      instructions[split_pos] = Split(split_pos + 1, jmp_pos + 1)
      instructions[jmp_pos] = Jump(instructions.length())
    }
    Backreference(i) => instructions.push(Backreference(i))
  }
}

///|
fn Regex::compile(self : Regex) -> Array[Instruction] {
  // for leftmost matching
  let instructions = [Split(3, 1), Char(['\u{0}', '\u{10FFFF}']), Jump(0)]
  // start matching
  instructions.push(Save(0))
  self.compile_aux(instructions)
  instructions.push(Save(1))
  instructions.push(Matched)
  instructions
}

///|
/// Compiles a regex into a matcher.
fn ParseResult::compile(self : Self) -> Engine {
  {
    instructions: self.ast.compile(),
    map: self.capture_map,
    capture: self.captures,
  }
}

///|
test "literal" {
  let regex = Regex::Literal("abc".to_string())
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 3]")
}

///|
test "char_class" {
  // ([ac])
  let regex = Regex::ZeroOrMore(
    Regex::CharClass(['a', 'c'], neg=false),
    greedy=true,
  )
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 3]")
  // ([a])
  let regex = Regex::ZeroOrMore(
    Regex::CharClass(['a', 'a'], neg=false),
    greedy=true,
  )
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 1]")
  // ([^ac])
  let regex = Regex::ZeroOrMore(
    Regex::CharClass(['a', 'c'], neg=true),
    greedy=true,
  )
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 0]")
}

///|
test "capture" {
  let regex = Regex::Capture(Regex::Literal("abc".to_string()), index=1)
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 2)
  inspect(result, content="[0, 3, 0, 3]")
  inspect(
    "abc".view(start_offset=result[1 * 2], end_offset=result[1 * 2 + 1]),
    content="abc",
  )
}

///|
test "zero_or_more" {
  let regex = Regex::ZeroOrMore(Regex::Literal("abc".to_string()), greedy=true)
  let instructions = regex.compile()
  let result = vm(instructions, "abcabcab".view(), 1)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), 1)
  inspect(result, content="[0, 0]")
  let regex = Regex::ZeroOrMore(Regex::Literal("abc".to_string()), greedy=false)
  let instructions = regex.compile()
  let result = vm(instructions, "abcabcab".view(), 1)
  inspect(result, content="[0, 0]")
  let result = vm(instructions, "ab".view(), 1)
  inspect(result, content="[0, 0]")
}

///|
test "one_or_more" {
  let regex = Regex::OneOrMore(Regex::Literal("abc".to_string()), greedy=true)
  let instructions = regex.compile()
  let result = vm(instructions, "abcabcab".view(), 1)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), 1)
  inspect(result, content="[]")
  let regex = Regex::OneOrMore(Regex::Literal("abc".to_string()), greedy=false)
  let instructions = regex.compile()
  let result = vm(instructions, "abcabcab".view(), 1)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "ab".view(), 1)
  inspect(result, content="[]")
}

///|
test "zero_or_one" {
  let regex = Regex::ZeroOrOne(Regex::Literal("abc".to_string()), greedy=true)
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "ab".view(), 1)
  inspect(result, content="[0, 0]")
  let regex = Regex::ZeroOrOne(Regex::Literal("abc".to_string()), greedy=false)
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 0]")
  let result = vm(instructions, "ab".view(), 1)
  inspect(result, content="[0, 0]")
}

///|
test "repeat" {
  let regex = Regex::Repeat(
    min=2,
    max=Some(4),
    Regex::Literal("abc".to_string()),
    greedy=true,
  )
  let instructions = regex.compile()
  let result = vm(instructions, "abcabcabcabc".view(), 1)
  inspect(result, content="[0, 12]")
  let result = vm(instructions, "abcabc".view(), 1)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "ab".view(), 1)
  inspect(result, content="[]")
}

///|
test "concat" {
  let regex = Regex::Concat([
    Regex::Literal("abc".to_string()),
    Regex::Literal("def".to_string()),
  ])
  let instructions = regex.compile()
  let result = vm(instructions, "abcdef".view(), 1)
  inspect(result, content="[0, 6]")
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[]")
}

///|
test "alternate" {
  let regex = Regex::Alternate(
    Regex::Literal("abc".to_string()),
    Regex::Literal("def".to_string()),
  )
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "def".view(), 1)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "xyz".view(), 1)
  inspect(result, content="[]")
}

///|
test "empty" {
  let regex = Regex::Alternate(Regex::Literal("abc".to_string()), Regex::Empty)
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "xyz".view(), 1)
  inspect(result, content="[0, 0]")

  /// Reversed
  let regex = Regex::Alternate(Regex::Empty, Regex::Literal("abc".to_string()))
  let instructions = regex.compile()
  let result = vm(instructions, "abc".view(), 1)
  inspect(result, content="[0, 0]")
}

///|
test "alternate capture" {
  let regex = OneOrMore(
    Alternate(
      Capture(CharClass(['a', 'a'], neg=false), index=1),
      Capture(CharClass(['b', 'b'], neg=false), index=2),
    ),
    greedy=true,
  )
  @json.inspect(regex.compile(), content=[
    ["Split", 3, 1],
    ["Chars", ["'\\u{00}'", "'\\u{10ffff}'"]],
    ["Jump", 0],
    ["Save", 0],
    ["Split", 5, 9],
    ["Save", 2],
    ["Chars", ["'a'", "'a'"]],
    ["Save", 3],
    ["Jump", 12],
    ["Save", 4],
    ["Chars", ["'b'", "'b'"]],
    ["Save", 5],
    ["Split", 4, 13],
    ["Save", 1],
    "Matched",
  ])
}

///|
test "backreference" {
  let regex = Concat([
    Capture(
      ZeroOrMore(Alternate(Literal("a"), Literal("b")), greedy=true),
      index=1,
    ),
    Backreference(1),
    Backreference(1),
  ])
  @json.inspect(regex.compile(), content=[
    ["Split", 3, 1],
    ["Chars", ["'\\u{00}'", "'\\u{10ffff}'"]],
    ["Jump", 0],
    ["Save", 0],
    ["Save", 2],
    ["Split", 6, 11],
    ["Split", 7, 9],
    ["Chars", ["'a'", "'a'"]],
    ["Jump", 10],
    ["Chars", ["'b'", "'b'"]],
    ["Split", 6, 11],
    ["Save", 3],
    ["Backreference", 1],
    ["Backreference", 1],
    ["Save", 1],
    "Matched",
  ])
}

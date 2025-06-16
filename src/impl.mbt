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
priv enum Instruction {
  Matched
  Save(Int)
  Char(Array[Char])
  Jump(Int)
  Split(Int, Int)
  /// Zero-width assertions
  Assertion(Predicate)
} derive(Show)

///|
priv enum Predicate {
  BeginText
  EndText
  BeginLine
  EndLine
  WordBoundary
  NoWordBoundary
} derive(Show)

///|
/// A thread represents a point in the execution of the VM.
/// It contains the program counter (pc) and an array of captures.
priv struct Thread {
  pc : Int
  captures : Array[Int]
}

///|
/// Add a thread to the list of threads to be processed.
/// 
/// @param sp the current position in the input string  
/// @param content the input string  
/// @param instructions the list of instructions to execute  
/// @param gen the generation number for the instruction  
/// @param inst_gen an array to track the generation of each instruction  
/// @param thread the current thread to add  
/// @param clist the list of threads to be processed in the next iteration  
fn add_thread(
  sp : Int,
  content : @string.View,
  instructions : Array[Instruction],
  gen : Int,
  inst_gen : Array[Int],
  thread : Thread,
  clist : Array[Thread]
) -> Unit {
  if inst_gen[thread.pc] == gen {
    // already on the list
    return
  }
  inst_gen[thread.pc] = gen
  match instructions[thread.pc] {
    Save(i) => {
      thread.captures[i] = sp
      add_thread(
        sp,
        content,
        instructions,
        gen,
        inst_gen,
        { pc: thread.pc + 1, captures: thread.captures },
        clist,
      )
    }
    Jump(i) =>
      add_thread(
        sp,
        content,
        instructions,
        gen,
        inst_gen,
        { pc: i, captures: thread.captures },
        clist,
      )
    Split(i1, i2) => {
      add_thread(
        sp,
        content,
        instructions,
        gen,
        inst_gen,
        { pc: i1, captures: thread.captures.copy() },
        clist,
      )
      add_thread(
        sp,
        content,
        instructions,
        gen,
        inst_gen,
        { pc: i2, captures: thread.captures },
        clist,
      )
    }
    Assertion(pred) =>
      if (pred is BeginText && sp == 0) ||
        (pred is EndText && sp == content.length()) ||
        (
          pred is BeginLine &&
          (sp == 0 || content.charcode_at(sp - 1) == '\n'.to_int())
        ) ||
        (
          pred is EndLine &&
          (sp == content.length() || content.charcode_at(sp) == '\n'.to_int())
        ) ||
        (
          pred is WordBoundary &&
          (
            sp == 0 ||
            sp == content.length() ||
            is_word_char(content.char_at(sp - 1)) !=
            is_word_char(content.char_at(sp))
          )
        ) ||
        (
          pred is NoWordBoundary &&
          sp > 0 &&
          sp < content.length() &&
          is_word_char(content.char_at(sp - 1)) ==
          is_word_char(content.char_at(sp))
        ) {
        // the assertion is true, continue
        add_thread(
          sp,
          content,
          instructions,
          gen,
          inst_gen,
          { pc: thread.pc + 1, captures: thread.captures },
          clist,
        )
      }
    _ => clist.push(thread)
  }
}

///|
/// The core VM function that executes the instructions against the input string.
/// 
/// @param instructions the list of instructions to execute
/// @param input the input string to match against
/// @param captures the number of capture groups
/// @return an array of integers representing the start and end indices of the matches, or an empty array if no match is found
fn vm(
  instructions : Array[Instruction],
  input : @string.View,
  captures : Int
) -> Array[Int] {
  guard instructions is [.., Save(1), Matched]
  let inst_gen = Array::make(instructions.length(), 0)
  let mut clist = Array::new(capacity=instructions.length())
  let mut nlist = Array::new(capacity=instructions.length())
  let mut matched : Array[Int] = []
  add_thread(
    0,
    input,
    instructions,
    1,
    inst_gen,
    { pc: 0, captures: Array::make(captures * 2, -1) },
    clist,
  )
  for sp = 0; sp <= input.length(); sp = sp + 1 {
    if clist.is_empty() {
      break
    }
    let actual_char = if sp == input.length() {
      (-1).unsafe_to_char()
    } else {
      let ch = input.charcode_at(sp)
      if ch is (0xD800..=0xDFFF) {
        let next_ch = input.charcode_at(sp + 1)
        guard next_ch is (0xDC00..=0xDFFF)
        let high = ch - 0xD800
        let low = next_ch - 0xDC00
        (high * 0x400 + low + 0x10000).unsafe_to_char()
      } else {
        guard ch is (0x0000..=0xD7FF | 0xE000..=0xFFFF)
        ch.unsafe_to_char()
      }
    }
    for thread in clist {
      let { pc, captures } = thread
      if instructions[pc] is Matched {
        matched = captures
        // drop everything that has lower priority
        break
      }
      // should have been handled in the add_thread
      guard instructions[pc] is Char(chars)
      if char_in_ranges(actual_char, chars) {
        add_thread(
          sp + 1,
          input,
          instructions,
          sp + 2,
          inst_gen,
          { pc: pc + 1, captures },
          nlist,
        )
      }
    }
    let tmp = clist
    clist = nlist
    nlist = tmp
    nlist.clear()
    if actual_char.to_int() > 0xFFFF {
      continue sp + 2
    }
  }
  return matched
}

///|
test {
  // (a+b+)
  let instructions = [
    Save(0),
    Char(['a', 'a']),
    Split(1, 3),
    Char(['b', 'b']),
    Split(3, 5),
    Save(1),
    Matched,
  ]
  let captures = vm(instructions, "aab", 1)
  inspect(captures, content="[0, 3]")
  inspect("aab".charcodes(start=0, end=3), content="aab")
}

///|
test "lazy capture" {
  // (a+?)aaaa
  let instructions = [
    Save(0),
    Save(2),
    Split(3, 5),
    Char(['a', 'a']),
    Jump(1),
    Save(3),
    Char(['a', 'a']),
    Char(['a', 'a']),
    Char(['a', 'a']),
    Char(['a', 'a']),
    Save(1),
    Matched,
  ]
  let captures = vm(instructions, "aaaa", 2)
  inspect(captures, content="[0, 4, 0, 0]")
}

///|
test "priority" (t : @test.T) {
  // (a.*)(b.*)(c.*)
  let instructions = [
    Save(0),
    Save(2),
    Char(['a', 'a']),
    Split(4, 6),
    // any
    Char(['\u{0}', '\u{10FFFF}']),
    Jump(3),
    Save(3),
    Save(4),
    Char(['b', 'b']),
    Split(10, 12),
    // any
    Char(['\u{0}', '\u{10FFFF}']),
    Jump(9),
    Save(5),
    Save(6),
    Char(['c', 'c']),
    Split(16, 18),
    // any
    Char(['\u{0}', '\u{10FFFF}']),
    Jump(15),
    Save(7),
    Save(1),
    Matched,
  ]
  let captures = vm(instructions, "aabbcc", 4)
  inspect(captures, content="[0, 6, 0, 3, 3, 5, 5, 6]")
  for i = 0; i < captures.length(); i = i + 2 {
    t.writeln("aabbcc".charcodes(start=captures[i], end=captures[i + 1]))
  }
  t.snapshot(filename="priority.txt")
}

///|
test "alternate capture" {
  // a(b|c)*d
  let instructions = [
    Save(0),
    Char(['a', 'a']),
    Split(3, 10),
    Save(2),
    Split(5, 7),
    Char(['b', 'b']),
    Jump(8),
    Char(['c', 'c']),
    Save(3),
    Jump(2),
    Char(['d', 'd']),
    Save(1),
    Matched,
  ]
  let captures = vm(instructions, "abbd", 2)
  inspect(captures, content="[0, 4, 2, 3]")
}

///|
test "assertions" {
  // ^a$
  let instructions = [
    Save(0),
    Assertion(BeginText),
    Char(['a', 'a']),
    Assertion(EndText),
    Save(1),
    Matched,
  ]
  let capture = vm(instructions, "a", 1)
  inspect(capture, content="[0, 1]")
  let capture = vm(instructions, "ab", 1)
  inspect(capture, content="[]")
}

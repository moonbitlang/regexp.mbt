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
  Backreference(Int)
} derive(Show)

///|
impl ToJson for Instruction with to_json(self) {
  match self {
    Matched => "Matched"
    Save(i) => ["Save", i]
    Char(chars) => ["Chars", chars.map(c => repr(c))]
    Jump(i) => ["Jump", i]
    Split(i1, i2) => ["Split", i1, i2]
    Assertion(pred) => ["Assertion", pred]
    Backreference(i) => ["Backreference", i]
  }
}

///|
priv enum Predicate {
  BeginText
  EndText
  BeginLine
  EndLine
  WordBoundary
  NoWordBoundary
} derive(Show, ToJson)

///|
/// A thread represents a point in the execution of the VM.
/// It contains the program counter (pc) and an array of captures.
priv struct Thread {
  pc : Int
  sp : Int
  captures : Array[Int]
}

///|
/// Add a thread to the list of threads to be processed.
/// 
/// This function will forward the thread to the next instruction that consumes at least one character.
/// 
/// @param sp the current position in the input string  
/// @param content the input string  
/// @param instructions the list of instructions to execute  
/// @param inst_gen an array to track the generation of each instruction  
/// @param thread the current thread to add  
/// @param clist the list of threads to be processed in the next iteration  
fn add_thread(
  content : @string.View,
  instructions : Array[Instruction],
  inst_gen : Array[Int],
  thread : Thread,
  clist : Array[Thread]
) -> Unit {
  if inst_gen[thread.pc] == thread.sp {
    // already on the list
    return
  }
  inst_gen[thread.pc] = thread.sp
  match instructions[thread.pc] {
    Save(i) => {
      thread.captures[i] = thread.sp
      add_thread(
        content,
        instructions,
        inst_gen,
        { ..thread, pc: thread.pc + 1, captures: thread.captures },
        clist,
      )
    }
    Jump(i) =>
      add_thread(
        content,
        instructions,
        inst_gen,
        { ..thread, pc: i, captures: thread.captures },
        clist,
      )
    Split(i1, i2) => {
      add_thread(
        content,
        instructions,
        inst_gen,
        { ..thread, pc: i1, captures: thread.captures.copy() },
        clist,
      )
      add_thread(
        content,
        instructions,
        inst_gen,
        { ..thread, pc: i2, captures: thread.captures },
        clist,
      )
    }
    Assertion(pred) => {
      let sp = thread.sp
      let assertion = match pred {
        BeginText => sp == 0
        EndText => sp == content.length()
        BeginLine => sp == 0 || content.charcode_at(sp - 1) == '\n'.to_int()
        EndLine =>
          sp == content.length() || content.charcode_at(sp) == '\n'.to_int()
        WordBoundary =>
          is_word_char_at(content, sp - 1) != is_word_char_at(content, sp)
        NoWordBoundary =>
          is_word_char_at(content, sp - 1) == is_word_char_at(content, sp)
      }
      if assertion {
        add_thread(
          content,
          instructions,
          inst_gen,
          { ..thread, pc: thread.pc + 1, captures: thread.captures },
          clist,
        )
      }
    }
    Backreference(i) if i * 2 >= thread.captures.length() ||
      thread.captures[i * 2] == -1 ||
      thread.captures[i * 2 + 1] == thread.captures[i * 2] =>
      add_thread(
        content,
        instructions,
        inst_gen,
        { ..thread, pc: thread.pc + 1, captures: thread.captures },
        clist,
      )
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
  let inst_gen = Array::make(instructions.length(), -1)
  let mut clist = Array::new(capacity=instructions.length())
  let mut nlist = Array::new(capacity=instructions.length())
  let mut matched : Array[Int] = []
  add_thread(
    input,
    instructions,
    inst_gen,
    { sp: 0, pc: 0, captures: Array::make(captures * 2, -1) },
    clist,
  )
  for sp = 0; sp <= input.length(); {
    if clist.is_empty() {
      break
    }
    let actual_char = if sp == input.length() {
      (-1).unsafe_to_char()
    } else {
      input.char_at(sp)
    }
    let next_sp = if actual_char.to_int() > 0xFFFF { sp + 2 } else { sp + 1 }
    for thread in clist {
      let { pc, captures, sp: thread_sp } = thread
      if thread_sp > sp {
        // this thread is in the future state
        nlist.push(thread)
        continue
      }
      guard thread_sp == sp
      if instructions[pc] is Matched {
        matched = captures
        // drop everything that has lower priority
        break
      }
      // should have been handled in the add_thread
      match instructions[pc] {
        Char(chars) =>
          if char_in_ranges(actual_char, chars) {
            add_thread(
              input,
              instructions,
              inst_gen,
              { pc: pc + 1, captures, sp: next_sp },
              nlist,
            )
          }
        Backreference(i) => {
          let start = captures[i * 2]
          let end = captures[i * 2 + 1]
          let len = end - start
          guard len != 0
          let next_sp = sp + len
          if next_sp <= input.length() &&
            input.charcodes(start~, end~) ==
            input.charcodes(start=sp, end=next_sp) {
            add_thread(
              input,
              instructions,
              Array::make(instructions.length(), -1),
              { pc: pc + 1, captures, sp: next_sp },
              nlist,
            )
          }
        }
        _ => panic()
      }
    }
    let tmp = clist
    clist = nlist
    nlist = tmp
    nlist.clear()
    continue next_sp
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
  // \b
  let instructions = [Save(0), Assertion(WordBoundary), Save(1), Matched]
  let capture = vm(instructions, "", 1)
  inspect(capture, content="[]")
  let capture = vm(instructions, "a", 1)
  inspect(capture, content="[0, 0]")
  // \B
  let instructions = [Save(0), Assertion(NoWordBoundary), Save(1), Matched]
  let capture = vm(instructions, "", 1)
  inspect(capture, content="[0, 0]")
  let capture = vm(instructions, "a", 1)
  inspect(capture, content="[]")
}

///|
test "backreference" {
  // \1(a)\1
  let instructions = [
    Save(0),
    Backreference(1),
    Save(2),
    Char(['a', 'a']),
    Save(3),
    Save(4),
    Backreference(1),
    Save(5),
    Save(1),
    Matched,
  ]
  let capture = vm(instructions, "aa", 3)
  inspect(capture, content="[0, 2, 0, 1, 1, 2]")

  // (b*a)\1
  let instructions = [
    Save(0),
    Save(2),
    Split(3, 5),
    Char(['b', 'b']),
    Jump(2),
    Char(['a', 'a']),
    Save(3),
    Backreference(1),
    Save(1),
    Matched,
  ]
  let capture = vm(instructions, "bbabba", 2)
  inspect(capture, content="[0, 6, 0, 3]")

  // (a|b)\1
  let instructions = [
    Save(0),
    Save(2),
    Split(3, 5),
    Char(['a', 'a']),
    Jump(6),
    Char(['b', 'b']),
    Save(3),
    Backreference(1),
    Save(1),
    Matched,
  ]
  let capture = vm(instructions, "aa", 2)
  inspect(capture, content="[0, 2, 0, 1]")
  let capture = vm(instructions, "bb", 2)
  inspect(capture, content="[0, 2, 0, 1]")

  // (aa|bb)\1cd
  let instructions = [
    Save(0),
    Save(2),
    Split(3, 6),
    Char(['a', 'a']),
    Char(['a', 'a']),
    Jump(8),
    Char(['b', 'b']),
    Char(['b', 'b']),
    Save(3),
    Backreference(1),
    Char(['c', 'c']),
    Char(['d', 'd']),
    Save(1),
    Matched,
  ]
  let capture = vm(instructions, "aaaacd", 2)
  inspect(capture, content="[0, 6, 0, 2]")
  let capture = vm(instructions, "bbbbcd", 2)
  inspect(capture, content="[0, 6, 0, 2]")

  // (abc)(\1|ab)
  let instructions = [
    Save(0),
    Save(2),
    Char(['a', 'a']),
    Char(['b', 'b']),
    Char(['c', 'c']),
    Save(3),
    Save(4),
    Split(8, 10),
    Backreference(1),
    Jump(12),
    Char(['a', 'a']),
    Char(['b', 'b']),
    Save(5),
    Save(1),
    Matched,
  ]
  let capture = vm(instructions, "abcabc", 3)
  inspect(capture, content="[0, 6, 0, 3, 3, 6]")
  let capture = vm(instructions, "abcab", 3)
  inspect(capture, content="[0, 5, 0, 3, 3, 5]")

  // (abc)(ab|\1)d
  let instructions = [
    Save(0),
    Save(2),
    Char(['a', 'a']),
    Char(['b', 'b']),
    Char(['c', 'c']),
    Save(3),
    Save(4),
    Split(8, 11),
    Char(['a', 'a']),
    Char(['b', 'b']),
    Jump(12),
    Backreference(1),
    Save(5),
    Char(['d', 'd']),
    Save(1),
    Matched,
  ]
  let capture = vm(instructions, "abcabcd", 3)
  inspect(capture, content="[0, 7, 0, 3, 3, 6]")
  let capture = vm(instructions, "abcabd", 3)
  inspect(capture, content="[0, 6, 0, 3, 3, 5]")
}

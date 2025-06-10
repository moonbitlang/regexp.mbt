///|
priv enum Instruction {
  Matched
  Save(Int)
  Char(Array[Char])
  Jump(Int)
  Split(Int, Int)
}

///|
priv struct Thread {
  pc : Int
  captures : Array[Int]
}

///|
fn add_thread(
  sp : Int,
  gen : Int,
  instructions : Array[Instruction],
  inst_gen : Array[Int],
  clist : Array[Thread],
  thread : Thread
) -> Unit {
  if inst_gen[thread.pc] == gen {
    // already on the list
    return
  }
  inst_gen[thread.pc] = gen
  match instructions[thread.pc] {
    Save(i) => {
      thread.captures[i] = sp
      if thread.pc + 1 < instructions.length() {
        add_thread(sp, gen, instructions, inst_gen, clist, {
          pc: thread.pc + 1,
          captures: thread.captures,
        })
      }
    }
    Jump(i) =>
      add_thread(sp, gen, instructions, inst_gen, clist, {
        pc: i,
        captures: thread.captures,
      })
    Split(i1, i2) => {
      add_thread(sp, gen, instructions, inst_gen, clist, {
        pc: i1,
        captures: thread.captures,
      })
      add_thread(sp, gen, instructions, inst_gen, clist, {
        pc: i2,
        captures: thread.captures.copy(),
      })
    }
    _ => clist.push(thread)
  }
}

///|
fn thompson_vm(
  instructions : Array[Instruction],
  input : @string.View,
  captures : Int
) -> Array[Int] {
  guard instructions is [Save(0), .., Save(1), Matched]
  let inst_gen = Array::make(instructions.length(), 0)
  let mut clist = Array::new(capacity=instructions.length())
  let mut nlist = Array::new(capacity=instructions.length())
  let mut matched : Array[Int] = []
  add_thread(0, 1, instructions, inst_gen, clist, {
    pc: 0,
    captures: Array::make(captures * 2, 0),
  })
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
      guard instructions[pc] is Char(chars) else {
        // should have been handled in the add_thread
        panic()
      }
      for i = 0; i < chars.length() / 2; i = i + 1 {
        if chars[i * 2] <= actual_char && chars[i * 2 + 1] >= actual_char {
          continue
        } else {
          break
        }
      } else {
        add_thread(sp + 1, sp + 2, instructions, inst_gen, nlist, {
          pc: pc + 1,
          captures,
        })
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
  let captures = thompson_vm(instructions, "aab", 1)
  inspect!(captures, content="[0, 3]")
  inspect!("aab".charcodes(start=0, end=3), content="aab")
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
  let captures = thompson_vm(instructions, "aaaa", 2)
  inspect!(captures, content="[0, 4, 0, 0]")
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
  let captures = thompson_vm(instructions, "aabbcc", 4)
  inspect!(captures, content="[0, 6, 0, 3, 3, 5, 5, 6]")
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
  let captures = thompson_vm(instructions, "abbd", 2)
  inspect!(captures, content="[0, 4, 3, 3]")
}

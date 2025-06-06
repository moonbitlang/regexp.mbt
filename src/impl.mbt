///|
enum Instruction {
  Save(Int)
  Char(Array[Char])
  Jump(Int)
  Split(Int, Int)
}

///|
priv struct Thread {
  pc : Int
  captures : Array[Int]
} derive(Show)

///|
fn thompson_vm(
  instructions : Array[Instruction],
  input : @string.View,
  captures : Int
) -> Array[Int] {
  guard instructions is [Save(_), .., Save(_)]
  let mut clist = Array::new(capacity=instructions.length())
  let mut nlist = Array::new(capacity=instructions.length())
  clist.push({ pc: 0, captures: Array::make(captures * 2, 0) })
  for sp = 0; sp <= input.length(); sp = sp + 1 {
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
    for i = 0; i < clist.length(); i = i + 1 {
      let { pc, captures } = clist[i]
      if pc >= instructions.length() {
        continue
      }
      match instructions[pc] {
        Save(i) => {
          captures[i] = sp
          if pc + 1 < instructions.length() {
            clist.push({ pc: pc + 1, captures })
          } else {
            return captures
          }
        }
        Char(chars) =>
          for i = 0; i < chars.length() / 2; i = i + 1 {
            if chars[i * 2] <= actual_char && chars[i * 2 + 1] >= actual_char {
              continue
            } else {
              break
            }
          } else {
            nlist.push({ pc: pc + 1, captures })
          }
        Jump(i) => clist.push({ pc: i, captures })
        Split(i1, i2) => {
          clist.push({ pc: i1, captures })
          clist.push({ pc: i2, captures: captures.copy() })
        }
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
  return []
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
    Jump(17),
    Save(7),
    Save(1),
  ]
  let captures = thompson_vm(instructions, "aabbcc", 4)
  inspect!(captures, content="[0, 5, 0, 3, 3, 4, 4, 5]")
  for i = 0; i < captures.length(); i = i + 2 {
    t.writeln("aabbcc".charcodes(start=captures[i], end=captures[i + 1]))
  }
  t.snapshot(filename="priority.txt")
}

///|
enum Instruction {
  Save(Int)
  Char(Char)
  Jump(Int)
  Split(Int, Int)
}

///|
priv struct Thread {
  pc : Int
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
  let result = Array::make(captures * 2, 0)
  clist.push({ pc: 0 })
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
      let { pc } = clist[i]
      if pc >= instructions.length() {
        continue
      }
      match instructions[pc] {
        Save(i) => {
          result[i] = sp
          if pc + 1 < instructions.length() {
            clist.push({ pc: pc + 1 })
          }
        }
        Char(c) => if c == actual_char { nlist.push({ pc: pc + 1 }) }
        Jump(i) => clist.push({ pc: i })
        Split(i1, i2) => {
          clist.push({ pc: i1 })
          clist.push({ pc: i2 })
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
  result
}

///|
test {
  // (a+b+)
  let instructions = [
    Save(0),
    Char('a'),
    Split(1, 3),
    Char('b'),
    Split(3, 5),
    Save(1),
  ]
  let captures = thompson_vm(instructions, "aab", 1)
  inspect!(captures, content="[0, 3]")
  inspect!("aab".charcodes(start=0, end=3), content="aab")
}

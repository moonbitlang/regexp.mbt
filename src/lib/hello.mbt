///|
enum Instruction {
  Match
  Char(Char)
  Jump(Int)
  Split(Int, Int)
}

///|
fn implementation(prog : Instruction, input : Iter[Char]) -> Bool {
  ...
}

///|
fn recursive(
  instructions : Array[Instruction],
  input : Array[Char],
  pc~ : Int = 0,
  ptr~ : Int = 0
) -> Bool {
  match instructions[pc] {
    Match => true
    Char(c) =>
      input.get(ptr) is Some(ch) &&
      c == ch &&
      recursive(instructions, input, pc=pc + 1, ptr=ptr + 1)
    Jump(i) => recursive(instructions, input, pc=i, ptr~)
    Split(i1, i2) =>
      recursive(instructions, input, pc=i1, ptr~) ||
      recursive(instructions, input, pc=i2, ptr~)
  }
}

///|
priv struct Thread0 {
  instruction : Int
  char : Int
}

///|
fn backtracking_vm(
  instructions : Array[Instruction],
  input : Array[Char]
) -> Bool {
  let mut threads : @list.T[Thread0] = @list.new()
  threads = threads.add({ instruction: 0, char: 0 })
  while threads is More(thread, tail~) {
    threads = tail
    let mut pc = thread.instruction
    let mut sp = thread.char
    for {
      match instructions[pc] {
        Match => return true
        Char(c) =>
          if input.get(sp) is Some(ch) && c == ch {
            pc += 1
            sp += 1
          } else {
            break
          }
        Jump(i) => pc = i
        Split(i1, i2) => {
          threads = threads.add({ instruction: i2, char: sp })
          pc = i1
        }
      }
    }
  }
  return false
}

///|
test {
  let instructions = [Char('a'), Split(0, 2), Char('b'), Split(2, 4), Match]
  assert_true(recursive(instructions, "aab".iter().collect()))
  assert_true(backtracking_vm(instructions, "aab".iter().collect()))
  assert_true(thompson_vm(instructions, "aab".iter().collect()))
}

///|
priv struct Thread {
  pc : Int
} derive(Show)

///|
fn thompson_vm(instructions : Array[Instruction], input : Array[Char]) -> Bool {
  let mut clist = Array::new(capacity=instructions.length())
  let mut nlist = Array::new(capacity=instructions.length())
  clist.push({ pc: 0 })
  for sp in 0..=input.length() {
    for i = 0; i < clist.length(); i = i + 1 {
      let { pc } = clist[i]
      match instructions[pc] {
        Match => return true
        Char(c) if input.get(sp) is Some(ch) && c == ch =>
          nlist.push({ pc: pc + 1 })
        Jump(i) => clist.push({ pc: i })
        Split(i1, i2) => {
          clist.push({ pc: i1 })
          clist.push({ pc: i2 })
        }
        _ => ()
      }
    }
    let tmp = clist
    clist = nlist
    nlist = tmp
    nlist.clear()
  } else {
    false
  }
}

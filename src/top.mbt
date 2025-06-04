///|
priv enum State {
  Match(lastlist~ : Ref[UInt])
  Split(out~ : Ref[State?], out1~ : Ref[State?])
  Char(Char, out~ : Ref[State?], lastlist~ : Ref[UInt])
}

///|
struct Frag {
  start : State
  out : Array[Ref[State?]]
}

///|
fn Frag::char(c : Char) -> Frag {
  let out = { val: None }
  { start: Char(c, out~, lastlist={ val: 0 }), out: [out] }
}

///|
fn Frag::concat(self : Frag, other : Frag) -> Frag {
  for out in self.out {
    out.val = Some(other.start)
  }
  { start: self.start, out: other.out }
}

///|
fn Frag::alternate(self : Frag, other : Frag) -> Frag {
  let out = []
  for state in self.out {
    out.push(state)
  }
  for state in other.out {
    out.push(state)
  }
  {
    start: Split(out={ val: Some(self.start) }, out1={ val: Some(other.start) }),
    out,
  }
}

///|
fn Frag::zero_or_one(self : Frag) -> Frag {
  let out = []
  let out1 = { val: None }
  let state = Split(out={ val: Some(self.start) }, out1~)
  for out_state in self.out {
    out.push(out_state)
  }
  out.push(out1)
  { start: state, out }
}

///|
fn Frag::zero_or_more(self : Frag) -> Frag {
  let out1 = { val: None }
  let state = Split(out={ val: Some(self.start) }, out1~)
  for out_state in self.out {
    out_state.val = Some(state)
  }
  { start: state, out: [out1] }
}

///|
fn Frag::one_or_more(self : Frag) -> Frag {
  let out1 = { val: None }
  let state = Split(out={ val: Some(self.start) }, out1~)
  for out_state in self.out {
    out_state.val = Some(state)
  }
  { ..self, out: [out1] }
}

///|
pub fn Frag::from_postfix(postfix : @string.View) -> Frag {
  let stack = []
  loop postfix {
    ['.', .. rest] => {
      let frag0 = stack.unsafe_pop()
      let frag1 = stack.unsafe_pop()
      stack.push(Frag::concat(frag0, frag1))
      continue rest
    }
    ['|', .. rest] => {
      let frag0 = stack.unsafe_pop()
      let frag1 = stack.unsafe_pop()
      stack.push(Frag::alternate(frag0, frag1))
      continue rest
    }
    ['?', .. rest] => {
      let frag0 = stack.unsafe_pop()
      stack.push(Frag::zero_or_one(frag0))
      continue rest
    }
    ['*', .. rest] => {
      let frag0 = stack.unsafe_pop()
      stack.push(Frag::zero_or_more(frag0))
      continue rest
    }
    ['+', .. rest] => {
      let frag0 = stack.unsafe_pop()
      stack.push(Frag::one_or_more(frag0))
      continue rest
    }
    ['\\', '.' | '|' | '?' | '*' | '+' as ch, .. rest] => {
      stack.push(Frag::char(ch))
      continue rest
    }
    [ch, .. rest] => {
      stack.push(Frag::char(ch))
      continue rest
    }
    [] => ()
  }
  guard stack is [frag]
  let matched = Match(lastlist={ val: 0 })
  for out in frag.out {
    out.val = Some(matched)
  }
  frag
}

///|
pub fn Frag::match_(frag : Frag, input : Iter[Char]) -> Bool {
  let mut listId = 0U
  let mut clist = [frag.start]
  let mut nlist = []
  fn add(list : Array[State], state : State) {
    match state {
      Split(out~, out1~) => {
        guard out.val is Some(state)
        add(list, state)
        guard out1.val is Some(state)
        add(list, state)
      }
      Match(lastlist~) if lastlist.val != listId => {
        lastlist.val = listId
        list.push(state)
      }
      Char(_, lastlist~, ..) if lastlist.val != listId => {
        lastlist.val = listId
        list.push(state)
      }
      _ => ()
    }
  }

  fn step(ch : Char) {
    listId += 1
    nlist.clear()
    for state in clist {
      match state {
        Match(_) => add(nlist, state)
        Char(c, out={ val: Some(state) }, ..) if c == ch => add(nlist, state)
        Char(c, ..) if c != ch => ()
        _ => panic()
      }
    }
    let tmp = clist
    clist = nlist
    nlist = tmp
  }

  for ch in input {
    step(ch)
  }
  clist
  .iter()
  .any(fn {
    Match(..) => true
    _ => false
  })
}

///|
test {
  let frag = Frag::from_postfix("abb.+.a.")
  assert_true!(frag.match_("abba".iter()))
  let frag = Frag::from_postfix("abb.+.a.")
  assert_true!(frag.match_("abbbba".iter()))
  let frag = Frag::from_postfix("abb.+.a.")
  assert_false!(frag.match_("aa".iter()))
}

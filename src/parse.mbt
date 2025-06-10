///|
priv struct Parser {
  mut input : @string.View
}

///|
pub enum Err {
  InternalError
  InvalidCharClass
  InvalidEscape
  InvalidNamedCapture
  InvalidRepeatOp
  InvalidRepeatSize
  MissingBracket
  MissingParenthesis
  MissingRepeatArgument
  TrailingBackslash
  UnexpectedParenthesis
}

///|
pub type! Error_ {
  Error_(err~ : Err, data~ : @string.View)
}

///|
fn Parser::new(input : @string.View) -> Parser {
  Parser::{ input, }
}

///|
pub fn parse(regex : @string.View) -> Regex!Error_ {
  let parser = Parser::new(regex)
  parser.parse_expression()
}

///|
fn Parser::parse_expression(self : Parser) -> Regex!Error_ {
  let mut left = self.parse_sequence()
  while self.peek_char() == Some('|') {
    self.consume_char()
    let right = self.parse_sequence()
    left = Alternate(left, right)
  }
  left
}

///|
fn Parser::parse_sequence(self : Parser) -> Regex!Error_ {
  let sequence = []
  while self.has_more() &&
        self.peek_char() != Some('|') &&
        self.peek_char() != Some(')') {
    let term = self.parse_term()
    sequence.push(term)
  }
  match sequence.length() {
    // Seems like go consider empty sequence as a valid regex
    0 => Empty
    1 => sequence[0]
    _ => Concat(sequence)
  }
}

///|
fn Parser::parse_term(self : Parser) -> Regex!Error_ {
  let mut base = self.parse_factor()

  // 处理量词
  match self.peek_char() {
    Some('*') => {
      self.consume_char()
      base = ZeroOrMore(base)
    }
    Some('+') => {
      self.consume_char()
      base = OneOrMore(base)
    }
    Some('?') => {
      self.consume_char()
      base = ZeroOrOne(base)
    }
    _ => ()
  }
  base
}

///|
fn Parser::parse_factor(self : Parser) -> Regex!Error_ {
  match self.peek_char() {
    Some('(') => {
      self.consume_char() // 消费 '('
      let expr = self.parse_expression()
      if self.peek_char() != Some(')') {
        raise Error_(err=MissingParenthesis, data=self.input)
      }
      self.consume_char() // 消费 ')'
      Capture(expr)
    }
    Some('[') => self.parse_char_class()
    Some('\\') => {
      self.consume_char() // 消费 '\'
      match self.peek_char() {
        Some(c) => {
          self.consume_char()
          CharClass([c, c])
        }
        None => raise Error_(err=TrailingBackslash, data=self.input)
      }
    }
    Some(c) if Parser::is_special_char(c) =>
      raise Error_(err=InvalidEscape, data=self.input)
    Some(c) => {
      self.consume_char()
      CharClass([c, c])
    }
    None => raise Error_(err=InternalError, data=self.input)
  }
}

///|
fn Parser::parse_char_class(self : Parser) -> Regex!Error_ {
  self.consume_char() // 消费 '['
  let chars = []
  while self.has_more() && self.peek_char() != Some(']') {
    match self.peek_char() {
      Some('\\') => {
        self.consume_char()
        match self.peek_char() {
          Some(c) => {
            self.consume_char()
            chars.push(c)
          }
          None => raise Error_(err=TrailingBackslash, data=self.input)
        }
      }
      Some(c) => {
        self.consume_char()
        chars.push(c)
      }
      None => raise Error_(err=MissingBracket, data=self.input)
    }
  }
  if self.peek_char() != Some(']') {
    raise Error_(err=MissingBracket, data=self.input)
  }
  self.consume_char() // 消费 ']'
  CharClass(chars)
}

///|
fn Parser::peek_char(self : Parser) -> Char? {
  match self.input {
    [ch, ..] => Some(ch)
    _ => None
  }
}

///|
fn Parser::consume_char(self : Parser) -> Unit {
  match self.input {
    [_, .. rest] => self.input = rest
    _ => ()
  }
}

///|
fn Parser::has_more(self : Parser) -> Bool {
  not(self.input is "")
}

///|
fn Parser::is_special_char(c : Char) -> Bool {
  match c {
    '*' | '+' | '?' | '|' | '(' | ')' | '[' | ']' | '{' | '}' => true
    _ => false
  }
}

///|
test {
  let regex = parse("a(b|c)*d")
  let (instructions, capture) = regex.compile()
  let result = thompson_vm(instructions, "abbd", capture)
  inspect(result, content="[0, 4, 2, 3]")
}

///|
test {
  let regex = parse("abc|def|ghi")
  let (instructions, capture) = regex.compile()
  let result = thompson_vm(instructions, "abcdefghi", capture)
  inspect(result, content="[0, 3]")
}

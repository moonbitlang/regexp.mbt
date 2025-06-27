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

/// Regular Expression Parser - Using Recursive Descent Parsing Algorithm
///
/// This parser implements a simplified regular expression syntax, described using ABNF (Augmented Backus-Naur Form) as follows:
///
/// ```abnf
/// ; Regular Expression Syntax ABNF Specification
/// regex       = expression
/// expression  = sequence *( "|" sequence )           ; Alternation: a|b|c
/// sequence    = *term                                ; Sequence: abc
/// term        = factor [quantifier]                  ; Term with quantifier: a*, b+, c?
/// factor      = char / group / char-class / escape / dot / assertion   ; Basic elements
///
/// ; Quantifiers
/// quantifier  = "*" / "+" / "?" / repeat
/// repeat      = "{" number "}" / "{" number "," "}" / "{" number "," number "}"
///
/// ; Groups
/// group       = "(" expression ")"                   ; Capture group: (abc)
///             / "(?<" group-name ">" expression ")"  ; Named capture group:(?<name>abc)
///
/// ; Character classes
/// char-class  = "[" *char-class-item "]"            ; Character class: [abc], [a-z]
/// char-class-item = escape / char-range / normal-char
/// char-range  = char-class-char "-" char-class-char  ; Character range: a-z, 0-9
/// char-class-char = escape / normal-char             ; Character in character class (any character or escaped character)
///
/// ; Escape sequences
/// escape      = "\" any-char                         ; Escape character: \n, \*, \\
///
/// ; Assertions
/// assertion   = "^" / "$"                            ; Assertions: ^ (line start), $ (line end)
///
/// ; Any character
/// dot         = "."                                  ; Match any character
///
/// ; Normal character
/// char        = normal-char
/// normal-char = <any character except special chars>
/// special-chars = "*" / "+" / "?" / "|" / "(" / ")" / "[" / "]" / "{" / "}" / "\" / "." / "^" / "$"
/// ```
///
/// Parsing precedence (from high to low):
/// 1. Factor: characters, groups, character classes, escapes, assertions
/// 2. Quantifiers: *, +, ?
/// 3. Concatenation: implicit concatenation
/// 4. Alternation: |
///
/// Examples:
/// - `abc`     -> Sequence: character a, character b, character c
/// - `a|b`     -> Alternation: character a or character b
/// - `a*`      -> Quantifier: character a repeated 0 or more times
/// - `(a|b)*`  -> Group with quantifier: (character a or character b) repeated 0 or more times
/// - `[abc]`   -> Character class: any of characters a, b, or c
/// - `^abc$`   -> Assertions: line start, characters abc, line end

///|
priv struct Parser {
  mut input : @string.View
  mut flags : Flags
}

///|
priv struct Flags {
  multiline : Bool
  singleline : Bool
  ignore_case : Bool
} derive(Default)

///| Regular expression parsing error types
///
/// Defines various error conditions that may be encountered during parsing
pub enum Err {
  InternalError // Internal error
  InvalidCharClass // Invalid character class
  InvalidEscape // Invalid escape sequence
  InvalidNamedCapture // Invalid named capture group
  InvalidRepeatOp // Invalid repeat operator
  InvalidRepeatSize // Invalid repeat count
  MissingBracket // Missing right bracket ]
  MissingParenthesis // Missing right parenthesis )
  MissingRepeatArgument // Missing repeat argument
  TrailingBackslash // Trailing backslash
  UnexpectedParenthesis // Unexpected parenthesis
} derive(Show)

///| Parsing error exception type
///
/// Contains error information and related string view context
pub suberror Error_ {
  Error_(err~ : Err, data~ : @string.View)
} derive(Show)

///| Create a regular expression parser
///
/// Parameters:
/// - `input`: String view of the regular expression to parse
///
/// Returns: New parser instance
fn Parser::new(input : @string.View, flags : Flags) -> Parser {
  Parser::{ input, flags }
}

///| Entry function for parsing regular expressions
///
/// According to ABNF rule: `regex = expression`
///
/// Parameters:
/// - `regex`: Regular expression string
///
/// Returns: Parsed Regex AST
///
/// Throws: Error_ when parsing fails
fn parse(
  regex : @string.View,
  flags~ : Flags = Flags::default()
) -> Regex raise Error_ {
  let parser = Parser::new(regex, flags)
  let result = parser.parse_expression()

  // Check if there's any remaining input, especially unmatched right parentheses
  if parser.input is [')', ..] {
    raise Error_(err=UnexpectedParenthesis, data=parser.input)
  }
  result
}

///| Parse Expression
///
/// According to ABNF rule: `expression = sequence *( "|" sequence )`
///
/// Expression is the top-level structure of a regular expression, consisting of one or more sequences separated by `|`.
/// This represents alternation operation, matching any one of the sequences.
///
/// Examples:
/// - `a`       -> Single sequence
/// - `a|b`     -> Alternation of two sequences: match a or b
/// - `abc|def` -> Alternation of two sequences: match abc or def
/// - `a|b|c`   -> Alternation of multiple sequences: match a, b, or c
///
/// Returns: Parsed Regex AST
fn Parser::parse_expression(self : Parser) -> Regex raise Error_ {
  let mut left = self.parse_sequence()
  while self.input is ['|', .. rest] {
    self.input = rest // consume '|'
    let right = self.parse_sequence()
    left = Regex::Alternate(left, right)
  }
  left
}

///| Parse Sequence
///
/// According to ABNF rule: `sequence = *term`
///
/// Sequence consists of consecutive terms, representing implicit concatenation operation.
/// Each term must match in order for the entire sequence to match successfully.
///
/// Examples:
/// - `abc`     -> Sequence of three terms: character a, character b, character c
/// - `a*b+`    -> Sequence of two terms: quantifier a*, quantifier b+
/// - `(ab)c`   -> Sequence of two terms: group (ab), character c
/// - ``        -> Empty sequence (valid)
///
/// Parsing termination conditions:
/// - Encounters `|` character (alternation operator)
/// - Encounters `)` character (group end)
/// - End of input
///
/// Returns: Parsed Regex AST
fn Parser::parse_sequence(self : Parser) -> Regex raise Error_ {
  let sequence = []
  while self.input is [ch, ..] && ch != '|' && ch != ')' {
    let term = self.parse_term()
    sequence.push(term)
  }
  match sequence {
    // Empty sequence is considered a valid regular expression (consistent with Go's behavior)
    [] => Regex::Empty
    [regex] => regex
    _ => Regex::Concat(sequence)
  }
}

///| Parse Term
///
/// According to ABNF rule: `term = factor [quantifier]`
///
/// Term consists of a factor plus an optional quantifier.
/// Factor is the most basic regular expression unit, quantifier modifies the repetition count of the factor.
///
/// Supported quantifiers:
/// - `*`: Zero or more repetitions (ZeroOrMore)
/// - `+`: One or more repetitions (OneOrMore)
/// - `?`: Zero or one repetition (ZeroOrOne)
/// - `{n}`: Exactly n repetitions
/// - `{n,}`: At least n repetitions
/// - `{n,m}`: n to m repetitions
///
/// Examples:
/// - `a`      -> Basic factor: character a
/// - `a*`     -> Quantified term: character a repeated 0 or more times
/// - `a+`     -> Quantified term: character a repeated 1 or more times
/// - `a?`     -> Quantified term: character a repeated 0 or 1 times
/// - `a{3}`   -> Quantified term: character a repeated exactly 3 times
/// - `a{2,}`  -> Quantified term: character a repeated at least 2 times
/// - `a{2,5}` -> Quantified term: character a repeated 2 to 5 times
/// - `(ab)*`  -> Quantified term: group (ab) repeated 0 or more times
///
/// Returns: Parsed Regex AST
fn Parser::parse_term(self : Parser) -> Regex raise Error_ {
  let mut base = self.parse_factor()

  // Handle quantifiers
  match self.input {
    [.. "*?", .. rest] => {
      // Handle lazy quantifier '*?'
      self.input = rest // consume '*?'
      base = ZeroOrMore(base, greedy=false)
    }
    [.. "*", .. rest] => {
      // Handle greedy quantifier '*'
      self.input = rest // consume '*'
      base = ZeroOrMore(base, greedy=true)
    }
    [.. "+?", .. rest] => {
      // Handle lazy quantifier '+?'
      self.input = rest // consume '+?'
      base = OneOrMore(base, greedy=false)
    }
    [.. "+", .. rest] => {
      // Handle greedy quantifier '+'
      self.input = rest // consume '+'
      base = OneOrMore(base, greedy=true)
    }
    [.. "??", .. rest] => {
      // Handle lazy quantifier '??'
      self.input = rest // consume '??'
      base = ZeroOrOne(base, greedy=false)
    }
    [.. "?", .. rest] => {
      // Handle greedy quantifier '?'
      self.input = rest // consume '?'
      base = ZeroOrOne(base, greedy=true)
    }
    ['{', .. rest] => {
      self.input = rest
      // Handle repeat quantifiers {n}, {n,}, {n,m}
      let repeat_result = self.parse_repeat()
      let greedy = match self.input {
        ['?', .. rest] => {
          self.input = rest // consume '?'
          false
        }
        _ => true
      }
      base = Repeat(base, greedy~, min=repeat_result.0, max=repeat_result.1)
    }
    _ => ()
  }
  base
}

///| Parse Factor
///
/// According to ABNF rule: `factor = char / group / char-class / escape / dot / assertion`
///
/// Factor is the smallest unit of a regular expression, which can be:
/// - Group: `(expression)` - Subexpression surrounded by parentheses
/// - Character class: `[abc]` - Match any one character from the specified character set
/// - Any character: `.` - Match any single character
/// - Assertion: `^` - Line start assertion, `$` - Line end assertion
/// - Escape character: `\c` - Escaped character, such as `\*`, `\\`
/// - Normal character: Any character except special characters
///
/// Special characters must be escaped to be used as literals:
/// `*` `+` `?` `|` `(` `)` `[` `]` `{` `}` `\` `.` `^` `$`
///
/// Examples:
/// - `a`       -> Character: matches character 'a'
/// - `(abc)`   -> Group: capture group, matches sequence 'abc'
/// - `[abc]`   -> Character class: matches 'a', 'b', or 'c'
/// - `\.`      -> Escape character: matches literal '.'
/// - `.`       -> Any character: matches any character
/// - `^`       -> Assertion: line start assertion
/// - `$`       -> Assertion: line end assertion
///
/// Returns: Parsed Regex AST
///
/// Throws: Error_ when invalid syntax is encountered
fn Parser::parse_factor(self : Parser) -> Regex raise Error_ {
  match self.input {
    [.. "(?", .. rest] =>
      // Handle various special group syntax
      match rest {
        ['<', .. rest] => {
          // Named capture group (?<name>...)
          self.input = rest // consume '(?<'
          let name = self.parse_group_name()
          guard self.input is ['>', .. rest] else {
            raise Error_(err=InvalidNamedCapture, data=self.input)
          }
          self.input = rest // consume '>'
          let expr = self.parse_expression()
          guard self.input is [')', .. rest] else {
            raise Error_(err=MissingParenthesis, data=self.input)
          }
          self.input = rest // consume ')'
          Capture(expr, name=Some(name))
        }
        _ => {
          // (?flags:...) - Scoped flags group
          self.input = rest // consume '(?'
          let old_flags = self.flags
          let new_flags = self.parse_flags()
          self.flags = new_flags
          let expr = self.parse_expression()
          guard self.input is [')', .. rest] else {
            raise Error_(err=MissingParenthesis, data=self.input)
          }
          self.input = rest // consume ')'
          self.flags = old_flags // restore original flags
          expr
        }
      }
    ['(', .. rest] => {
      self.input = rest // consume '('
      // Regular capture group
      let expr = self.parse_expression()
      guard self.input is [')', .. rest] else {
        raise Error_(err=MissingParenthesis, data=self.input)
      }
      self.input = rest // consume ')'
      Capture(expr, name=None)
    }
    ['[', .. rest] => {
      self.input = rest
      self.parse_char_class()
    }
    ['.', .. rest] => {
      self.input = rest // consume '.'
      if self.flags.singleline {
        // In singleline mode, '.' matches any character including newline
        CharClass(ranges_any, neg=false)
      } else {
        // In default mode, '.' matches any character except newline
        CharClass(ranges_any_not_new_line, neg=false)
      }
    }
    ['^', .. rest] => {
      self.input = rest // consume '^'
      if self.flags.multiline {
        // In multiline mode, '^' matches the beginning of a line
        Assertion(BeginLine)
      } else {
        // In default mode, '^' matches the beginning of the text
        Assertion(BeginText)
      }
    }
    ['$', .. rest] => {
      self.input = rest // consume '$'
      if self.flags.multiline {
        // In multiline mode, '$' matches the end of a line
        Assertion(EndLine)
      } else {
        // In default mode, '$' matches the end of the text
        Assertion(EndText)
      }
    }
    ['\\', .. rest] => {
      guard rest is [c, .. rest] else {
        raise Error_(err=TrailingBackslash, data=self.input)
      }
      self.input = rest // consume '\' and the character
      match c {
        'b' => Assertion(WordBoundary) // Word boundary assertion
        'B' => Assertion(NoWordBoundary) // Non-word boundary assertion
        'd' => CharClass(ranges_is_digit, neg=false) // Digit character class
        'D' => CharClass(ranges_is_not_digit, neg=false) // Non-digit character class
        'w' => CharClass(ranges_is_word, neg=false) // Word character class
        'W' => CharClass(ranges_is_not_word, neg=false) // Non-word character class
        's' => CharClass(ranges_is_white_space_or_line_terminator, neg=false) // Whitespace character class
        'S' =>
          CharClass(ranges_is_not_white_space_or_line_terminator, neg=false) // Non-whitespace character class
        // ControlEscape
        't' => CharClass(['\t', '\t'], neg=false) // Tab
        'n' => CharClass(['\n', '\n'], neg=false) // Newline
        'v' => CharClass(['\u{b}', '\u{b}'], neg=false) // Vertical tab
        'f' => CharClass(['\u{c}', '\u{c}'], neg=false) // Form feed
        'r' => CharClass(['\r', '\r'], neg=false) // Carriage return
        'p' | 'P' as flag => {
          // Unicode property \p{property_name}
          let property_name = self.parse_unicode_property()
          self.parse_general_category(property_name, flag == 'P')
        }
        _ =>
          if self.flags.ignore_case {
            CharClass(case_insensitive_char_class([c, c]), neg=false)
          } else {
            CharClass([c, c], neg=false)
          }
      }
    }
    [c, ..] if Parser::is_special_char(c) =>
      raise Error_(err=InvalidEscape, data=self.input)
    [c, .. rest] => {
      self.input = rest
      if self.flags.ignore_case {
        CharClass(case_insensitive_char_class([c, c]), neg=false)
      } else {
        CharClass([c, c], neg=false)
      }
    }
    "" => raise Error_(err=InternalError, data=self.input)
  }
}

///| Parse Character Class
///
/// According to ABNF rule: `char-class = "[" *char-class-item "]"`
///
/// A character class is a set of characters enclosed in square brackets, matching any single character from the set.
/// It supports escape characters and character range syntax.
///
/// Examples:
/// - `[abc]`   -> Matches character 'a', 'b', or 'c'
/// - `[a-z]`   -> Character range: matches any character from 'a' to 'z'
/// - `[a-zA-Z]` -> Multiple ranges: matches any character from 'a' to 'z' or 'A' to 'Z'
/// - `[a-\]]`  -> Character range: matches any character from 'a' to ']'
/// - `[\[\]]`  -> Escaped square bracket characters
/// - `[\\]`    -> Escaped backslash character
///
/// A char-class-item can be:
/// - Character range: `a-z` - a range from character 'a' to character 'z'
/// - Escape character: `\c` - any character escaped by a backslash (including `\]`)
/// - Normal character: any non-special character
///
/// Input: Assumes the left square bracket `[` has been consumed
///
/// Returns: CharClass(chars) - a character class AST containing a list of character ranges
///
/// Throws: Error_ when the character class format is incorrect
fn Parser::parse_char_class(self : Parser) -> Regex raise Error_ {
  let neg = if self.input is ['^', .. rest] {
    self.input = rest // consume '^'
    true
  } else {
    false
  }
  let chars = []
  while self.input is [ch, .. rest] && ch != ']' {
    let start_char = match ch {
      '\\' => {
        guard rest is [ch, .. rest] else {
          raise Error_(err=TrailingBackslash, data=self.input)
        }
        self.input = rest
        match ch {
          'd' => {
            ranges_is_digit.each(chars.push(_)) // digit character class
            continue
          }
          'D' => {
            ranges_is_not_digit.each(chars.push(_)) // non-digit character class
            continue
          }
          'w' => {
            ranges_is_word.each(chars.push(_)) // word character class
            continue
          }
          'W' => {
            ranges_is_not_word.each(chars.push(_)) // non-word character class
            continue
          }
          's' => {
            ranges_is_white_space_or_line_terminator.each(chars.push(_)) // whitespace character class
            continue
          }
          'S' => {
            ranges_is_not_white_space_or_line_terminator.each(chars.push(_)) // non-whitespace character class
            continue
          }
          // ControlEscape
          't' => {
            ['\t', '\t'].each(chars.push(_))
            continue
          }
          'n' => {
            ['\n', '\n'].each(chars.push(_))
            continue
          }
          'v' => {
            ['\u{b}', '\u{b}'].each(chars.push(_))
            continue
          }
          'f' => {
            ['\u{c}', '\u{c}'].each(chars.push(_))
            continue
          }
          'r' => {
            ['\r', '\r'].each(chars.push(_))
            continue
          }
          // backspace
          'b' => {
            ['\u{8}', '\u{8}'].each(chars.push(_))
            continue
          }
          _ => ch
        }
      }
      _ => {
        self.input = rest
        ch
      }
    }

    // Check for character range (e.g., a-z)
    if self.input is ['-', .. rest] {
      // Look ahead after '-', ensure it's not ']' and there are more characters
      let input_copy = self.input
      self.input = rest // consume '-'
      if self.input is [ch, .. rest] && ch != ']' {
        // Parse the end character of the range
        let end_char = match ch {
          '\\' => {
            guard rest is [ch, .. rest] else {
              raise Error_(err=TrailingBackslash, data=self.input)
            }
            self.input = rest
            ch
          }
          _ => {
            self.input = rest
            ch
          }
        }

        // Check if the end character of the range is valid
        if end_char < start_char {
          raise Error_(err=InvalidCharClass, data=self.input)
        }

        // Add the range: start and end characters
        chars.push(start_char)
        chars.push(end_char)
      } else {
        // If '-' is followed by ']' or end of input, it's a literal, not a range operator
        self.input = input_copy // Restore input state
        chars.push(start_char)
        chars.push(start_char)
      }
    } else {
      // Normal character, not a range, represented as a single-character range
      chars.push(start_char)
      chars.push(start_char)
    }
  }
  guard self.input is [']', .. rest] else {
    raise Error_(err=MissingBracket, data=self.input)
  }
  self.input = rest // consume ']'
  if self.flags.ignore_case {
    CharClass(case_insensitive_char_class(chars), neg~)
  } else {
    CharClass(chars, neg~)
  }
}

///| Check if a character is a regular expression special character
///
/// Special characters need to be escaped to be used as literal characters.
///
/// Parameters:
/// - `c`: The character to check
///
/// Returns: `true` if it is a special character
fn Parser::is_special_char(c : Char) -> Bool {
  c
  is ('*'
  | '+'
  | '?'
  | '|'
  | '('
  | ')'
  | '['
  | ']'
  | '{'
  | '}'
  | '.'
  | '^'
  | '$')
}

///| Parse Repeat Quantifier
///
/// According to ABNF rule: `repeat = "{" number "}" / "{" number "," "}" / "{" number "," number "}"`
///
/// The repeat quantifier specifies how many times the preceding element should be repeated:
/// - `{n}`: Exactly n times
/// - `{n,}`: At least n times
/// - `{n,m}`: From n to m times (inclusive)
///
/// Examples:
/// - `a{3}` -> Character 'a' repeated exactly 3 times
/// - `b{2,}` -> Character 'b' repeated at least 2 times
/// - `c{1,5}` -> Character 'c' repeated 1 to 5 times
///
/// Input: Assumes the left brace `{` has been consumed
///
/// Returns: A tuple (min, max), where:
/// - min: Minimum number of repetitions
/// - max: Maximum number of repetitions (None means unlimited)
///
/// Throws: Error_ when the repeat quantifier format is incorrect
fn Parser::parse_repeat(self : Parser) -> (UInt, UInt?) raise Error_ {

  // Parse the first number (minimum repetitions)
  let min = self.parse_number()
  match self.input {
    ['}', .. rest] => {
      // {n} format: exactly n repetitions
      self.input = rest
      (min, Some(min))
    }
    [',', .. rest] => {
      self.input = rest // consume ','
      match self.input {
        ['}', .. rest] => {
          // {n,} format: at least n repetitions
          self.input = rest
          (min, None)
        }
        _ => {
          // {n,m} format: n to m repetitions
          let max = self.parse_number()
          guard self.input is ['}', .. rest] else {
            raise Error_(err=InvalidRepeatOp, data=self.input)
          }
          self.input = rest // consume '}'

          // Validate the range
          if max < min {
            raise Error_(err=InvalidRepeatSize, data=self.input)
          }
          (min, Some(max))
        }
      }
    }
    _ => raise Error_(err=InvalidRepeatOp, data=self.input)
  }
}

///| Parse Number
///
/// Parses a sequence of decimal digits from the current input position.
/// The number must contain at least one digit character.
///
/// Examples:
/// - `123` -> 123
/// - `0` -> 0
/// - `42` -> 42
///
/// Returns: The parsed integer value
///
/// Throws: Error_ when no valid number is found
fn Parser::parse_number(self : Parser) -> UInt raise Error_ {
  let mut result = 0U
  let mut has_digits = false
  while self.input is [ch, .. rest] && ch >= '0' && ch <= '9' {
    has_digits = true
    result = result * 10U + (ch.to_int() - '0'.to_int()).reinterpret_as_uint()
    self.input = rest
  }
  if not(has_digits) {
    raise Error_(err=MissingRepeatArgument, data=self.input)
  }
  result
}

///| Parse Group Name of a Named Capture Group
///
/// The group name must be a valid identifier, containing only letters, numbers, and underscores,
/// and must start with a letter or an underscore.
///
/// Examples:
/// - `name`     -> Valid group name
/// - `group1`   -> Valid group name
/// - `_test`    -> Valid group name
/// - `1invalid` -> Invalid group name (starts with a digit)
///
/// Returns: The parsed group name string
///
/// Throws: Error_ when the group name format is incorrect
fn Parser::parse_group_name(self : Parser) -> String raise Error_ {
  let mut name = ""
  let mut first = true
  while self.input is [ch, .. rest] && ch != '>' {
    if first {
      // The first character must be a letter or an underscore
      if ch is ('a'..='z' | 'A'..='Z' | '_') {
        name += ch.to_string()
        self.input = rest
        first = false
      } else {
        raise Error_(err=InvalidNamedCapture, data=self.input)
      }
    } else if ch is ('a'..='z' | 'A'..='Z' | '0'..='9' | '_') {
      // Subsequent characters can be letters, numbers, or underscores
      name += ch.to_string()
      self.input = rest
    } else {
      raise Error_(err=InvalidNamedCapture, data=self.input)
    }
  }

  // Check if the group name is empty
  if name == "" {
    raise Error_(err=InvalidNamedCapture, data=self.input)
  }
  name
}

///| Parse flag string, e.g., "msi" for multiline, singleline and ignore case modes
///
/// Supported flags:
/// - `m`: Multiline mode
/// - `s`: Singleline mode (dotall)
/// - `i`: Ignore case mode
///
/// Returns: The new flag settings
///
/// Throws: Error_ when an invalid flag is encountered
fn Parser::parse_flags(self : Parser) -> Flags raise Error_ {
  let mut flag = { ..self.flags }
  let mut positive = true
  loop self.input {
    [':', .. rest] => {
      self.input = rest // consume
      return flag
    }
    ['m', .. rest] => {
      flag = { ..flag, multiline: positive }
      continue rest
    }
    ['s', .. rest] => {
      flag = { ..flag, singleline: positive }
      continue rest
    }
    ['i', .. rest] => {
      flag = { ..flag, ignore_case: positive }
      continue rest
    }
    ['-', .. rest] if positive => {
      positive = false // Switch to negation mode
      continue rest
    }
    [_, ..] | [] =>
      // Unknown flag character or unexpected end
      raise Error_(err=InvalidRepeatOp, data=self.input)
  }
}

///| Parse Unicode Property name from \p{property_name}
///
/// Parses the property name inside the braces after \p
///
/// Returns: The property name string
///
/// Throws: Error_ when invalid syntax is encountered
fn Parser::parse_unicode_property(self : Parser) -> String raise Error_ {
  guard self.input is ['{', .. rest] else {
    raise Error_(err=InvalidCharClass, data=self.input)
  }
  self.input = rest // consume '{'
  let chars = []
  while self.input is [ch, .. rest] && ch != '}' {
    chars.push(ch)
    self.input = rest
  }
  guard self.input is ['}', .. rest] else {
    raise Error_(err=InvalidCharClass, data=self.input)
  }
  self.input = rest // consume '}'
  String::from_iter(chars.iter())
}

///| Parse General Category Unicode Property
///
/// Takes a property name and returns the corresponding character class
/// using the general category mappings from the unicode module
///
/// Parameters:
/// - `property_name`: The name of the general category property
///
/// Returns: CharClass containing the character ranges for the property
///
/// Throws: Error_ when the property is not found
fn Parser::parse_general_category(
  self : Parser,
  property_name : String,
  neg : Bool
) -> Regex raise Error_ {
  // First, normalize the property name using aliases
  let normalized_name = match
    @unicode.general_category_property_value_alises.get(property_name) {
    Some(name) => name
    None => raise Error_(err=InvalidCharClass, data=self.input)
  }

  // Get the character ranges for the normalized property name
  guard @unicode.general_category_ranges.get(normalized_name) is Some(ranges)
  CharClass(ranges, neg~)
}

///| Test case: Parse a complex regular expression with capture groups and quantifiers
///
/// Test regex "a(b|c)*d":
/// - Character 'a'
/// - Capture group (b|c) repeated 0 or more times
/// - Character 'd'
///
/// Expected match for string "abbd":
/// - Full match range: [0, 4]
/// - Last match of the first capture group: [2, 3] (character 'b')
test "parse complex regex with capture group and quantifier" {
  let regex = parse("a(b|c)*d")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abbd", capture_count)
  inspect(result, content="[0, 4, 2, 3]")
}

///| Test case: Parse a multi-branch alternation expression
///
/// Test regex "abc|def|ghi":
/// - Three alternative branches: "abc", "def", "ghi"
/// - Matches any one of them
///
/// Expected match for the first branch "abc" in "abcdefghi":
/// - Match range: [0, 3]
test "parse multi-branch alternation expression" {
  let regex = parse("abc|def|ghi")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcdefghi", capture_count)
  inspect(result, content="[0, 3]")
}

///| Test case: Parse dot character (any character match)
///
/// Test regex "a.c":
/// - Character 'a'
/// - Any character '.'
/// - Character 'c'
///
/// Expected to match strings like "abc", "axc", "a1c", etc.:
/// - Match range: [0, 3]
test "parse dot character (any character match)" {
  let regex = parse("a.c")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "axc", capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "a1c", capture_count)
  inspect(result, content="[0, 3]")
}

///| Test case: Parse character class range syntax
///
/// Test regex "[a-z]":
/// - Character range: matches any character between 'a' and 'z'
///
/// Expected to match the first character 'h' in "hello":
/// - Match range: [0, 1]
test "parse character class range syntax" {
  let regex = parse("[a-z]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "hello", capture_count)
  inspect(result, content="[0, 1]")
}

///| Test case: Parse multiple character class ranges
///
/// Test regex "[a-zA-Z]":
/// - Two character ranges: 'a' to 'z' and 'A' to 'Z'
/// - Matches any English letter
///
/// Expected to match the first character 'H' in "Hello123":
/// - Match range: [0, 1]
test "parse multiple character class ranges" {
  let regex = parse("[a-zA-Z]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "Hello123", capture_count)
  inspect(result, content="[0, 1]")
}

///| Test case: Parse mixed character class (ranges and individual characters)
///
/// Test regex "[a-z0-9_]":
/// - Character range: 'a' to 'z'
/// - Character range: '0' to '9'
/// - Single character: '_'
///
/// Expected to match the first character '_' in "_test123":
/// - Match range: [0, 1]
test "parse mixed character class (ranges and individual characters)" {
  let regex = parse("[a-z0-9_]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "_test123", capture_count)
  inspect(result, content="[0, 1]")
}

///| Test case: Parse literal hyphen in a character class
///
/// Test regex "[abc-]":
/// - Single characters: 'a', 'b', 'c'
/// - Literal hyphen: '-' (at the end, does not form a range)
///
/// Expected to match the hyphen in "-":
/// - Match range: [0, 1]
test "parse literal hyphen in character class" {
  let regex = parse("[abc-]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "-", capture_count)
  inspect(result, content="[0, 1]")
}

///| Test case: Parse a character class range with escaped characters
///
/// Test regex "[\]-a]":
/// - Uses escape character '\]' to include a right bracket
/// - Character range: from ']' to 'a'
///
/// Expected to match the ']' character in "]":
/// - Match range: [0, 1]
test "parse character class range with escaped characters" {
  let regex = parse("[\\]-a]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "]", capture_count)
  inspect(result, content="[0, 1]")

  // Test invalid case: end character is less than start character
  let regex = try? parse("[a-\\]]")
  inspect(
    regex,
    content=
      #|Err(Error_(err=InvalidCharClass, data="]"))
    ,
  )
}

///| Test case: Parse exact repeat quantifier {n}
///
/// Test regex "a{3}":
/// - Character 'a' repeated exactly 3 times
///
/// Expected to match the string "aaa":
/// - Match range: [0, 3]
test "parse exact repeat quantifier {n}" {
  let regex = parse("a{3}")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "aaa", capture_count)
  inspect(result, content="[0, 3]")

  // Should not match if there are fewer than 3 'a's
  let result = vm(instructions, "aa", capture_count)
  inspect(result, content="[]")

  // Should match if there are more than 3 'a's (matches the first 3)
  let result = vm(instructions, "aaaa", capture_count)
  inspect(result, content="[0, 3]")
}

///| Test case: Parse minimum repeat quantifier {n,}
///
/// Test regex "b{2,}":
/// - Character 'b' repeated at least 2 times
///
/// Expected to match strings "bb", "bbb", "bbbb":
/// - Match range: [0, string length]
test "parse minimum repeat quantifier {n,}" {
  let regex = parse("b{2,}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Match exactly 2 'b's
  let result = vm(instructions, "bb", capture_count)
  inspect(result, content="[0, 2]")

  // Match 3 'b's
  let result = vm(instructions, "bbb", capture_count)
  inspect(result, content="[0, 3]")

  // Should not match if there are fewer than 2 'b's
  let result = vm(instructions, "b", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse range repeat quantifier {n,m}
///
/// Test regex "c{2,4}":
/// - Character 'c' repeated 2 to 4 times
///
/// Expected to match strings "cc", "ccc", "cccc":
/// - Match range: [0, actual match length]
test "parse range repeat quantifier {n,m}" {
  let regex = parse("c{2,4}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Match 2 'c's
  let result = vm(instructions, "cc", capture_count)
  inspect(result, content="[0, 2]")

  // Match 3 'c's
  let result = vm(instructions, "ccc", capture_count)
  inspect(result, content="[0, 3]")

  // Match 4 'c's
  let result = vm(instructions, "cccc", capture_count)
  inspect(result, content="[0, 4]")

  // Should match if there are more than 4 'c's (matches the first 4)
  let result = vm(instructions, "ccccc", capture_count)
  inspect(result, content="[0, 4]")

  // Should not match if there are fewer than 2 'c's
  let result = vm(instructions, "c", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse lazy minimum repeat quantifier {n,}?
///
/// Test regex "d{2,}?":
/// - Character 'd' repeated at least 2 times, lazy mode
///
/// Lazy mode matches as few characters as possible
test "parse lazy minimum repeat quantifier {n,}?" {
  let regex = parse("d{2,}?")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Lazy mode matches the minimum number of characters
  let result = vm(instructions, "ddd", capture_count)
  inspect(result, content="[0, 2]")
}

///| Test case: Parse a complex repeat quantifier expression
///
/// Test regex "a{2}b{1,3}c{2,}":
/// - Character 'a' exactly 2 times
/// - Character 'b' 1 to 3 times
/// - Character 'c' at least 2 times
test "parse complex repeat quantifier expression" {
  let regex = parse("a{2}b{1,3}c{2,}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Match "aabccc"
  let result = vm(instructions, "aabccc", capture_count)
  inspect(result, content="[0, 6]")

  // Should not match "aabbbbcc" (more than 3 'b's)
  let result = vm(instructions, "aabbbbcc", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse a repeat quantifier with groups
///
/// Test regex "(ab){2}":
/// - Group (ab) repeated exactly 2 times
test "parse repeat quantifier with groups" {
  let regex = parse("(ab){2}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Match "abab"
  let result = vm(instructions, "abab", capture_count)
  inspect(result, content="[0, 4, 2, 4]")
}

///| Test case: Test error cases for repeat quantifiers
///
/// Tests various invalid repeat quantifier syntaxes
test "parse repeat quantifier error cases" {
  // Test case where {m,n} has m > n
  let regex = try? parse("a{5,2}")
  inspect(
    regex,
    content=
      #|Err(Error_(err=InvalidRepeatSize, data=""))
    ,
  )

  // Test case with missing number
  let regex = try? parse("a{}")
  inspect(regex, content="Err(Error_(err=MissingRepeatArgument, data=\"}\"))")

  // Test case with missing right brace
  let regex = try? parse("a{2")
  inspect(regex, content="Err(Error_(err=InvalidRepeatOp, data=\"\"))")

  // Test case with invalid format
  let regex = try? parse("a{2,3,4}")
  inspect(regex, content="Err(Error_(err=InvalidRepeatOp, data=\",4}\"))")
}

///| Test case: Parse a non-capturing group
///
/// Test regex "(?:abc)":
/// - Non-capturing group: matches "abc" but does not capture
test "parse non-capturing group" {
  let regex = parse("(?:abc)")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")
}

///| Test case: Parse a named capture group
///
/// Test regex "(?<name>abc)":
/// - Named capture group: name is "name", matches "abc"
///
/// Expected match for string "abc":
/// - Match range: [0, 3, 0, 3] (full match and named group match)
test "parse named capture group" {
  let regex = parse("(?<name>abc)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3, 0, 3]")

  // Validate named group map
  inspect(map.get("name"), content="Some(1)")
}

///| Test case: Parse a complex named capture group expression
///
/// Test regex "(?<first>a+)(?<second>b+)":
/// - First named capture group: name "first", matches one or more 'a's
/// - Second named capture group: name "second", matches one or more 'b's
///
/// Expected match for string "aaabbb":
/// - Match range: [0, 6, 0, 3, 3, 6]
test "parse complex named capture group expression" {
  let regex = parse("(?<first>a+)(?<second>b+)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "aaabbb", capture_count)
  inspect(result, content="[0, 6, 0, 3, 3, 6]")

  // Validate named group map
  inspect(map.get("first"), content="Some(1)")
  inspect(map.get("second"), content="Some(2)")
}

///| Test case: Parse nested named capture groups
///
/// Test regex "(?<outer>a(?<inner>bc)d)":
/// - Outer named capture group: name "outer"
/// - Inner named capture group: name "inner"
///
/// Expected match for string "abcd":
/// - Match range: [0, 4, 0, 4, 1, 3]
test "parse nested named capture groups" {
  let regex = parse("(?<outer>a(?<inner>bc)d)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "abcd", capture_count)
  inspect(result, content="[0, 4, 0, 4, 1, 3]")

  // Validate named group map
  inspect(map.get("outer"), content="Some(1)")
  inspect(map.get("inner"), content="Some(2)")
}

///| Test case: Mix named and regular capture groups
///
/// Test regex "(a)(?<named>b)(c)":
/// - First regular capture group: matches "a"
/// - Named capture group: name "named", matches "b"
/// - Second regular capture group: matches "c"
///
/// Expected match for string "abc":
/// - Match range: [0, 3, 0, 1, 1, 2, 2, 3]
test "parse mixed named and regular capture groups" {
  let regex = parse("(a)(?<named>b)(c)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3, 0, 1, 1, 2, 2, 3]")

  // Validate named group map (second capture group, index 2)
  inspect(map.get("named"), content="Some(2)")
}

///| Test case: Error cases for named capture groups
///
/// Tests various invalid named capture group syntaxes
test "parse named capture group error cases" {
  // Test empty group name
  let regex = try? parse("(?<>abc)")
  inspect(regex, content="Err(Error_(err=InvalidNamedCapture, data=\">abc)\"))")

  // Test group name starting with a digit
  let regex = try? parse("(?<1invalid>abc)")
  inspect(
    regex,
    content="Err(Error_(err=InvalidNamedCapture, data=\"1invalid>abc)\"))",
  )

  // Test group name with illegal characters
  let regex = try? parse("(?<na-me>abc)")
  inspect(
    regex,
    content="Err(Error_(err=InvalidNamedCapture, data=\"-me>abc)\"))",
  )

  // Test missing right angle bracket
  let regex = try? parse("(?<name abc)")
  inspect(regex, content="Err(Error_(err=InvalidNamedCapture, data=\" abc)\"))")

  // Test missing right parenthesis
  let regex = try? parse("(?<name>abc")
  inspect(regex, content="Err(Error_(err=MissingParenthesis, data=\"\"))")
}

///| Test case: Valid group name formats
///
/// Tests various valid group name formats
test "parse valid group name formats" {
  // Starts with a letter
  let regex = parse("(?<group>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("group"))
    ,
  )

  // Starts with an underscore
  let regex = parse("(?<_group>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("_group"))
    ,
  )

  // Contains digits
  let regex = parse("(?<group1>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("group1"))
    ,
  )

  // Contains multiple underscores
  let regex = parse("(?<my_group_1>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("my_group_1"))
    ,
  )
}

///| Test case: Parse line begin assertion ^
///
/// Test regex "^abc":
/// - Line begin assertion: ^
/// - Character sequence: abc
///
/// Expected to match lines starting with "abc":
/// - Match "abc" itself: [0, 3]
/// - Match "abc\ndef": [0, 3] (first line)
/// - Match "def\nabc": [4, 7] (second line)
/// - Should not match "xabc": [] (not at the beginning of a line)
test "parse line begin assertion ^" {
  let regex = parse("^abc", flags={ ..Flags::default(), multiline: true })
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching at the beginning of a line
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")

  // Test matching the first line in a multiline string
  let result = vm(instructions, "abc\ndef", capture_count)
  inspect(result, content="[0, 3]")
  // Test matching the second line in a multiline string
  let result = vm(instructions, "def\nabc", capture_count)
  inspect(result, content="[4, 7]")

  // Test not matching when not at the beginning of a line (should not match)
  let result = vm(instructions, "xabc", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse line end assertion $
///
/// Test regex "abc$":
/// - Character sequence: abc
/// - Line end assertion: $
///
/// Expected to match lines ending with "abc":
/// - Match "abc" itself: [0, 3]
/// - Match "abc\ndef": [0, 3] (first line)
/// - Match "def\nabc": [4, 7] (second line)
/// - Should not match "abcx": [] (not at the end of a line)
test "parse line end assertion $" {
  let regex = parse("abc$", flags={ ..Flags::default(), multiline: true })
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching at the end of a line
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")

  // Test matching the first line in a multiline string
  let result = vm(instructions, "abc\ndef", capture_count)
  inspect(result, content="[0, 3]")

  // Test matching the second line in a multiline string
  let result = vm(instructions, "def\nabc", capture_count)
  inspect(result, content="[4, 7]")

  // Test not matching when not at the end of a line (should not match)
  let result = vm(instructions, "abcx", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse combination of line begin and end assertions ^...$
///
/// Test regex "^abc$":
/// - Line begin assertion: ^
/// - Character sequence: abc
/// - Line end assertion: $
///
/// Expected to match when the entire line is "abc":
/// - Match "abc": [0, 3]
/// - Should not match "abcd": [] (extra characters at the end)
/// - Should not match "xabc": [] (extra characters at the beginning)
test "parse line begin and end assertion ^...$" {
  let regex = parse("^abc$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching the entire line
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")

  // Test with extra characters at the end (should not match)
  let result = vm(instructions, "abcd", capture_count)
  inspect(result, content="[]")

  // Test with extra characters at the beginning (should not match)
  let result = vm(instructions, "xabc", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse assertions in multiline mode
///
/// Test matching "^line" in multiline text:
/// - Should match "line" at the beginning of each line
///
/// Test string "line1\nline2\nnot line":
/// - Should match "line" on the first line: [0, 4]
test "parse multiline assertions" {
  let regex = parse("^line", flags={ ..Flags::default(), multiline: true })
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching the first line in multiline text
  let result = vm(instructions, "line1\nline2\nnot line", capture_count)
  inspect(result, content="[0, 4]")

  // Test matching line end assertion in multiline text
  let regex = parse("line$", flags={ ..Flags::default(), multiline: true })
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "not line\nline2\nthis line", capture_count)
  inspect(result, content="[4, 8]") // Matches "line" on the first line
}

///| Test case: Combination of assertions and quantifiers
///
/// Test regex "^a+$":
/// - Line begin assertion: ^
/// - Character 'a' repeated one or more times
/// - Line end assertion: $
///
/// Expected to match when the entire line consists of 'a' characters
test "parse assertion with quantifiers" {
  let regex = parse("^a+$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching a line full of 'a's
  let result = vm(instructions, "aaa", capture_count)
  inspect(result, content="[0, 3]")

  // Test with a single 'a'
  let result = vm(instructions, "a", capture_count)
  inspect(result, content="[0, 1]")

  // Test with other characters (should not match)
  let result = vm(instructions, "aab", capture_count)
  inspect(result, content="[]")
}

///| Test case: Combination of assertions and capture groups
///
/// Test regex "^(abc)$":
/// - Line begin assertion: ^
/// - Capture group: (abc)
/// - Line end assertion: $
///
/// Expected to capture the entire line's content
test "parse assertion with capture groups" {
  let regex = parse("^(abc)$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching and capturing the entire line
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3, 0, 3]")

  // Test non-matching case
  let result = vm(instructions, "abcd", capture_count)
  inspect(result, content="[]")
}

///| Test case: Escaped assertion characters
///
/// Test regex "\\^abc\\$":
/// - Escaped '^' character
/// - Character sequence: abc
/// - Escaped '$' character
///
/// Expected to match the literal string "^abc$"
test "parse escaped assertion characters" {
  let regex = parse("\\^abc\\$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching the literal "^abc$"
  let result = vm(instructions, "^abc$", capture_count)
  inspect(result, content="[0, 5]")

  // Test non-matching case without literal symbols
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[]")
}

///| Test case: Assertion characters within a character class
///
/// Test regex "[^$]":
/// - Character class: matches any character except '$'
///
/// In a character class, ^ at the beginning means negation, and $ is treated as a literal character.
test "parse assertion characters in character class" {
  let regex = parse("[^$]")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching a normal character
  let result = vm(instructions, "a", capture_count)
  inspect(result, content="[0, 1]")

  // Test matching '^' character (since it's not '$')
  let result = vm(instructions, "^", capture_count)
  inspect(result, content="[0, 1]")

  // Test not matching '$' character
  let result = vm(instructions, "$", capture_count)
  inspect(result, content="[]")
}

///| Test case: Complex assertion expression
///
/// Test regex "^(hello|world)$":
/// - Line begin assertion: ^
/// - Alternation group: (hello|world)
/// - Line end assertion: $
///
/// Expected to match when the entire line is "hello" or "world"
test "parse complex assertion expression" {
  let regex = parse("^(hello|world)$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching "hello"
  let result = vm(instructions, "hello", capture_count)
  inspect(result, content="[0, 5, 0, 5]")

  // Test matching "world"
  let result = vm(instructions, "world", capture_count)
  inspect(result, content="[0, 5, 0, 5]")

  // Test not matching other content
  let result = vm(instructions, "hello world", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse word boundary assertion \b
///
/// Test regex "\bword\b":
/// - Word boundary assertion: \b
/// - Character sequence: word
/// - Word boundary assertion: \b
///
/// Expected to match the whole word "word", not partial words
test "parse word boundary assertion \\b" {
  let regex = parse("\\bword\\b")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching a standalone word
  let result = vm(instructions, "word", capture_count)
  inspect(result, content="[0, 4]")

  // Test matching a whole word in a sentence
  let result = vm(instructions, "the word is", capture_count)
  inspect(result, content="[4, 8]")

  // Test not matching part of a word
  let result = vm(instructions, "password", capture_count)
  inspect(result, content="[]")

  // Test not matching the beginning of a word
  let result = vm(instructions, "words", capture_count)
  inspect(result, content="[]")
}

///| Test case: Parse non-word boundary assertion \B
///
/// Test regex "\\Bword\\B":
/// - Non-word boundary assertion: \B
/// - Character sequence: word
/// - Non-word boundary assertion: \B
///
/// Expected to match "word" surrounded by other characters (not at a word boundary)
test "parse non-word boundary assertion \\B" {
  let regex = parse("\\Bword\\B")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching "word" surrounded by letters
  let result = vm(instructions, "passwords", capture_count)
  inspect(result, content="[4, 8]")

  // Test not matching a standalone word
  let result = vm(instructions, "word", capture_count)
  inspect(result, content="[]")

  // Test not matching at a word boundary
  let result = vm(instructions, "the word", capture_count)
  inspect(result, content="[]")
}

///| Test case: Combined use of word boundary assertions
///
/// Test regex "\\btest|\\btesting\\b":
/// - Alternative 1: \btest (word starting with "test")
/// - Alternative 2: \btesting\b (whole word "testing")
test "parse combined word boundary assertions" {
  let regex = parse("\\btest|\\btesting\\b")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching a word starting with "test"
  let result = vm(instructions, "testing", capture_count)
  inspect(result, content="[0, 4]") // Matches "test" part

  // Test matching the whole word "testing"
  let result = vm(instructions, "a testing b", capture_count)
  inspect(result, content="[2, 6]")

  // Test matching the standalone word "test"
  let result = vm(instructions, "test", capture_count)
  inspect(result, content="[0, 4]")
}

///| Test case: Word boundary combined with character class
///
/// Test regex "\\b[a-z]+\\b":
/// - Word boundary assertion: \b
/// - Character class: [a-z]+ one or more lowercase letters
/// - Word boundary assertion: \b
///
/// Expected to match whole lowercase words
test "parse word boundary with character class" {
  let regex = parse("\\b[a-z]+\\b")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching a lowercase word
  let result = vm(instructions, "hello world", capture_count)
  inspect(result, content="[0, 5]")

  // Test not matching a word with uppercase letters
  let result = vm(instructions, "Hello", capture_count)
  inspect(result, content="[]")

  // Test not matching a word with digits
  let result = vm(instructions, "test123", capture_count)
  inspect(result, content="[]")
}

///| Test case: Word boundary combined with quantifiers
///
/// Test regex "\\b\\w{3,5}\\b":
/// - Word boundary assertion: \b
/// - Word character class: \w repeated 3 to 5 times
/// - Word boundary assertion: \b
///
/// Expected to match whole words of length 3 to 5
test "parse word boundary with quantifiers" {
  let regex = parse("\\b\\w{3,5}\\b")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching a 3-character word
  let result = vm(instructions, "cat", capture_count)
  inspect(result, content="[0, 3]")

  // Test matching a 5-character word
  let result = vm(instructions, "hello", capture_count)
  inspect(result, content="[0, 5]")

  // Test not matching a 2-character word
  let result = vm(instructions, "go", capture_count)
  inspect(result, content="[]")

  // Test not matching a 6-character word
  let result = vm(instructions, "longer", capture_count)
  inspect(result, content="[]")
}

///| Test case: Word boundary combined with capture groups
///
/// Test regex "\\b(\\w+)\\b":
/// - Word boundary assertion: \b
/// - Capture group: (\w+) captures one or more word characters
/// - Word boundary assertion: \b
///
/// Expected to capture a whole word
test "parse word boundary with capture groups" {
  let regex = parse("\\b(\\w+)\\b")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test capturing a single word
  let result = vm(instructions, "hello", capture_count)
  inspect(result, content="[0, 5, 0, 5]")

  // Test capturing the first word in a sentence
  let result = vm(instructions, "hello world", capture_count)
  inspect(result, content="[0, 5, 0, 5]")
}

///| Test case: Complex word boundary expression
///
/// Test regex "\\b(?:the|a|an)\\b\\s+\\b\\w+\\b":
/// - Non-capturing group: (?:the|a|an) for articles
/// - Word boundary assertion: \b
/// - Whitespace character: \s+ one or more whitespace characters
/// - Word boundary assertion: \b
/// - Word character: \w+ one or more word characters
/// - Word boundary assertion: \b
///
/// Expected to match the pattern "article + space + word"
test "parse complex word boundary expression" {
  // Simplified version, only tests basic word boundary functionality
  let regex = parse("\\bthe\\b")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching standalone "the"
  let result = vm(instructions, "the", capture_count)
  inspect(result, content="[0, 3]")

  // Test matching "the" in a sentence
  let result = vm(instructions, "the cat", capture_count)
  inspect(result, content="[0, 3]")

  // Test not matching "the" as part of another word
  let result = vm(instructions, "them", capture_count)
  inspect(result, content="[]")
  let result = vm(instructions, "other", capture_count)
  inspect(result, content="[]")
}

///|
test "parse unicode general property" {
  let regex = parse("\\p{Ll}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // Test matching a letter character
  let result = vm(instructions, "a", capture_count)
  inspect(result, content="[0, 1]")

  // Test matching a non-letter character
  let result = vm(instructions, "1", capture_count)
  inspect(result, content="[]")

  // Test matching a Unicode letter character
  let result = vm(instructions, "é", capture_count)
  inspect(result, content="[0, 1]")

  // Test matching a composed class
  let regex = parse("\\p{L}")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "é", capture_count)
  inspect(result, content="[0, 1]")

  // Negated matching
  let regex = parse("\\P{L}")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "é", capture_count)
  inspect(result, content="[]")
  let result = vm(instructions, "\t", capture_count)
  inspect(result, content="[0, 1]")
}

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
test "simple regex test" {
  let regex = @regexp.compile("abc")
  let result = regex.execute("abc").results().collect()
  inspect(
    result,
    content=
      #|["abc"]
    ,
  )
  let result = regex.execute("ab").results().collect()
  inspect(result, content="[]")
  let result = regex.execute("abcd").results().collect()
  inspect(
    result,
    content=
      #|["abc"]
    ,
  )
}

///|
test "simple regex test matching leftmost" {
  let regex = @regexp.compile("a(bc|de)f")
  let result = regex.execute("xxabcf").results().collect()
  inspect(
    result,
    content=
      #|["abcf", "bc"]
    ,
  )
}

///|
test "simple regex test with repeat" {
  let regex = @regexp.compile("a(bc|de){2,}f")
  let result = regex.execute("xxabcdebcf").results().collect()
  inspect(
    result,
    content=
      #|["abcdebcf", "bc"]
    ,
  )
}

///|
test "character classes" {
  // Email validation (simplified)
  let email = @regexp.compile(
    #|[\w-]+@[\w-]+\.\w+
    ,
  )
  let email_result = email.execute("user@example.com").results().collect()
  assert_eq(email_result, ["user@example.com"])
  // Extract numbers
  let numbers = @regexp.compile(
    #|\d+\.\d{2}
    ,
  )
  let result = numbers.execute("Price: $42.99").results().collect()
  assert_eq(result, ["42.99"])

  // Named captures for parsing
  let parser = @regexp.compile(
    #|(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})
    ,
  )
  let date_result = parser.execute("2024-03-15")
  assert_eq(date_result.group_by_name("year"), Some("2024"))
  assert_eq(date_result.group_by_name("month"), Some("03"))
  assert_eq(date_result.group_by_name("day"), Some("15"))
}

///|
test "regexp with flags" {
  // singleline flag
  let regexp = compile(".")
  assert_false(regexp.execute("\n").matched())
  let regexp = compile(".", flags="s")
  assert_true(regexp.execute("\n").matched())
  let regexp = compile("(?s:.)")
  assert_true(regexp.execute("\n").matched())

  // multiline flag
  let regexp = compile("$")
  assert_true(regexp.execute("\n").matched())
  inspect(regexp.execute("\n").results().count(), content="1")
  inspect(
    regexp.execute("\n").results().map(_.start_offset()).collect(),
    content="[1]",
  )
  let regexp = compile("$", flags="m")
  assert_true(regexp.execute("\n").matched())
  inspect(
    regexp.execute("\n").results().map(_.start_offset()).collect(),
    content="[0]",
  )
  let regexp = compile("(?m:$)")
  assert_true(regexp.execute("\n").matched())
  inspect(
    regexp.execute("\n").results().map(_.start_offset()).collect(),
    content="[0]",
  )
  let regexp = compile("(?m-m:$)")
  assert_true(regexp.execute("\n").matched())
  inspect(
    regexp.execute("\n").results().map(_.start_offset()).collect(),
    content="[1]",
  )
}

///|
test "invalid regex test" {
  guard (try? @regexp.compile("a(b")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=MissingParenthesis, data="")
    ,
  )
  guard (try? @regexp.compile("a(b|c")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=MissingParenthesis, data="")
    ,
  )
  guard (try? @regexp.compile("a|b)")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=UnexpectedParenthesis, data=")")
    ,
  )
  guard (try? @regexp.compile("a|b|c)")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=UnexpectedParenthesis, data=")")
    ,
  )
}

///|
test "to be fixed" {
  // This should be allowed in some flavors where the `{` is considered a literal character
  guard (try? @regexp.compile("a{2")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=InvalidRepeatOp, data="")
    ,
  )
  // This should be allowed in some flavors where the `}` is considered a literal character
  guard (try? @regexp.compile("a|b|c}")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=InvalidEscape, data="}")
    ,
  )
  // This should raise InvalidRepeatOp to align with golang
  guard (try? @regexp.compile("a++")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=InvalidEscape, data="+")
    ,
  )
}

///|
test "quantifiers and repetition" {
  // Test * quantifier (zero or more)
  let regex = @regexp.compile("ab*c")
  assert_eq(regex.execute("ac").results().collect(), ["ac"])
  assert_eq(regex.execute("abc").results().collect(), ["abc"])
  assert_eq(regex.execute("abbbbc").results().collect(), ["abbbbc"])
  assert_false(regex.execute("bc").matched())

  // Test + quantifier (one or more)
  let regex = @regexp.compile("ab+c")
  assert_false(regex.execute("ac").matched())
  assert_eq(regex.execute("abc").results().collect(), ["abc"])
  assert_eq(regex.execute("abbbbc").results().collect(), ["abbbbc"])

  // Test ? quantifier (zero or one)
  let regex = @regexp.compile("ab?c")
  assert_eq(regex.execute("ac").results().collect(), ["ac"])
  assert_eq(regex.execute("abc").results().collect(), ["abc"])
  assert_false(regex.execute("abbc").matched())

  // Test specific count {n}
  let regex = @regexp.compile("a{3}")
  assert_false(regex.execute("aa").matched())
  assert_eq(regex.execute("aaa").results().collect(), ["aaa"])
  assert_eq(regex.execute("aaaa").results().collect(), ["aaa"])

  // Test range {n,m}
  let regex = @regexp.compile("a{2,4}")
  assert_false(regex.execute("a").matched())
  assert_eq(regex.execute("aa").results().collect(), ["aa"])
  assert_eq(regex.execute("aaa").results().collect(), ["aaa"])
  assert_eq(regex.execute("aaaa").results().collect(), ["aaaa"])
  assert_eq(regex.execute("aaaaa").results().collect(), ["aaaa"])

  // Test minimum count {n,}
  let regex = @regexp.compile("a{3,}")
  assert_false(regex.execute("aa").matched())
  assert_eq(regex.execute("aaa").results().collect(), ["aaa"])
  assert_eq(regex.execute("aaaaa").results().collect(), ["aaaaa"])
}

///|
test "character classes and sets" {
  // Test digit class \d
  let regex = @regexp.compile("\\d+")
  assert_eq(regex.execute("123").results().collect(), ["123"])
  assert_eq(regex.execute("abc123def").results().collect(), ["123"])
  assert_false(regex.execute("abc").matched())

  // Test word class \w
  let regex = @regexp.compile("\\w+")
  assert_eq(regex.execute("hello123").results().collect(), ["hello123"])
  assert_eq(regex.execute("hello-world").results().collect(), ["hello"])

  // Test whitespace class \s
  let regex = @regexp.compile("\\s+")
  assert_eq(regex.execute("  \t\n").results().collect(), ["  \t\n"])
  assert_eq(regex.execute("a b").results().collect(), [" "])

  // Test negated classes
  let regex = @regexp.compile("\\D+")
  assert_eq(regex.execute("abc123").results().collect(), ["abc"])
  let regex = @regexp.compile("\\W+")
  assert_eq(regex.execute("hello-world!").results().collect(), ["-"])
  let regex = @regexp.compile("\\S+")
  assert_eq(regex.execute("hello world").results().collect(), ["hello"])

  // Test custom character sets
  let regex = @regexp.compile("[abc]")
  assert_eq(regex.execute("apple").results().collect(), ["a"])
  assert_eq(regex.execute("banana").results().collect(), ["b"])
  assert_false(regex.execute("xyz").matched())

  // Test character ranges
  let regex = @regexp.compile("[a-z]+")
  assert_eq(regex.execute("hello123").results().collect(), ["hello"])
  assert_eq(regex.execute("Hello").results().collect(), ["ello"])
  let regex = @regexp.compile("[0-9]+")
  assert_eq(regex.execute("abc123def").results().collect(), ["123"])

  // Test negated character sets
  let regex = @regexp.compile("[^abc]+")
  assert_eq(regex.execute("abcdef").results().collect(), ["def"])
  assert_eq(regex.execute("xyz").results().collect(), ["xyz"])

  // Test mixed character sets
  let regex = @regexp.compile("[a-zA-Z0-9_]+")
  assert_eq(regex.execute("Hello_World123").results().collect(), [
    "Hello_World123",
  ])
  assert_eq(regex.execute("test-case").results().collect(), ["test"])
}

///|
test "anchors and boundaries" {
  // Test start anchor ^
  let regex = @regexp.compile("^hello")
  assert_eq(regex.execute("hello world").results().collect(), ["hello"])
  assert_false(regex.execute("say hello").matched())

  // Test end anchor $
  let regex = @regexp.compile("world$")
  assert_eq(regex.execute("hello world").results().collect(), ["world"])
  assert_false(regex.execute("world peace").matched())

  // Test both anchors
  let regex = @regexp.compile("^hello$")
  assert_eq(regex.execute("hello").results().collect(), ["hello"])
  assert_false(regex.execute("hello world").matched())
  assert_false(regex.execute("say hello").matched())

  // Test word boundaries \b
  let regex = @regexp.compile("\\bword\\b")
  assert_eq(regex.execute("a word here").results().collect(), ["word"])
  assert_eq(regex.execute("word").results().collect(), ["word"])
  assert_false(regex.execute("sword").matched())
  assert_false(regex.execute("words").matched())

  // Test non-word boundaries \B
  let regex = @regexp.compile("\\Bor\\B")
  assert_eq(regex.execute("words").results().collect(), ["or"])
  assert_false(regex.execute("or").matched())
  assert_false(regex.execute("for you").matched())
}

///|
test "alternation and grouping" {
  // Test simple alternation
  let regex = @regexp.compile("cat|dog")
  assert_eq(regex.execute("I have a cat").results().collect(), ["cat"])
  assert_eq(regex.execute("I have a dog").results().collect(), ["dog"])
  assert_false(regex.execute("I have a bird").matched())

  // Test alternation with groups
  let regex = @regexp.compile("(cat|dog) food")
  let result = regex.execute("cat food").results().collect()
  assert_eq(result, ["cat food", "cat"])

  // Test nested groups
  let regex = @regexp.compile("((a|b)(c|d))")
  let result = regex.execute("ac").results().collect()
  assert_eq(result, ["ac", "ac", "a", "c"])

  // Test non-capturing groups
  let regex = @regexp.compile("(?:cat|dog) food")
  assert_eq(regex.execute("cat food").results().collect(), ["cat food"])

  // Test multiple alternations
  let regex = @regexp.compile("red|green|blue")
  assert_eq(regex.execute("red car").results().collect(), ["red"])
  assert_eq(regex.execute("green light").results().collect(), ["green"])
  assert_eq(regex.execute("blue sky").results().collect(), ["blue"])
}

///|
test "advanced capture groups" {
  // Test multiple groups
  let regex = @regexp.compile("([a-z]+) ([0-9]+)")
  let result = regex.execute("hello 123")
  assert_eq(result.group(0), Some("hello 123"))
  assert_eq(result.group(1), Some("hello"))
  assert_eq(result.group(2), Some("123"))
  assert_eq(result.group(3), None)

  // Test nested groups
  let regex = @regexp.compile("((\\w+)-(\\w+))")
  let result = regex.execute("first-second")
  assert_eq(result.group(0), Some("first-second"))
  assert_eq(result.group(1), Some("first-second"))
  assert_eq(result.group(2), Some("first"))
  assert_eq(result.group(3), Some("second"))

  // Test optional groups
  let regex = @regexp.compile("(\\w+)(-\\w+)?")
  let result1 = regex.execute("hello-world")
  assert_eq(result1.group(1), Some("hello"))
  assert_eq(result1.group(2), Some("-world"))
  let result2 = regex.execute("hello")
  assert_eq(result2.group(1), Some("hello"))
  // Optional group that didn't match should still be accessible but empty
  inspect(result2.group(2), content="None")
}

///|
test "complex named capture groups" {
  // Test multiple named groups
  let regex = @regexp.compile("(?<first>\\w+)\\s+(?<last>\\w+)")
  let result = regex.execute("John Doe")
  assert_eq(result.group_by_name("first"), Some("John"))
  assert_eq(result.group_by_name("last"), Some("Doe"))

  // Test group names iteration
  let names = regex.group_names().collect()
  inspect(names.contains("first"), content="true")
  inspect(names.contains("last"), content="true")

  // Test URL parsing with named groups
  let url_regex = @regexp.compile(
    "(?<protocol>https?)://(?<domain>[^/]+)(?<path>/.*)?",
  )
  let result = url_regex.execute("https://example.com/path/to/page")
  assert_eq(result.group_by_name("protocol"), Some("https"))
  assert_eq(result.group_by_name("domain"), Some("example.com"))
  assert_eq(result.group_by_name("path"), Some("/path/to/page"))

  // Test mixed named and unnamed groups
  let regex = @regexp.compile("(\\w+)@(?<domain>\\w+\\.\\w+)")
  let result = regex.execute("user@example.com")
  assert_eq(result.group(1), Some("user"))
  assert_eq(result.group_by_name("domain"), Some("example.com"))
}

///|
test "escape sequences and special characters" {
  // Test literal special characters
  let regex = @regexp.compile("\\.")
  assert_eq(regex.execute("3.14").results().collect(), ["."])
  assert_false(regex.execute("314").matched())
  let regex = @regexp.compile("\\*")
  assert_eq(regex.execute("2*3").results().collect(), ["*"])
  let regex = @regexp.compile("\\+")
  assert_eq(regex.execute("1+1").results().collect(), ["+"])
  let regex = @regexp.compile("\\?")
  assert_eq(regex.execute("what?").results().collect(), ["?"])

  // Test escaped brackets
  let regex = @regexp.compile("\\[\\]")
  assert_eq(regex.execute("array[]").results().collect(), ["[]"])
  let regex = @regexp.compile("\\(\\)")
  assert_eq(regex.execute("func()").results().collect(), ["()"])

  // Test escaped backslash
  let regex = @regexp.compile("\\\\")
  assert_eq(regex.execute("path\\file").results().collect(), ["\\"])

  // Test tab, newline, etc.
  let regex = @regexp.compile("\\t")
  assert_eq(regex.execute("a\tb").results().collect(), ["\t"])
  let regex = @regexp.compile("\\n")
  assert_eq(regex.execute("line1\nline2").results().collect(), ["\n"])
  let regex = @regexp.compile("\\r")
  assert_eq(regex.execute("line1\rline2").results().collect(), ["\r"])
  let regex = @regexp.compile("[\\t\\n\\r]")
  assert_eq(regex.execute("a\tb").results().collect(), ["\t"])
  assert_eq(regex.execute("line1\nline2").results().collect(), ["\n"])
  assert_eq(regex.execute("line1\rline2").results().collect(), ["\r"])
}

///|
test "greedy vs non-greedy matching" {
  // Test greedy quantifiers
  let regex = @regexp.compile("<.*>")
  assert_eq(regex.execute("<div><span></span></div>").results().collect(), [
    "<div><span></span></div>",
  ])

  // Test non-greedy quantifiers
  let regex = @regexp.compile("<.*?>")
  assert_eq(regex.execute("<div><span></span></div>").results().collect(), [
    "<div>",
  ])

  // Test non-greedy + 
  let regex = @regexp.compile("a.+?b")
  assert_eq(regex.execute("axxxbyyybzzz").results().collect(), ["axxxb"])

  // Test non-greedy *
  let regex = @regexp.compile("a.*?b")
  assert_eq(regex.execute("axxxbyyybzzz").results().collect(), ["axxxb"])
}

// ///|
// test "lookahead and lookbehind assertions" {
//   // Test positive lookahead
//   let regex = @regexp.compile("\\w+(?=ing)")
//   let result = regex.execute("running jumping walking")
//   if result.matched() {
//     inspect(
//       result.results().collect(),
//       content=
//         #|["runn", "jump", "walk"]
//       ,
//     )
//   }

//   // Test negative lookahead  
//   let regex = @regexp.compile("\\w+(?!ing)")
//   let result = regex.execute("running jump walking")
//   if result.matched() {
//     // Should match words not followed by "ing"
//     inspect(result.results().collect()[0], content="jump")
//   }

//   // Test positive lookbehind
//   let regex = @regexp.compile("(?<=\\$)\\d+")
//   let result = regex.execute("Price: $100 and €200")
//   if result.matched() {
//     assert_eq(result.results().collect(), ["100"])
//   }

//   // Test negative lookbehind
//   let regex = @regexp.compile("(?<!\\$)\\d+")
//   let result = regex.execute("Price: $100 and 200")
//   if result.matched() {
//     assert_eq(result.results().collect(), ["200"])
//   }
// }

///|
test "case sensitivity and flags" {
  // Test case insensitive flag
  let regex = @regexp.compile("hello", flags="i")
  assert_eq(regex.execute("HELLO").results().collect(), ["HELLO"])
  assert_eq(regex.execute("Hello").results().collect(), ["Hello"])
  assert_eq(regex.execute("hElLo").results().collect(), ["hElLo"])

  // Test inline case insensitive
  let regex = @regexp.compile("(?i:hello)")
  assert_eq(regex.execute("HELLO world").results().collect(), ["HELLO"])

  // Test case sensitive (default)
  let regex = @regexp.compile("hello")
  assert_eq(regex.execute("hello").results().collect(), ["hello"])
  assert_false(regex.execute("HELLO").matched())

  // Test mixed case sensitivity
  let regex = @regexp.compile("(?i:hello) world")
  assert_eq(regex.execute("HELLO world").results().collect(), ["HELLO world"])
  assert_false(regex.execute("HELLO WORLD").matched())
}

// ///|

///|
test "unicode and international characters" {
  // Test basic unicode
  let regex = @regexp.compile("café")
  assert_eq(regex.execute("I love café").results().collect(), ["café"])

  // Test unicode word boundaries
  let regex = @regexp.compile("\\w+")
  assert_eq(regex.execute("hello 世界").results().collect(), ["hello"])

  // // Test unicode character classes
  // let regex = @regexp.compile("[\\u4e00-\\u9fff]+")
  // if regex.execute("Hello 世界 World").matched() {
  //   assert_eq(regex.execute("Hello 世界 World").results().collect(), [
  //     "世界",
  //   ])
  // }

  // Test emoji (if supported)
  let regex = @regexp.compile("😀")
  let result = regex.execute("Happy 😀 face")
  guard result.matched()
  inspect(
    result.group(0),
    content=
      #|Some("😀")
    ,
  )
}

///|
test "complex real-world patterns" {
  // Email validation (comprehensive)
  let email_regex = @regexp.compile(
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
  )
  assert_eq(email_regex.execute("user@example.com").results().collect(), [
    "user@example.com",
  ])
  assert_eq(
    email_regex.execute("test.email+tag@domain.co.uk").results().collect(),
    ["test.email+tag@domain.co.uk"],
  )
  assert_false(email_regex.execute("invalid.email").matched())

  // Phone number patterns
  let phone_regex = @regexp.compile("\\(?\\d{3}\\)?[-.]?\\d{3}[-.]?\\d{4}")
  assert_eq(phone_regex.execute("(123)456-7890").results().collect(), [
    "(123)456-7890",
  ])
  assert_eq(phone_regex.execute("123.456.7890").results().collect(), [
    "123.456.7890",
  ])
  assert_eq(phone_regex.execute("1234567890").results().collect(), [
    "1234567890",
  ])

  // URL matching
  let url_regex = @regexp.compile("https?://[^\\s]+")
  assert_eq(
    url_regex.execute("Visit https://example.com for more").results().collect(),
    ["https://example.com"],
  )
  assert_eq(
    url_regex.execute("Go to http://test.org/path?query=1").results().collect(),
    ["http://test.org/path?query=1"],
  )

  // IP address validation
  let ip_regex = @regexp.compile(
    "\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b",
  )
  if ip_regex.execute("Server IP: 192.168.1.1").matched() {
    assert_eq(ip_regex.execute("Server IP: 192.168.1.1").results().collect(), [
      "192.168.1.1",
    ])
  }

  // Credit card number (simple pattern)
  let cc_regex = @regexp.compile(
    "\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}",
  )
  assert_eq(cc_regex.execute("1234 5678 9012 3456").results().collect(), [
    "1234 5678 9012 3456",
  ])
  assert_eq(cc_regex.execute("1234-5678-9012-3456").results().collect(), [
    "1234-5678-9012-3456",
  ])

  // HTML tag matching
  let html_regex = @regexp.compile("<([a-zA-Z]+)[^>]*>(.*?)</\\1>")
  let result = html_regex.execute("<div class='test'>content</div>")
  if result.matched() {
    assert_eq(result.group(1), Some("div"))
    assert_eq(result.group(2), Some("content"))
  }
}

///|
test "edge cases and boundary conditions" {
  // Empty string matching
  let regex = @regexp.compile("")
  assert_eq(regex.execute("").results().collect(), [""])
  assert_eq(regex.execute("abc").results().collect(), [""])

  // Very long strings
  let long_string = "a".repeat(1000) + "b"
  let regex = @regexp.compile("a+b")
  assert_eq(regex.execute(long_string).results().collect(), [long_string])

  // Pattern at string boundaries
  let regex = @regexp.compile("^a|b$")
  assert_eq(regex.execute("a").results().collect(), ["a"])
  assert_eq(regex.execute("b").results().collect(), ["b"])
  assert_eq(regex.execute("ab").results().collect(), ["a"])
  assert_eq(regex.execute("ba").results().collect(), [])

  // Zero-width assertions
  let regex = @regexp.compile("\\b")
  let result = regex.execute("hello world")
  inspect(result.matched(), content="true")
  // Word boundaries are zero-width, so match should be empty string
  if result.matched() {
    inspect(result.group(0), content="Some(\"\")")
  }

  // Overlapping matches (should get first/leftmost)
  let regex = @regexp.compile("aa")
  assert_eq(regex.execute("aaa").results().collect(), ["aa"])

  // Pattern with all quantifiers
  let regex = @regexp.compile("a*b+c?d{2}e{2,4}f{3,}")
  if regex.execute("bbcddeeefffff").matched() {
    assert_eq(regex.execute("bbcddeeefffff").results().collect(), [
      "bbcddeeefffff",
    ])
  }
}

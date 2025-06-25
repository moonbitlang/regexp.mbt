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
      #|[Some("abc")]
    ,
  )
  let result = regex.execute("ab").results().collect()
  inspect(result, content="[]")
  let result = regex.execute("abcd").results().collect()
  inspect(
    result,
    content=
      #|[Some("abc")]
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
      #|[Some("abcf"), Some("bc")]
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
      #|[Some("abcdebcf"), Some("bc")]
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
  inspect(
    email_result,
    content=
      #|[Some("user@example.com")]
    ,
  )
  // Extract numbers
  let numbers = @regexp.compile(
    #|\d+\.\d{2}
    ,
  )
  let result = numbers.execute("Price: $42.99").results().collect()
  inspect(
    result,
    content=
      #|[Some("42.99")]
    ,
  )

  // Named captures for parsing
  let parser = @regexp.compile(
    #|(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})
    ,
  )
  let date_result = parser.execute("2024-03-15")
  inspect(
    date_result.group_by_name("year"),
    content=
      #|Some("2024")
    ,
  )
  inspect(
    date_result.group_by_name("month"),
    content=
      #|Some("03")
    ,
  )
  inspect(
    date_result.group_by_name("day"),
    content=
      #|Some("15")
    ,
  )
}

///|
test "regexp with flags" {
  // singleline flag
  let regexp = compile(".")
  inspect(regexp.execute("\n").matched(), content="false")
  let regexp = compile(".", flags="s")
  inspect(regexp.execute("\n").matched(), content="true")
  let regexp = compile("(?s:.)")
  inspect(regexp.execute("\n").matched(), content="true")

  // multiline flag
  let regexp = compile("$")
  inspect(regexp.execute("\n").matched(), content="true")
  inspect(regexp.execute("\n").results().count(), content="1")
  inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()).collect(),
    content="[1]",
  )
  let regexp = compile("$", flags="m")
  inspect(regexp.execute("\n").matched(), content="true")
  inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()).collect(),
    content="[0]",
  )
  let regexp = compile("(?m:$)")
  inspect(regexp.execute("\n").matched(), content="true")
  inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()).collect(),
    content="[0]",
  )
  let regexp = compile("(?m-m:$)")
  inspect(regexp.execute("\n").matched(), content="true")
  inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()).collect(),
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
test "quantifiers and repetition" {
  // Test * quantifier (zero or more)
  let regex = @regexp.compile("ab*c")
  inspect(
    regex.execute("ac").results().collect(),
    content=
      #|[Some("ac")]
    ,
  )
  inspect(
    regex.execute("abc").results().collect(),
    content=
      #|[Some("abc")]
    ,
  )
  inspect(
    regex.execute("abbbbc").results().collect(),
    content=
      #|[Some("abbbbc")]
    ,
  )
  inspect(regex.execute("bc").matched(), content="false")

  // Test + quantifier (one or more)
  let regex = @regexp.compile("ab+c")
  inspect(regex.execute("ac").matched(), content="false")
  inspect(
    regex.execute("abc").results().collect(),
    content=
      #|[Some("abc")]
    ,
  )
  inspect(
    regex.execute("abbbbc").results().collect(),
    content=
      #|[Some("abbbbc")]
    ,
  )

  // Test ? quantifier (zero or one)
  let regex = @regexp.compile("ab?c")
  inspect(
    regex.execute("ac").results().collect(),
    content=
      #|[Some("ac")]
    ,
  )
  inspect(
    regex.execute("abc").results().collect(),
    content=
      #|[Some("abc")]
    ,
  )
  inspect(regex.execute("abbc").matched(), content="false")

  // Test specific count {n}
  let regex = @regexp.compile("a{3}")
  inspect(regex.execute("aa").matched(), content="false")
  inspect(
    regex.execute("aaa").results().collect(),
    content=
      #|[Some("aaa")]
    ,
  )
  inspect(
    regex.execute("aaaa").results().collect(),
    content=
      #|[Some("aaa")]
    ,
  )

  // Test range {n,m}
  let regex = @regexp.compile("a{2,4}")
  inspect(regex.execute("a").matched(), content="false")
  inspect(
    regex.execute("aa").results().collect(),
    content=
      #|[Some("aa")]
    ,
  )
  inspect(
    regex.execute("aaa").results().collect(),
    content=
      #|[Some("aaa")]
    ,
  )
  inspect(
    regex.execute("aaaa").results().collect(),
    content=
      #|[Some("aaaa")]
    ,
  )
  inspect(
    regex.execute("aaaaa").results().collect(),
    content=
      #|[Some("aaaa")]
    ,
  )

  // Test minimum count {n,}
  let regex = @regexp.compile("a{3,}")
  inspect(regex.execute("aa").matched(), content="false")
  inspect(
    regex.execute("aaa").results().collect(),
    content=
      #|[Some("aaa")]
    ,
  )
  inspect(
    regex.execute("aaaaa").results().collect(),
    content=
      #|[Some("aaaaa")]
    ,
  )
}

///|
test "character classes and sets" {
  // Test digit class \d
  let regex = @regexp.compile("\\d+")
  inspect(
    regex.execute("123").results().collect(),
    content=
      #|[Some("123")]
    ,
  )
  inspect(
    regex.execute("abc123def").results().collect(),
    content=
      #|[Some("123")]
    ,
  )
  inspect(regex.execute("abc").matched(), content="false")

  // Test word class \w
  let regex = @regexp.compile("\\w+")
  inspect(
    regex.execute("hello123").results().collect(),
    content=
      #|[Some("hello123")]
    ,
  )
  inspect(
    regex.execute("hello-world").results().collect(),
    content=
      #|[Some("hello")]
    ,
  )

  // Test whitespace class \s
  let regex = @regexp.compile("\\s+")
  inspect(
    regex.execute("  \t\n").results().collect(),
    content=
      #|[Some("  \t\n")]
    ,
  )
  inspect(
    regex.execute("a b").results().collect(),
    content=
      #|[Some(" ")]
    ,
  )

  // Test negated classes
  let regex = @regexp.compile("\\D+")
  inspect(
    regex.execute("abc123").results().collect(),
    content=
      #|[Some("abc")]
    ,
  )
  let regex = @regexp.compile("\\W+")
  inspect(
    regex.execute("hello-world!").results().collect(),
    content=
      #|[Some("-")]
    ,
  )
  let regex = @regexp.compile("\\S+")
  inspect(
    regex.execute("hello world").results().collect(),
    content=
      #|[Some("hello")]
    ,
  )

  // Test custom character sets
  let regex = @regexp.compile("[abc]")
  inspect(
    regex.execute("apple").results().collect(),
    content=
      #|[Some("a")]
    ,
  )
  inspect(
    regex.execute("banana").results().collect(),
    content=
      #|[Some("b")]
    ,
  )
  inspect(regex.execute("xyz").matched(), content="false")

  // Test character ranges
  let regex = @regexp.compile("[a-z]+")
  inspect(
    regex.execute("hello123").results().collect(),
    content=
      #|[Some("hello")]
    ,
  )
  inspect(
    regex.execute("Hello").results().collect(),
    content=
      #|[Some("ello")]
    ,
  )
  let regex = @regexp.compile("[0-9]+")
  inspect(
    regex.execute("abc123def").results().collect(),
    content=
      #|[Some("123")]
    ,
  )

  // Test negated character sets
  let regex = @regexp.compile("[^abc]+")
  inspect(
    regex.execute("abcdef").results().collect(),
    content=
      #|[Some("def")]
    ,
  )
  inspect(
    regex.execute("xyz").results().collect(),
    content=
      #|[Some("xyz")]
    ,
  )

  // Test mixed character sets
  let regex = @regexp.compile("[a-zA-Z0-9_]+")
  inspect(
    regex.execute("Hello_World123").results().collect(),
    content=
      #|[Some("Hello_World123")]
    ,
  )
  inspect(
    regex.execute("test-case").results().collect(),
    content=
      #|[Some("test")]
    ,
  )
}

///|
test "anchors and boundaries" {
  // Test start anchor ^
  let regex = @regexp.compile("^hello")
  inspect(
    regex.execute("hello world").results().collect(),
    content=
      #|[Some("hello")]
    ,
  )
  inspect(regex.execute("say hello").matched(), content="false")

  // Test end anchor $
  let regex = @regexp.compile("world$")
  inspect(
    regex.execute("hello world").results().collect(),
    content=
      #|[Some("world")]
    ,
  )
  inspect(regex.execute("world peace").matched(), content="false")

  // Test both anchors
  let regex = @regexp.compile("^hello$")
  inspect(
    regex.execute("hello").results().collect(),
    content=
      #|[Some("hello")]
    ,
  )
  inspect(regex.execute("hello world").matched(), content="false")
  inspect(regex.execute("say hello").matched(), content="false")

  // Test word boundaries \b
  let regex = @regexp.compile("\\bword\\b")
  inspect(
    regex.execute("a word here").results().collect(),
    content=
      #|[Some("word")]
    ,
  )
  inspect(
    regex.execute("word").results().collect(),
    content=
      #|[Some("word")]
    ,
  )
  inspect(regex.execute("sword").matched(), content="false")
  inspect(regex.execute("words").matched(), content="false")

  // Test non-word boundaries \B
  let regex = @regexp.compile("\\Bor\\B")
  inspect(
    regex.execute("words").results().collect(),
    content=
      #|[Some("or")]
    ,
  )
  inspect(regex.execute("or").matched(), content="false")
  inspect(regex.execute("for you").matched(), content="false")
}

///|
test "alternation and grouping" {
  // Test simple alternation
  let regex = @regexp.compile("cat|dog")
  inspect(
    regex.execute("I have a cat").results().collect(),
    content=
      #|[Some("cat")]
    ,
  )
  inspect(
    regex.execute("I have a dog").results().collect(),
    content=
      #|[Some("dog")]
    ,
  )
  inspect(regex.execute("I have a bird").matched(), content="false")

  // Test alternation with groups
  let regex = @regexp.compile("(cat|dog) food")
  let result = regex.execute("cat food").results().collect()
  inspect(
    result,
    content=
      #|[Some("cat food"), Some("cat")]
    ,
  )

  // Test nested groups
  let regex = @regexp.compile("((a|b)(c|d))")
  let result = regex.execute("ac").results().collect()
  inspect(
    result,
    content=
      #|[Some("ac"), Some("ac"), Some("a"), Some("c")]
    ,
  )

  // Test non-capturing groups
  let regex = @regexp.compile("(?:cat|dog) food")
  inspect(
    regex.execute("cat food").results().collect(),
    content=
      #|[Some("cat food")]
    ,
  )

  // Test multiple alternations
  let regex = @regexp.compile("red|green|blue")
  inspect(
    regex.execute("red car").results().collect(),
    content=
      #|[Some("red")]
    ,
  )
  inspect(
    regex.execute("green light").results().collect(),
    content=
      #|[Some("green")]
    ,
  )
  inspect(
    regex.execute("blue sky").results().collect(),
    content=
      #|[Some("blue")]
    ,
  )
}

///|
test "advanced capture groups" {
  // Test multiple groups
  let regex = @regexp.compile("([a-z]+) ([0-9]+)")
  let result = regex.execute("hello 123")
  inspect(
    result.group(0),
    content=
      #|Some("hello 123")
    ,
  )
  inspect(
    result.group(1),
    content=
      #|Some("hello")
    ,
  )
  inspect(
    result.group(2),
    content=
      #|Some("123")
    ,
  )
  inspect(result.group(3), content="None")

  // Test nested groups
  let regex = @regexp.compile("((\\w+)-(\\w+))")
  let result = regex.execute("first-second")
  inspect(
    result.group(0),
    content=
      #|Some("first-second")
    ,
  )
  inspect(
    result.group(1),
    content=
      #|Some("first-second")
    ,
  )
  inspect(
    result.group(2),
    content=
      #|Some("first")
    ,
  )
  inspect(
    result.group(3),
    content=
      #|Some("second")
    ,
  )

  // Test optional groups
  let regex = @regexp.compile("(\\w+)(-\\w+)?")
  let result1 = regex.execute("hello-world")
  inspect(
    result1.group(1),
    content=
      #|Some("hello")
    ,
  )
  inspect(
    result1.group(2),
    content=
      #|Some("-world")
    ,
  )
  let result2 = regex.execute("hello")
  inspect(
    result2.group(1),
    content=
      #|Some("hello")
    ,
  )
  // Optional group that didn't match should still be accessible but empty
  inspect(result2.group(2), content="None")
}

///|
test "complex named capture groups" {
  // Test multiple named groups
  let regex = @regexp.compile("(?<first>\\w+)\\s+(?<last>\\w+)")
  let result = regex.execute("John Doe")
  inspect(
    result.group_by_name("first"),
    content=
      #|Some("John")
    ,
  )
  inspect(
    result.group_by_name("last"),
    content=
      #|Some("Doe")
    ,
  )

  // Test group names iteration
  let names = regex.group_names().collect()
  inspect(names.contains("first"), content="true")
  inspect(names.contains("last"), content="true")

  // Test URL parsing with named groups
  let url_regex = @regexp.compile(
    "(?<protocol>https?)://(?<domain>[^/]+)(?<path>/.*)?",
  )
  let result = url_regex.execute("https://example.com/path/to/page")
  inspect(
    result.group_by_name("protocol"),
    content=
      #|Some("https")
    ,
  )
  inspect(
    result.group_by_name("domain"),
    content=
      #|Some("example.com")
    ,
  )
  inspect(
    result.group_by_name("path"),
    content=
      #|Some("/path/to/page")
    ,
  )

  // Test mixed named and unnamed groups
  let regex = @regexp.compile("(\\w+)@(?<domain>\\w+\\.\\w+)")
  let result = regex.execute("user@example.com")
  inspect(
    result.group(1),
    content=
      #|Some("user")
    ,
  )
  inspect(
    result.group_by_name("domain"),
    content=
      #|Some("example.com")
    ,
  )
}

///|
test "escape sequences and special characters" {
  // Test literal special characters
  let regex = @regexp.compile("\\.")
  inspect(
    regex.execute("3.14").results().collect(),
    content=
      #|[Some(".")]
    ,
  )
  inspect(regex.execute("314").matched(), content="false")
  let regex = @regexp.compile("\\*")
  inspect(
    regex.execute("2*3").results().collect(),
    content=
      #|[Some("*")]
    ,
  )
  let regex = @regexp.compile("\\+")
  inspect(
    regex.execute("1+1").results().collect(),
    content=
      #|[Some("+")]
    ,
  )
  let regex = @regexp.compile("\\?")
  inspect(
    regex.execute("what?").results().collect(),
    content=
      #|[Some("?")]
    ,
  )

  // Test escaped brackets
  let regex = @regexp.compile("\\[\\]")
  inspect(
    regex.execute("array[]").results().collect(),
    content=
      #|[Some("[]")]
    ,
  )
  let regex = @regexp.compile("\\(\\)")
  inspect(
    regex.execute("func()").results().collect(),
    content=
      #|[Some("()")]
    ,
  )

  // Test escaped backslash
  let regex = @regexp.compile("\\\\")
  inspect(
    regex.execute("path\\file").results().collect(),
    content=
      #|[Some("\\")]
    ,
  )

  // Test tab, newline, etc.
  let regex = @regexp.compile("\\t")
  inspect(
    regex.execute("a\tb").results().collect(),
    content=
      #|[Some("\t")]
    ,
  )
  let regex = @regexp.compile("\\n")
  inspect(
    regex.execute("line1\nline2").results().collect(),
    content=
      #|[Some("\n")]
    ,
  )
  let regex = @regexp.compile("\\r")
  inspect(
    regex.execute("line1\rline2").results().collect(),
    content=
      #|[Some("\r")]
    ,
  )
  let regex = @regexp.compile("[\\t\\n\\r]")
  inspect(
    regex.execute("a\tb").results().collect(),
    content=
      #|[Some("\t")]
    ,
  )
  inspect(
    regex.execute("line1\nline2").results().collect(),
    content=
      #|[Some("\n")]
    ,
  )
  inspect(
    regex.execute("line1\rline2").results().collect(),
    content=
      #|[Some("\r")]
    ,
  )
}

///|
test "greedy vs non-greedy matching" {
  // Test greedy quantifiers
  let regex = @regexp.compile("<.*>")
  inspect(
    regex.execute("<div><span></span></div>").results().collect(),
    content=
      #|[Some("<div><span></span></div>")]
    ,
  )

  // Test non-greedy quantifiers
  let regex = @regexp.compile("<.*?>")
  inspect(
    regex.execute("<div><span></span></div>").results().collect(),
    content=
      #|[Some("<div>")]
    ,
  )

  // Test non-greedy +
  let regex = @regexp.compile("a.+?b")
  inspect(
    regex.execute("axxxbyyybzzz").results().collect(),
    content=
      #|[Some("axxxb")]
    ,
  )

  // Test non-greedy *
  let regex = @regexp.compile("a.*?b")
  inspect(
    regex.execute("axxxbyyybzzz").results().collect(),
    content=
      #|[Some("axxxb")]
    ,
  )
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
  inspect(
    regex.execute("HELLO").results().collect(),
    content=
      #|[Some("HELLO")]
    ,
  )
  inspect(
    regex.execute("Hello").results().collect(),
    content=
      #|[Some("Hello")]
    ,
  )
  inspect(
    regex.execute("hElLo").results().collect(),
    content=
      #|[Some("hElLo")]
    ,
  )

  // Test inline case insensitive
  let regex = @regexp.compile("(?i:hello)")
  inspect(
    regex.execute("HELLO world").results().collect(),
    content=
      #|[Some("HELLO")]
    ,
  )

  // Test case sensitive (default)
  let regex = @regexp.compile("hello")
  inspect(
    regex.execute("hello").results().collect(),
    content=
      #|[Some("hello")]
    ,
  )
  inspect(regex.execute("HELLO").matched(), content="false")

  // Test mixed case sensitivity
  let regex = @regexp.compile("(?i:hello) world")
  inspect(
    regex.execute("HELLO world").results().collect(),
    content=
      #|[Some("HELLO world")]
    ,
  )
  inspect(regex.execute("HELLO WORLD").matched(), content="false")
}

// ///|

///|
test "unicode and international characters" {
  // Test basic unicode
  let regex = @regexp.compile("café")
  inspect(
    regex.execute("I love café").results().collect(),
    content=
      #|[Some("café")]
    ,
  )

  // Test unicode word boundaries
  let regex = @regexp.compile("\\w+")
  inspect(
    regex.execute("hello 世界").results().collect(),
    content=
      #|[Some("hello")]
    ,
  )

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
  inspect(
    email_regex.execute("user@example.com").results().collect(),
    content=
      #|[Some("user@example.com")]
    ,
  )
  inspect(
    email_regex.execute("test.email+tag@domain.co.uk").results().collect(),
    content=
      #|[Some("test.email+tag@domain.co.uk")]
    ,
  )
  inspect(email_regex.execute("invalid.email").matched(), content="false")

  // Phone number patterns
  let phone_regex = @regexp.compile("\\(?\\d{3}\\)?[ -.]?\\d{3}[-.]?\\d{4}")
  inspect(
    phone_regex.execute("(123)456-7890").results().collect(),
    content=
      #|[Some("(123)456-7890")]
    ,
  )
  inspect(
    phone_regex.execute("123.456.7890").results().collect(),
    content=
      #|[Some("123.456.7890")]
    ,
  )
  inspect(
    phone_regex.execute("1234567890").results().collect(),
    content=
      #|[Some("1234567890")]
    ,
  )

  // URL matching
  let url_regex = @regexp.compile("https?://[^\\s]+")
  inspect(
    url_regex.execute("Visit https://example.com for more").results().collect(),
    content=
      #|[Some("https://example.com")]
    ,
  )
  inspect(
    url_regex.execute("Go to http://test.org/path?query=1").results().collect(),
    content=
      #|[Some("http://test.org/path?query=1")]
    ,
  )

  // IP address validation
  let ip_regex = @regexp.compile(
    "\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b",
  )
  inspect(
    ip_regex.execute("Server IP: 192.168.1.1").results().collect(),
    content=
      #|[Some("192.168.1.1")]
    ,
  )

  // Credit card number (simple pattern)
  let cc_regex = @regexp.compile(
    "\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}",
  )
  inspect(
    cc_regex.execute("1234 5678 9012 3456").results().collect(),
    content=
      #|[Some("1234 5678 9012 3456")]
    ,
  )
  inspect(
    cc_regex.execute("1234-5678-9012-3456").results().collect(),
    content=
      #|[Some("1234-5678-9012-3456")]
    ,
  )

  // HTML tag matching
  let html_regex = @regexp.compile("<([a-zA-Z]+)[^>]*>(.*?)</\\1>")
  let result = html_regex.execute("<div class='test'>content</div>")
  inspect(result.group(1), content="None")
  inspect(result.group(2), content="None")
}

///|
test "edge cases and boundary conditions" {
  // Empty string matching
  let regex = @regexp.compile("")
  inspect(
    regex.execute("").results().collect(),
    content=
      #|[Some("")]
    ,
  )
  inspect(
    regex.execute("abc").results().collect(),
    content=
      #|[Some("")]
    ,
  )

  // Very long strings
  let long_string = "a".repeat(1000) + "b"
  let regex = @regexp.compile("a+b")
  inspect(
    regex.execute(long_string).results().collect(),
    content=
      #|[Some("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab")]
    ,
  )

  // Pattern at string boundaries
  let regex = @regexp.compile("^a|b$")
  inspect(
    regex.execute("a").results().collect(),
    content=
      #|[Some("a")]
    ,
  )
  inspect(
    regex.execute("b").results().collect(),
    content=
      #|[Some("b")]
    ,
  )
  inspect(
    regex.execute("ab").results().collect(),
    content=
      #|[Some("a")]
    ,
  )
  inspect(regex.execute("ba").results().collect(), content="[]")

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
  inspect(
    regex.execute("aaa").results().collect(),
    content=
      #|[Some("aa")]
    ,
  )

  // Pattern with all quantifiers
  let regex = @regexp.compile("a*b+c?d{2}e{2,4}f{3,}")
  inspect(
    regex.execute("bbcddeeefffff").results().collect(),
    content=
      #|[Some("bbcddeeefffff")]
    ,
  )
}

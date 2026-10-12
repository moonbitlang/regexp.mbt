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
  debug_inspect(
    regex.execute("abc").results(),
    content=(
      #|[Some(<StringView: "abc">)]
    ),
  )
  debug_inspect(regex.execute("ab").results(), content="[]")
  debug_inspect(
    regex.execute("abcd").results(),
    content=(
      #|[Some(<StringView: "abc">)]
    ),
  )
}

///|
test "unicode escape sequences" {
  // Test basic \u{aaaa} format
  let regex = @regexp.compile("\\u{41}")
  debug_inspect(
    regex.execute("A").results(),
    content=(
      #|[Some(<StringView: "A">)]
    ),
  )
  inspect(regex.execute("B").matched(), content="false")

  // Test \uaaaa format (exactly 4 digits)
  let regex = @regexp.compile("\\u0041")
  debug_inspect(
    regex.execute("A").results(),
    content=(
      #|[Some(<StringView: "A">)]
    ),
  )

  // Test Unicode characters beyond ASCII
  let regex = @regexp.compile("\\u{4e16}\\u{754c}")
  debug_inspect(
    regex.execute("世界").results(),
    content=(
      #|[Some(<StringView: "世界">)]
    ),
  )
  let regex = @regexp.compile("\\u4e16\\u754C")
  debug_inspect(
    regex.execute("世界").results(),
    content=(
      #|[Some(<StringView: "世界">)]
    ),
  )

  // Test large Unicode escape
  let regex = @regexp.compile("\\u{10348}")
  debug_inspect(
    regex.execute("𐍈").results(),
    content=(
      #|[Some(<StringView: "𐍈">)]
    ),
  )

  // Test in character classes
  let regex = @regexp.compile("[\\u{41}-\\u{43}]")
  debug_inspect(
    regex.execute("B").results(),
    content=(
      #|[Some(<StringView: "B">)]
    ),
  )
  inspect(regex.execute("D").matched(), content="false")

  // Test with \uaaaa format in character classes
  let regex = @regexp.compile("[\\u0041\\u0042]")
  debug_inspect(
    regex.execute("A").results(),
    content=(
      #|[Some(<StringView: "A">)]
    ),
  )
  debug_inspect(
    regex.execute("B").results(),
    content=(
      #|[Some(<StringView: "B">)]
    ),
  )
  inspect(regex.execute("C").matched(), content="false")

  // Test combining with other patterns
  let regex = @regexp.compile("\\u{48}ello \\u{4E16}\\u754C")
  debug_inspect(
    regex.execute("Hello 世界").results(),
    content=(
      #|[Some(<StringView: "Hello 世界">)]
    ),
  )

  // Test error cases
  try @regexp.compile("\\u{}") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "}">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\u{1234567}") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(
          #|  err=InvalidEscape,
          #|  source_fragment=<StringView: "1234567}">,
          #|)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\u{GGGG}") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "GGGG}">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\u123") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\uGGGG") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "GGGG">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\u{110000}") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(
          #|  err=InvalidEscape,
          #|  source_fragment=<StringView: "110000}">,
          #|)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\u{dfff}") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "dfff}">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\u{") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "simple regex test matching leftmost" {
  let regex = @regexp.compile("a(bc|de)f")
  debug_inspect(
    regex.execute("xxabcf").results(),
    content=(
      #|[Some(<StringView: "abcf">), Some(<StringView: "bc">)]
    ),
  )
}

///|
test "simple regex test with repeat" {
  let regex = @regexp.compile("a(bc|de){2,}f")
  debug_inspect(
    regex.execute("xxabcdebcf").results(),
    content=(
      #|[Some(<StringView: "abcdebcf">), Some(<StringView: "bc">)]
    ),
  )
}

///|
test "character classes" {
  // Email validation (simplified)
  let email = @regexp.compile(
    (
      #|[\w-]+@[\w-]+\.\w+
    ),
  )
  let email_result = email.execute("user@example.com").results()
  debug_inspect(
    email_result,
    content=(
      #|[Some(<StringView: "user@example.com">)]
    ),
  )
  // Extract numbers
  let numbers = @regexp.compile(
    (
      #|\d+\.\d{2}
    ),
  )
  let result = numbers.execute("Price: $42.99").results()
  debug_inspect(
    result,
    content=(
      #|[Some(<StringView: "42.99">)]
    ),
  )

  // Named captures for parsing
  let parser = @regexp.compile(
    (
      #|(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})
    ),
  )
  let date_result = parser.execute("2024-03-15")
  debug_inspect(
    date_result.groups(),
    content=(
      #|{
      #|  "year": <StringView: "2024">,
      #|  "month": <StringView: "03">,
      #|  "day": <StringView: "15">,
      #|}
    ),
  )
}

///|
test "regexp with flags" {
  // singleline flag
  let regexp = @regexp.compile(".")
  inspect(regexp.execute("\n").matched(), content="false")
  let regexp = @regexp.compile(".", flags="s")
  inspect(regexp.execute("\n").matched(), content="true")
  let regexp = @regexp.compile("(?s:.)")
  inspect(regexp.execute("\n").matched(), content="true")

  // multiline flag
  let regexp = @regexp.compile("$")
  inspect(regexp.execute("\n").matched(), content="true")
  inspect(regexp.execute("\n").results().length(), content="1")
  debug_inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()),
    content="[1]",
  )
  let regexp = @regexp.compile("$", flags="m")
  inspect(regexp.execute("\n").matched(), content="true")
  debug_inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()),
    content="[0]",
  )
  let regexp = @regexp.compile("(?m:$)")
  inspect(regexp.execute("\n").matched(), content="true")
  debug_inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()),
    content="[0]",
  )
  let regexp = @regexp.compile("(?m-m:$)")
  inspect(regexp.execute("\n").matched(), content="true")
  debug_inspect(
    regexp.execute("\n").results().map(r => r.unwrap().start_offset()),
    content="[1]",
  )
}

///|
test "invalid regex test" {
  try @regexp.compile("a(b") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=MissingParenthesis, source_fragment=<StringView: "">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("a(b|c") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=MissingParenthesis, source_fragment=<StringView: "">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("a|b)") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(
          #|  err=UnexpectedParenthesis,
          #|  source_fragment=<StringView: ")">,
          #|)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("a|b|c)") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(
          #|  err=UnexpectedParenthesis,
          #|  source_fragment=<StringView: ")">,
          #|)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "quantifiers and repetition" {
  // Test * quantifier (zero or more)
  let regex = @regexp.compile("ab*c")
  debug_inspect(
    regex.execute("ac").results(),
    content=(
      #|[Some(<StringView: "ac">)]
    ),
  )
  debug_inspect(
    regex.execute("abc").results(),
    content=(
      #|[Some(<StringView: "abc">)]
    ),
  )
  debug_inspect(
    regex.execute("abbbbc").results(),
    content=(
      #|[Some(<StringView: "abbbbc">)]
    ),
  )
  inspect(regex.execute("bc").matched(), content="false")

  // Test + quantifier (one or more)
  let regex = @regexp.compile("ab+c")
  inspect(regex.execute("ac").matched(), content="false")
  debug_inspect(
    regex.execute("abc").results(),
    content=(
      #|[Some(<StringView: "abc">)]
    ),
  )
  debug_inspect(
    regex.execute("abbbbc").results(),
    content=(
      #|[Some(<StringView: "abbbbc">)]
    ),
  )

  // Test ? quantifier (zero or one)
  let regex = @regexp.compile("ab?c")
  debug_inspect(
    regex.execute("ac").results(),
    content=(
      #|[Some(<StringView: "ac">)]
    ),
  )
  debug_inspect(
    regex.execute("abc").results(),
    content=(
      #|[Some(<StringView: "abc">)]
    ),
  )
  inspect(regex.execute("abbc").matched(), content="false")

  // Test specific count {n}
  let regex = @regexp.compile("a{3}")
  inspect(regex.execute("aa").matched(), content="false")
  debug_inspect(
    regex.execute("aaa").results(),
    content=(
      #|[Some(<StringView: "aaa">)]
    ),
  )
  debug_inspect(
    regex.execute("aaaa").results(),
    content=(
      #|[Some(<StringView: "aaa">)]
    ),
  )

  // Test range {n,m}
  let regex = @regexp.compile("a{2,4}")
  inspect(regex.execute("a").matched(), content="false")
  debug_inspect(
    regex.execute("aa").results(),
    content=(
      #|[Some(<StringView: "aa">)]
    ),
  )
  debug_inspect(
    regex.execute("aaa").results(),
    content=(
      #|[Some(<StringView: "aaa">)]
    ),
  )
  debug_inspect(
    regex.execute("aaaa").results(),
    content=(
      #|[Some(<StringView: "aaaa">)]
    ),
  )
  debug_inspect(
    regex.execute("aaaaa").results(),
    content=(
      #|[Some(<StringView: "aaaa">)]
    ),
  )

  // Test minimum count {n,}
  let regex = @regexp.compile("a{3,}")
  inspect(regex.execute("aa").matched(), content="false")
  debug_inspect(
    regex.execute("aaa").results(),
    content=(
      #|[Some(<StringView: "aaa">)]
    ),
  )
  debug_inspect(
    regex.execute("aaaaa").results(),
    content=(
      #|[Some(<StringView: "aaaaa">)]
    ),
  )
}

///|
test "character classes and sets" {
  // Test digit class \d
  let regex = @regexp.compile("\\d+")
  debug_inspect(
    regex.execute("123").results(),
    content=(
      #|[Some(<StringView: "123">)]
    ),
  )
  debug_inspect(
    regex.execute("abc123def").results(),
    content=(
      #|[Some(<StringView: "123">)]
    ),
  )
  inspect(regex.execute("abc").matched(), content="false")

  // Test word class \w
  let regex = @regexp.compile("\\w+")
  debug_inspect(
    regex.execute("hello123").results(),
    content=(
      #|[Some(<StringView: "hello123">)]
    ),
  )
  debug_inspect(
    regex.execute("hello-world").results(),
    content=(
      #|[Some(<StringView: "hello">)]
    ),
  )

  // Test whitespace class \s
  let regex = @regexp.compile("\\s+")
  debug_inspect(
    regex.execute("  \t\n").results(),
    content=(
      #|[Some(<StringView: "  \t\n">)]
    ),
  )
  debug_inspect(
    regex.execute("a b").results(),
    content=(
      #|[Some(<StringView: " ">)]
    ),
  )

  // Test negated classes
  let regex = @regexp.compile("\\D+")
  debug_inspect(
    regex.execute("abc123").results(),
    content=(
      #|[Some(<StringView: "abc">)]
    ),
  )
  let regex = @regexp.compile("\\W+")
  debug_inspect(
    regex.execute("hello-world!").results(),
    content=(
      #|[Some(<StringView: "-">)]
    ),
  )
  let regex = @regexp.compile("\\S+")
  debug_inspect(
    regex.execute("hello world").results(),
    content=(
      #|[Some(<StringView: "hello">)]
    ),
  )

  // Test custom character sets
  let regex = @regexp.compile("[abc]")
  debug_inspect(
    regex.execute("apple").results(),
    content=(
      #|[Some(<StringView: "a">)]
    ),
  )
  debug_inspect(
    regex.execute("banana").results(),
    content=(
      #|[Some(<StringView: "b">)]
    ),
  )
  inspect(regex.execute("xyz").matched(), content="false")

  // Test character ranges
  let regex = @regexp.compile("[a-z]+")
  debug_inspect(
    regex.execute("hello123").results(),
    content=(
      #|[Some(<StringView: "hello">)]
    ),
  )
  debug_inspect(
    regex.execute("Hello").results(),
    content=(
      #|[Some(<StringView: "ello">)]
    ),
  )
  let regex = @regexp.compile("[0-9]+")
  debug_inspect(
    regex.execute("abc123def").results(),
    content=(
      #|[Some(<StringView: "123">)]
    ),
  )

  // Test negated character sets
  let regex = @regexp.compile("[^abc]+")
  debug_inspect(
    regex.execute("abcdef").results(),
    content=(
      #|[Some(<StringView: "def">)]
    ),
  )
  debug_inspect(
    regex.execute("xyz").results(),
    content=(
      #|[Some(<StringView: "xyz">)]
    ),
  )

  // Test mixed character sets
  let regex = @regexp.compile("[a-zA-Z0-9_]+")
  debug_inspect(
    regex.execute("Hello_World123").results(),
    content=(
      #|[Some(<StringView: "Hello_World123">)]
    ),
  )
  debug_inspect(
    regex.execute("test-case").results(),
    content=(
      #|[Some(<StringView: "test">)]
    ),
  )
}

///|
test "anchors and boundaries" {
  // Test start anchor ^
  let regex = @regexp.compile("^hello")
  debug_inspect(
    regex.execute("hello world").results(),
    content=(
      #|[Some(<StringView: "hello">)]
    ),
  )
  inspect(regex.execute("say hello").matched(), content="false")

  // Test end anchor $
  let regex = @regexp.compile("world$")
  debug_inspect(
    regex.execute("hello world").results(),
    content=(
      #|[Some(<StringView: "world">)]
    ),
  )
  inspect(regex.execute("world peace").matched(), content="false")

  // Test both anchors
  let regex = @regexp.compile("^hello$")
  debug_inspect(
    regex.execute("hello").results(),
    content=(
      #|[Some(<StringView: "hello">)]
    ),
  )
  inspect(regex.execute("hello world").matched(), content="false")
  inspect(regex.execute("say hello").matched(), content="false")

  // Test word boundaries \b
  let regex = @regexp.compile("\\bword\\b")
  debug_inspect(
    regex.execute("a word here").results(),
    content=(
      #|[Some(<StringView: "word">)]
    ),
  )
  debug_inspect(
    regex.execute("word").results(),
    content=(
      #|[Some(<StringView: "word">)]
    ),
  )
  inspect(regex.execute("sword").matched(), content="false")
  inspect(regex.execute("words").matched(), content="false")

  // Test non-word boundaries \B
  let regex = @regexp.compile("\\Bor\\B")
  debug_inspect(
    regex.execute("words").results(),
    content=(
      #|[Some(<StringView: "or">)]
    ),
  )
  inspect(regex.execute("or").matched(), content="false")
  inspect(regex.execute("for you").matched(), content="false")
}

///|
test "alternation and grouping" {
  // Test simple alternation
  let regex = @regexp.compile("cat|dog")
  debug_inspect(
    regex.execute("I have a cat").results(),
    content=(
      #|[Some(<StringView: "cat">)]
    ),
  )
  debug_inspect(
    regex.execute("I have a dog").results(),
    content=(
      #|[Some(<StringView: "dog">)]
    ),
  )
  inspect(regex.execute("I have a bird").matched(), content="false")

  // Test alternation with groups
  let regex = @regexp.compile("(cat|dog) food")
  let result = regex.execute("cat food").results()
  debug_inspect(
    result,
    content=(
      #|[Some(<StringView: "cat food">), Some(<StringView: "cat">)]
    ),
  )

  // Test nested groups
  let regex = @regexp.compile("((a|b)(c|d))")
  let result = regex.execute("ac").results()
  debug_inspect(
    result,
    content=(
      #|[
      #|  Some(<StringView: "ac">),
      #|  Some(<StringView: "ac">),
      #|  Some(<StringView: "a">),
      #|  Some(<StringView: "c">),
      #|]
    ),
  )

  // Test non-capturing groups
  let regex = @regexp.compile("(?:cat|dog) food")
  debug_inspect(
    regex.execute("cat food").results(),
    content=(
      #|[Some(<StringView: "cat food">)]
    ),
  )

  // Test multiple alternations
  let regex = @regexp.compile("red|green|blue")
  debug_inspect(
    regex.execute("red car").results(),
    content=(
      #|[Some(<StringView: "red">)]
    ),
  )
  debug_inspect(
    regex.execute("green light").results(),
    content=(
      #|[Some(<StringView: "green">)]
    ),
  )
  debug_inspect(
    regex.execute("blue sky").results(),
    content=(
      #|[Some(<StringView: "blue">)]
    ),
  )
}

///|
test "advanced capture groups" {
  // Test multiple groups
  let regex = @regexp.compile("([a-z]+) ([0-9]+)")
  let result = regex.execute("hello 123")
  debug_inspect(
    result.get(0),
    content=(
      #|Some(<StringView: "hello 123">)
    ),
  )
  debug_inspect(
    result.get(1),
    content=(
      #|Some(<StringView: "hello">)
    ),
  )
  debug_inspect(
    result.get(2),
    content=(
      #|Some(<StringView: "123">)
    ),
  )
  debug_inspect(result.get(3), content="None")

  // Test nested groups
  let regex = @regexp.compile("((\\w+)-(\\w+))")
  let result = regex.execute("first-second")
  debug_inspect(
    result.get(0),
    content=(
      #|Some(<StringView: "first-second">)
    ),
  )
  debug_inspect(
    result.get(1),
    content=(
      #|Some(<StringView: "first-second">)
    ),
  )
  debug_inspect(
    result.get(2),
    content=(
      #|Some(<StringView: "first">)
    ),
  )
  debug_inspect(
    result.get(3),
    content=(
      #|Some(<StringView: "second">)
    ),
  )

  // Test optional groups
  let regex = @regexp.compile("(\\w+)(-\\w+)?")
  let result1 = regex.execute("hello-world")
  debug_inspect(
    result1.get(1),
    content=(
      #|Some(<StringView: "hello">)
    ),
  )
  debug_inspect(
    result1.get(2),
    content=(
      #|Some(<StringView: "-world">)
    ),
  )
  let result2 = regex.execute("hello")
  debug_inspect(
    result2.get(1),
    content=(
      #|Some(<StringView: "hello">)
    ),
  )
  // Optional group that didn't match should still be accessible but empty
  debug_inspect(result2.get(2), content="None")
}

///|
test "complex named capture groups" {
  // Test multiple named groups
  let regex = @regexp.compile("(?<first>\\w+)\\s+(?<last>\\w+)")
  let result = regex.execute("John Doe")
  debug_inspect(
    result.groups(),
    content=(
      #|{ "first": <StringView: "John">, "last": <StringView: "Doe"> }
    ),
  )

  // Test group names iteration
  let names = regex.group_names()
  inspect(names.contains("first"), content="true")
  inspect(names.contains("last"), content="true")

  // Test URL parsing with named groups
  let url_regex = @regexp.compile(
    "(?<protocol>https?)://(?<domain>[^/]+)(?<path>/.*)?",
  )
  let result = url_regex.execute("https://example.com/path/to/page")
  debug_inspect(
    result.groups(),
    content=(
      #|{
      #|  "protocol": <StringView: "https">,
      #|  "domain": <StringView: "example.com">,
      #|  "path": <StringView: "/path/to/page">,
      #|}
    ),
  )

  // Test mixed named and unnamed groups
  let regex = @regexp.compile("(\\w+)@(?<domain>\\w+\\.\\w+)")
  let result = regex.execute("user@example.com")
  debug_inspect(
    result.get(1),
    content=(
      #|Some(<StringView: "user">)
    ),
  )
  debug_inspect(
    result.groups(),
    content=(
      #|{ "domain": <StringView: "example.com"> }
    ),
  )
}

///|
test "escape sequences and special characters" {
  // Test literal special characters
  let regex = @regexp.compile("\\.")
  debug_inspect(
    regex.execute("3.14").results(),
    content=(
      #|[Some(<StringView: ".">)]
    ),
  )
  inspect(regex.execute("314").matched(), content="false")
  let regex = @regexp.compile("\\*")
  debug_inspect(
    regex.execute("2*3").results(),
    content=(
      #|[Some(<StringView: "*">)]
    ),
  )
  let regex = @regexp.compile("\\+")
  debug_inspect(
    regex.execute("1+1").results(),
    content=(
      #|[Some(<StringView: "+">)]
    ),
  )
  let regex = @regexp.compile("\\?")
  debug_inspect(
    regex.execute("what?").results(),
    content=(
      #|[Some(<StringView: "?">)]
    ),
  )

  // Test escaped brackets
  let regex = @regexp.compile("\\[\\]")
  debug_inspect(
    regex.execute("array[]").results(),
    content=(
      #|[Some(<StringView: "[]">)]
    ),
  )
  let regex = @regexp.compile("\\(\\)")
  debug_inspect(
    regex.execute("func()").results(),
    content=(
      #|[Some(<StringView: "()">)]
    ),
  )

  // Test escaped backslash
  let regex = @regexp.compile("\\\\")
  debug_inspect(
    regex.execute("path\\file").results(),
    content=(
      #|[Some(<StringView: "\\">)]
    ),
  )

  // Test tab, newline, etc.
  let regex = @regexp.compile("\\t")
  debug_inspect(
    regex.execute("a\tb").results(),
    content=(
      #|[Some(<StringView: "\t">)]
    ),
  )
  let regex = @regexp.compile("\\n")
  debug_inspect(
    regex.execute("line1\nline2").results(),
    content=(
      #|[Some(<StringView: "\n">)]
    ),
  )
  let regex = @regexp.compile("\\r")
  debug_inspect(
    regex.execute("line1\rline2").results(),
    content=(
      #|[Some(<StringView: "\r">)]
    ),
  )
  let regex = @regexp.compile("[\\t\\n\\r]")
  debug_inspect(
    regex.execute("a\tb").results(),
    content=(
      #|[Some(<StringView: "\t">)]
    ),
  )
  debug_inspect(
    regex.execute("line1\nline2").results(),
    content=(
      #|[Some(<StringView: "\n">)]
    ),
  )
  debug_inspect(
    regex.execute("line1\rline2").results(),
    content=(
      #|[Some(<StringView: "\r">)]
    ),
  )
}

///|
test "greedy vs non-greedy matching" {
  // Test greedy quantifiers
  let regex = @regexp.compile("<.*>")
  debug_inspect(
    regex.execute("<div><span></span></div>").results(),
    content=(
      #|[Some(<StringView: "<div><span></span></div>">)]
    ),
  )

  // Test non-greedy quantifiers
  let regex = @regexp.compile("<.*?>")
  debug_inspect(
    regex.execute("<div><span></span></div>").results(),
    content=(
      #|[Some(<StringView: "<div>">)]
    ),
  )

  // Test non-greedy +
  let regex = @regexp.compile("a.+?b")
  debug_inspect(
    regex.execute("axxxbyyybzzz").results(),
    content=(
      #|[Some(<StringView: "axxxb">)]
    ),
  )

  // Test non-greedy *
  let regex = @regexp.compile("a.*?b")
  debug_inspect(
    regex.execute("axxxbyyybzzz").results(),
    content=(
      #|[Some(<StringView: "axxxb">)]
    ),
  )

  // Test non-greedy ?
  let regex = @regexp.compile("a??b")
  debug_inspect(
    regex.execute("b").results(),
    content=(
      #|[Some(<StringView: "b">)]
    ),
  )
}

// ///|
// test "lookahead and lookbehind assertions" {
//   // Test positive lookahead
//   let regex = @regexp.compile("\\w+(?=ing)")
//   let result = regex.execute("running jumping walking")
//   if result.matched() {
//     inspect(
//       result.results(),
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
//     inspect(result.results().take(0), content="jump")
//   }

//   // Test positive lookbehind
//   let regex = @regexp.compile("(?<=\\$)\\d+")
//   let result = regex.execute("Price: $100 and €200")
//   if result.matched() {
//     inspect(
//       result.results(),
//       content=
//         #|["100"]
//       ,
//     )
//   }

//   // Test negative lookbehind
//   let regex = @regexp.compile("(?<!\\$)\\d+")
//   let result = regex.execute("Price: $100 and 200")
//   if result.matched() {
//     inspect(
//       result.results(),
//       content=
//         #|["200"]
//       ,
//     )
//   }
// }

///|
test "case sensitivity and flags" {
  // Test case insensitive flag
  let regex = @regexp.compile("hello", flags="i")
  debug_inspect(
    regex.execute("HELLO").results(),
    content=(
      #|[Some(<StringView: "HELLO">)]
    ),
  )
  debug_inspect(
    regex.execute("Hello").results(),
    content=(
      #|[Some(<StringView: "Hello">)]
    ),
  )
  debug_inspect(
    regex.execute("hElLo").results(),
    content=(
      #|[Some(<StringView: "hElLo">)]
    ),
  )

  // Test inline case insensitive
  let regex = @regexp.compile("(?i:hello)")
  debug_inspect(
    regex.execute("HELLO world").results(),
    content=(
      #|[Some(<StringView: "HELLO">)]
    ),
  )

  // Test case sensitive (default)
  let regex = @regexp.compile("hello")
  debug_inspect(
    regex.execute("hello").results(),
    content=(
      #|[Some(<StringView: "hello">)]
    ),
  )
  inspect(regex.execute("HELLO").matched(), content="false")

  // Test mixed case sensitivity
  let regex = @regexp.compile("(?i:hello) world")
  debug_inspect(
    regex.execute("HELLO world").results(),
    content=(
      #|[Some(<StringView: "HELLO world">)]
    ),
  )
  inspect(regex.execute("HELLO WORLD").matched(), content="false")
}

// ///|

///|
test "unicode and international characters" {
  // Test basic unicode
  let regex = @regexp.compile("café")
  debug_inspect(
    regex.execute("I love café").results(),
    content=(
      #|[Some(<StringView: "café">)]
    ),
  )

  // Test unicode word boundaries
  let regex = @regexp.compile("\\w+")
  debug_inspect(
    regex.execute("hello 世界").results(),
    content=(
      #|[Some(<StringView: "hello">)]
    ),
  )

  // Test unicode character classes
  let regex = @regexp.compile("[\\u4e00-\\u9fff]+")
  assert_true(regex.execute("Hello 世界 World").matched())
  debug_inspect(
    regex.execute("Hello 世界 World").results(),
    content=(
      #|[Some(<StringView: "世界">)]
    ),
  )

  // Test emoji (if supported)
  let regex = @regexp.compile("😀")
  let result = regex.execute("Happy 😀 face")
  guard! result.matched()
  debug_inspect(
    result.get(0),
    content=(
      #|Some(<StringView: "😀">)
    ),
  )
}

///|
test "complex real-world patterns" {
  // Email validation (comprehensive)
  let email_regex = @regexp.compile(
    "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
  )
  debug_inspect(
    email_regex.execute("user@example.com").results(),
    content=(
      #|[Some(<StringView: "user@example.com">)]
    ),
  )
  debug_inspect(
    email_regex.execute("test.email+tag@domain.co.uk").results(),
    content=(
      #|[Some(<StringView: "test.email+tag@domain.co.uk">)]
    ),
  )
  inspect(email_regex.execute("invalid.email").matched(), content="false")

  // Phone number patterns
  let phone_regex = @regexp.compile("\\(?\\d{3}\\)?[ -.]?\\d{3}[-.]?\\d{4}")
  debug_inspect(
    phone_regex.execute("(123)456-7890").results(),
    content=(
      #|[Some(<StringView: "(123)456-7890">)]
    ),
  )
  debug_inspect(
    phone_regex.execute("123.456.7890").results(),
    content=(
      #|[Some(<StringView: "123.456.7890">)]
    ),
  )
  debug_inspect(
    phone_regex.execute("1234567890").results(),
    content=(
      #|[Some(<StringView: "1234567890">)]
    ),
  )

  // URL matching
  let url_regex = @regexp.compile("https?://[^\\s]+")
  debug_inspect(
    url_regex.execute("Visit https://example.com for more").results(),
    content=(
      #|[Some(<StringView: "https://example.com">)]
    ),
  )
  debug_inspect(
    url_regex.execute("Go to http://test.org/path?query=1").results(),
    content=(
      #|[Some(<StringView: "http://test.org/path?query=1">)]
    ),
  )

  // IP address validation
  let ip_regex = @regexp.compile(
    "\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b",
  )
  debug_inspect(
    ip_regex.execute("Server IP: 192.168.1.1").results(),
    content=(
      #|[Some(<StringView: "192.168.1.1">)]
    ),
  )

  // Credit card number (simple pattern)
  let cc_regex = @regexp.compile(
    "\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}[-\\s]?\\d{4}",
  )
  debug_inspect(
    cc_regex.execute("1234 5678 9012 3456").results(),
    content=(
      #|[Some(<StringView: "1234 5678 9012 3456">)]
    ),
  )
  debug_inspect(
    cc_regex.execute("1234-5678-9012-3456").results(),
    content=(
      #|[Some(<StringView: "1234-5678-9012-3456">)]
    ),
  )

  // HTML tag matching
  let html_regex = @regexp.compile("<([a-zA-Z]+)[^>]*>(.*?)</\\1>")
  let result = html_regex.execute("<div class='test'>content</div>")
  debug_inspect(
    result.get(1),
    content=(
      #|Some(<StringView: "div">)
    ),
  )
  debug_inspect(
    result.get(2),
    content=(
      #|Some(<StringView: "content">)
    ),
  )
}

///|
test "edge cases and boundary conditions" {
  // Empty string matching
  let regex = @regexp.compile("")
  debug_inspect(
    regex.execute("").results(),
    content=(
      #|[Some(<StringView: "">)]
    ),
  )
  debug_inspect(
    regex.execute("abc").results(),
    content=(
      #|[Some(<StringView: "">)]
    ),
  )

  // Very long strings
  let long_string = "a".repeat(1000) + "b"
  let regex = @regexp.compile("a+b")
  debug_inspect(
    regex.execute(long_string).results(),
    content=(
      #|[
      #|  Some(
      #|    <StringView:
      #|      "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaab">,
      #|  ),
      #|]
    ),
  )

  // Pattern at string boundaries
  let regex = @regexp.compile("^a|b$")
  debug_inspect(
    regex.execute("a").results(),
    content=(
      #|[Some(<StringView: "a">)]
    ),
  )
  debug_inspect(
    regex.execute("b").results(),
    content=(
      #|[Some(<StringView: "b">)]
    ),
  )
  debug_inspect(
    regex.execute("ab").results(),
    content=(
      #|[Some(<StringView: "a">)]
    ),
  )
  debug_inspect(regex.execute("ba").results(), content="[]")

  // Zero-width assertions
  let regex = @regexp.compile("\\b")
  let result = regex.execute("hello world")
  inspect(result.matched(), content="true")
  // Word boundaries are zero-width, so match should be empty string
  if result.matched() {
    debug_inspect(
      result.get(0),
      content=(
        #|Some(<StringView: "">)
      ),
    )
  }

  // Overlapping matches (should get first/leftmost)
  let regex = @regexp.compile("aa")
  debug_inspect(
    regex.execute("aaa").results(),
    content=(
      #|[Some(<StringView: "aa">)]
    ),
  )

  // Pattern with all quantifiers
  let regex = @regexp.compile("a*b+c?d{2}e{2,4}f{3,}")
  debug_inspect(
    regex.execute("bbcddeeefffff").results(),
    content=(
      #|[Some(<StringView: "bbcddeeefffff">)]
    ),
  )
}

///|
test "backreference" {
  let regex = @regexp.compile("((?:a|b)*)\\1\\1")
  debug_inspect(
    regex.execute("aaabbb").results(),
    content=(
      #|[Some(<StringView: "aaa">), Some(<StringView: "a">)]
    ),
  )
  debug_inspect(
    regex.execute("aaa").results(),
    content=(
      #|[Some(<StringView: "aaa">), Some(<StringView: "a">)]
    ),
  )
  debug_inspect(
    regex.execute("aaaa").results(),
    content=(
      #|[Some(<StringView: "aaa">), Some(<StringView: "a">)]
    ),
  )
  debug_inspect(
    regex.execute("aaaaaa").results(),
    content=(
      #|[Some(<StringView: "aaaaaa">), Some(<StringView: "aa">)]
    ),
  )

  // Example that needs exponential backtracking
  let regex = @regexp.compile("(?:((?:a|b)*)\\1\\1)+")
  debug_inspect(
    regex.execute("aaabbb").results(),
    content=(
      #|[Some(<StringView: "aaabbb">), Some(<StringView: "b">)]
    ),
  )

  // Palindrome detection
  let palindrome = @regexp.compile("^(.)(.)\\2\\1")
  debug_inspect(
    palindrome.execute("abba").results(),
    content=(
      #|[
      #|  Some(<StringView: "abba">),
      #|  Some(<StringView: "a">),
      #|  Some(<StringView: "b">),
      #|]
    ),
  )
}

///|
test "invalid backreferences" {
  try @regexp.compile("\\1000") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "\\1000">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\01") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "\\01">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "named backreferences with \\k<name>" {
  // Basic named backreference test
  let regex = @regexp.compile("(?<word>\\w+) \\k<word>")
  debug_inspect(
    regex.execute("hello hello").results(),
    content=(
      #|[Some(<StringView: "hello hello">), Some(<StringView: "hello">)]
    ),
  )
  inspect(regex.execute("hello world").matched(), content="false")

  // Multiple named backreferences
  let regex = @regexp.compile(
    "(?<first>\\w+) (?<second>\\w+) \\k<first> \\k<second>",
  )
  debug_inspect(
    regex.execute("cat dog cat dog").results(),
    content=(
      #|[
      #|  Some(<StringView: "cat dog cat dog">),
      #|  Some(<StringView: "cat">),
      #|  Some(<StringView: "dog">),
      #|]
    ),
  )

  // Named backreference with repetition
  let regex = @regexp.compile("(?<char>.)\\k<char>{2}")
  debug_inspect(
    regex.execute("aaa").results(),
    content=(
      #|[Some(<StringView: "aaa">), Some(<StringView: "a">)]
    ),
  )
  inspect(regex.execute("abb").matched(), content="false")

  // Using \k<name> with alternation
  let regex = @regexp.compile("(?<tag>\\w+)\\s*\\|\\s*\\k<tag>")
  debug_inspect(
    regex.execute("div | div").results(),
    content=(
      #|[Some(<StringView: "div | div">), Some(<StringView: "div">)]
    ),
  )

  // HTML-like tag matching
  let regex = @regexp.compile("<(?<tag>[a-z]+)>.*?</\\k<tag>>")
  debug_inspect(
    regex.execute("<div>content</div>").results(),
    content=(
      #|[Some(<StringView: "<div>content</div>">), Some(<StringView: "div">)]
    ),
  )
  inspect(regex.execute("<div>content</span>").matched(), content="false")

  // Case-insensitive named backreference
  let regex = @regexp.compile("(?i:(?<word>[a-z]+) \\k<word>)")
  debug_inspect(regex.execute("Hello HELLO").results(), content="[]")
}

///|
test "named backreference errors" {
  // Undefined name
  try @regexp.compile("\\k<undefined>") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(
          #|  err=InvalidEscape,
          #|  source_fragment=<StringView: "\\k<undefined>">,
          #|)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }

  // Recursive reference - reference to a capture group that is currently being defined
  try @regexp.compile("(?<recur>.\\k<recur>)") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(
          #|  err=InvalidEscape,
          #|  source_fragment=<StringView: "\\k<recur>)">,
          #|)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }

  // Reference to a named group that doesn't exist yet
  try @regexp.compile("\\k<name> (?<name>\\w+)") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(
          #|  err=InvalidEscape,
          #|  source_fragment=<StringView: "\\k<name> (?<name>\\w+)">,
          #|)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }

  // Invalid syntax for named backreference
  try @regexp.compile("\\k<name") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: "">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
  try @regexp.compile("\\k name>") catch {
    e =>
      debug_inspect(
        e,
        content=(
          #|RegexpError(err=InvalidEscape, source_fragment=<StringView: " name>">)
        ),
      )
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "unicode general category properties" {
  // Test Unicode property \p{L} (letter)
  let regex = @regexp.compile("\\p{Letter}+")
  debug_inspect(
    regex.execute("Hello 世界").results(),
    content=(
      #|[Some(<StringView: "Hello">)]
    ),
  )

  // Test Unicode property \p{N} (number)
  let regex = @regexp.compile("\\p{Number}+")
  debug_inspect(
    regex.execute("123 and 456").results(),
    content=(
      #|[Some(<StringView: "123">)]
    ),
  )

  // Test Unicode property \p{Z} (separator)
  let regex = @regexp.compile("\\p{Z}+")
  debug_inspect(
    regex.execute("Hello 世界 ").results(),
    content=(
      #|[Some(<StringView: " ">)]
    ),
  )
}

///|
test "char classes" {
  // negated case insensitive
  let regex = @regexp.compile("(?i:[^a-z]+)")
  debug_inspect(
    regex.execute("1234").results(),
    content=(
      #|[Some(<StringView: "1234">)]
    ),
  )
  debug_inspect(regex.execute("a").results(), content="[]")
  debug_inspect(regex.execute("A").results(), content="[]")
  debug_inspect(regex.execute("K").results(), content="[]")

  // digits
  let regex = @regexp.compile("[\\d]+")
  debug_inspect(
    regex.execute("123abc").results(),
    content=(
      #|[Some(<StringView: "123">)]
    ),
  )
  // non-digits
  let regex = @regexp.compile("[\\D]+")
  debug_inspect(
    regex.execute("abc123").results(),
    content=(
      #|[Some(<StringView: "abc">)]
    ),
  )

  // words
  let regex = @regexp.compile("[\\w]+")
  debug_inspect(
    regex.execute("hello_world123 ").results(),
    content=(
      #|[Some(<StringView: "hello_world123">)]
    ),
  )
  let regex = @regexp.compile("[\\W]+")
  debug_inspect(
    regex.execute("中文abc").results(),
    content=(
      #|[Some(<StringView: "中文">)]
    ),
  )

  // unicode properties
  let regex = @regexp.compile("[\\p{L}\\p{N}]+")
  debug_inspect(
    regex.execute("Hello世界123\n").results(),
    content=(
      #|[Some(<StringView: "Hello世界123">)]
    ),
  )
  let regex = @regexp.compile("[^\\p{L}\\p{N}]+")
  debug_inspect(
    regex.execute("Hello世界123\n").results(),
    content=(
      #|[Some(<StringView: "\n">)]
    ),
  )
  let regex = @regexp.compile("[\\P{L}]+")
  debug_inspect(
    regex.execute("Hello世界123\n").results(),
    content=(
      #|[Some(<StringView: "123\n">)]
    ),
  )
}

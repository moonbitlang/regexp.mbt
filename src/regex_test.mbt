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

  // multiline flag
  let regexp = compile("($)")
  assert_true(regexp.execute("\n").matched())
  inspect(regexp.execute("\n").results().count(), content="2")
  inspect(
    regexp.execute("\n").results().map(_.start_offset()).collect(),
    content="[1, 1]",
  )
  let regexp = compile("($)", flags="m")
  assert_true(regexp.execute("\n").matched())
  inspect(
    regexp.execute("\n").results().map(_.start_offset()).collect(),
    content="[0, 0]",
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

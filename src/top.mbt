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

///| Compiles a regular expression into an execution engine.
/// 
/// Parses and compiles a regular expression string into a reusable execution engine.
/// The compiled engine can be executed multiple times, avoiding the overhead of repeated parsing and compilation.
/// 
/// Args:
/// - `regexp`: A string view of the regular expression.
/// 
/// Returns: The compiled regular expression execution engine.
/// 
/// Throws: `Error_` if the regular expression syntax is invalid.
/// 
/// Example:
/// ```moonbit
/// let engine = compile("a(bc|de)f")
/// inspect(engine.execute("xxabcf").results(), content=(
///   #|[Some("abcf"), Some("bc")]
/// ))
/// ```
pub fn compile(
  regexp : @string.View,
  flags~ : @string.View = ""
) -> Regexp raise RegexpError {
  regexp
  |> parse(flags={
    multiline: flags.contains("m"),
    singleline: flags.contains("s"),
    ignore_case: flags.contains("i"),
  })
  |> ParseResult::compile()
}

///| Gets the index of a capture group by its name.
/// 
/// Finds the index of a capture group with the specified name in the results.
/// Used to access named capture groups, such as those defined in the form `(?<name>pattern)`.
/// 
/// Args:
/// - `self`: The regular expression execution engine.
/// - `name`: The name of the capture group.
/// 
/// Returns: The index of the capture group, or `None` if the group name does not exist.
/// 
/// Example:
/// ```moonbit
/// let engine = compile("(?<word>\\w+)")
/// inspect(engine.group_by_name("word"), content="Some(1)")
/// ```
pub fn Regexp::group_by_name(self : Regexp, name : String) -> Int? {
  self.map.get(name)
}

///| Gets the total number of capture groups in the regular expression.
/// 
/// Returns the number of capture groups defined in the regular expression pattern, including both named and anonymous groups.
/// Group with index 0 always represents the entire match, and actual capture groups start from index 1.
/// 
/// Args:
/// - `self`: The regular expression execution engine.
/// 
/// Returns: The total number of capture groups (including the full match at index 0).
/// 
/// Example:
/// ```moonbit
/// let engine = compile("(a)(b|c)")
/// inspect(engine.group_count(), content="3")
/// ```
pub fn Regexp::group_count(self : Regexp) -> Int {
  self.capture
}

///| Gets the names of all named capture groups in the regular expression.
/// 
/// Returns an iterator that contains the names of all named capture groups in the regular expression.
/// Only explicitly named capture groups, such as those defined in the form `(?<name>pattern)`, are returned.
/// 
/// Args:
/// - `self`: The regular expression execution engine.
/// 
/// Returns: An iterator containing all group names.
/// 
/// Example:
/// ```moonbit
/// let engine = compile("(?<first>a)(?<second>b)")
/// inspect(engine.group_names(), content=
///   #|["first", "second"]
/// )
/// ```
pub fn Regexp::group_names(self : Regexp) -> Array[String] {
  self.map.keys().collect()
}

///| Executes a regular expression match on the input text.
/// 
/// Uses the compiled regular expression engine to perform a match on the specified input text,
/// returning a `MatchResult` object containing the match results and capture group information.
/// It uses a leftmost-first matching strategy, returning the first match found.
/// 
/// Args:
/// - `self`: The regular expression execution engine.
/// - `input`: The input text to match against.
/// 
/// Returns: A `MatchResult` object containing the match status and capture group information.
/// 
/// Example:
/// ```moonbit
/// let engine = compile("a(bc|de)f")
/// let result = engine.execute("xxabcf")
/// if result.matched() { 
///   inspect(result.get(0), content=(
///     #|Some("abcf")
///   ))
/// }
/// ```
pub fn Regexp::execute(self : Regexp, input : @string.View) -> MatchResult {
  let captures = vm(
    self.instructions,
    input,
    self.capture,
    allow_exponentiaion=self.allow_exponentiaion,
  )
  let rest = if captures.length() < 2 {
    input
  } else {
    let match_end = captures[1]
    if match_end >= 0 && match_end <= input.length() {
      input.view(start_offset=match_end)
    } else {
      input
    }
  }
  { input, captures, names: self.map, rest }
}

///| Regular expression match result.
/// 
/// Contains the complete result information of a regular expression match, including:
/// - The original input text.
/// - An array of capture group position information.
/// - A map of named capture groups.
/// 
/// Structure of the capture group array:
/// - Index 0, 1: Start and end positions of the full match.
/// - Index 2, 3: Start and end positions of the first capture group.
/// - Index 4, 5: Start and end positions of the second capture group.
/// - And so on...
struct MatchResult {
  input : @string.View
  captures : Array[Int]
  names : Map[String, Int]
  rest : @string.View
}

///| Checks if the match was successful.
/// 
/// Determines whether the regular expression found a match in the input text.
/// An empty capture group array indicates that no match was found.
/// 
/// Args:
/// - `self`: The match result object.
/// 
/// Returns: `true` if a match was found, otherwise `false`.
/// 
/// Example:
/// ```moonbit
/// let result = compile("text").execute("text")
/// inspect(result.matched(), content="true")
/// ```
pub fn MatchResult::matched(self : Self) -> Bool {
  not(self.captures is [])
}

///| Gets the content of a capture group by its index.
/// 
/// Returns the corresponding matched text based on the capture group's index.
/// Index 0 represents the full match, while indices 1 and above represent individual capture groups.
/// 
/// Args:
/// - `self`: The match result object.
/// - `index`: The index of the capture group (0 for the full match).
/// 
/// Returns: 
/// - `Some(view)`: The text view corresponding to the capture group.
/// - `None`: If the index is invalid or the capture group did not match.
/// 
/// Example:
/// ```moonbit
/// let result = compile(".(bc)").execute("abc")
/// inspect(result.get(0), content=(
///   #|Some("abc")
/// ))
/// let first_group = result.get(1)
/// inspect(first_group, content=(
///   #|Some("bc")
/// ))
/// ```
pub fn MatchResult::get(self : Self, index : Int) -> @string.View? {
  if self.captures.is_empty() ||
    index < 0 ||
    index >= self.captures.length() / 2 {
    return None
  }
  let start = self.captures[index * 2]
  let end = self.captures[index * 2 + 1]
  if start < 0 || end < start || end > self.input.length() {
    return None
  }
  Some(self.input.view(start_offset=start, end_offset=end))
}

///|
/// Returns a map containing all named capture groups and their matched
/// contents.
///
/// Parameters:
///
/// * `self` : The match result object containing named capture group
///   information.
///
/// Returns a map where keys are the names of capture groups and values are
/// their corresponding matched content. If a named group did not participate in
/// the match, its value will be `None`.
///
/// Example:
///
/// ```moonbit
/// let engine = compile("(?<word>\\w+)\\s+(?<num>\\d+)")
/// let result = engine.execute("hello 123")
/// inspect(result.groups(), content=(
///   #|{"word": Some("hello"), "num": Some("123")}
/// ))
/// ```
///
pub fn MatchResult::groups(self : Self) -> Map[String, @string.View?] {
  self.names
  .iter()
  .map(p => {
    let content = self.get(p.1)
    (p.0, content)
  })
  |> Map::from_iter
}

///| Gets an iterator over the content of all valid capture groups.
/// 
/// Returns an iterator that contains the content of all successfully matched capture groups,
/// including the full match (index 0) and all other capture groups. Only valid matched content is returned,
/// skipping any unmatched capture groups.
/// 
/// Args:
/// - `self`: The match result object.
/// 
/// Returns: An iterator containing the content of all valid capture groups.
/// 
/// Example:
/// ```moonbit
/// let result = compile("(\\w)+").execute("abc")
/// inspect(result.results(), content=(
///   #|[Some("abc"), Some("c")]
/// ))
/// ```
pub fn MatchResult::results(self : Self) -> Array[@string.View?] {
  let results = []
  for i = 0; i < self.captures.length() / 2; i = i + 1 {
    let start = self.captures[i * 2]
    let end = self.captures[i * 2 + 1]
    if start == -1 && end == -1 {
      results.push(None)
    } else {
      results.push(Some(self.input.view(start_offset=start, end_offset=end)))
    }
  }
  results
}

///| Gets the remaining string after a match.
/// 
/// Returns the remaining input text after the end of the match, which can be used to continue searching for the next match.
/// If the match fails, it returns the original input text.
/// 
/// Args:
/// - `self`: The match result object.
/// 
/// Returns: A view of the text remaining from the end of the match.
/// 
/// Example:
/// ```moonbit
/// let result = compile("hello ").execute("hello world")
/// inspect(result.rest(), content="world")
/// let result = compile("hello ").execute("what?")
/// inspect(result.rest(), content="what?")
/// ```
pub fn MatchResult::rest(self : Self) -> @string.View {
  self.rest
}

///|
test "rest method" {
  let engine = compile("hello")
  let result = engine.execute("hello world")
  inspect(result.matched(), content="true")
  inspect(result.rest(), content=" world")
  let result2 = engine.execute("say hello")
  inspect(result2.matched(), content="true")
  inspect(result2.rest(), content="")
  let result3 = engine.execute("hi there")
  inspect(result3.matched(), content="false")
  inspect(result3.rest(), content="hi there")
  inspect("Test rest method completed", content="Test rest method completed")
}

///|
test "rest method with capture groups" {
  let engine = compile("(\\w+)\\s+")
  let result = engine.execute("hello world test")
  inspect(result.matched(), content="true")
  inspect(
    result.get(0),
    content=
      #|Some("hello ")
    ,
  )
  inspect(
    result.get(1),
    content=
      #|Some("hello")
    ,
  )
  inspect(result.rest(), content="world test")
  let engine2 = compile(".*")
  let result2 = engine2.execute("everything")
  inspect(result2.matched(), content="true")
  inspect(
    result2.get(0),
    content=
      #|Some("everything")
    ,
  )
  inspect(result2.rest(), content="")
}

///|
test "rest method usage example" {
  let engine = compile("\\b\\w+\\b")
  let mut input : @string.View = "word1 word2 word3"
  let result1 = engine.execute(input)
  inspect(
    result1.get(0),
    content=
      #|Some("word1")
    ,
  )
  input = result1.rest()
  let result2 = engine.execute(input)
  inspect(
    result2.get(0),
    content=
      #|Some("word2")
    ,
  )
  inspect(result2.rest(), content=" word3")
}

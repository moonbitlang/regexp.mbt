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
async fn main {
  let args = @env.args()
  guard args is [_, input, output] else {
    fail(
      "usage: moon run --target native src -- <unicode-data-directory> <output-directory>",
    )
  }
  handle_case_folding(input, output)
  handle_property_value_aliases(input, output)
  handle_general_category(input, output)
}

///|
async fn read_unicode_lines(directory : String, name : String) -> Array[String] {
  let data = @fs.read_file("\{directory}/\{name}").text()
  [
    for line in data.split("\n") if !line.is_empty() => line.to_owned()
  ]
}

///|
fn write_line(output : StringBuilder, text : String) -> Unit {
  output.write_string(text)
  output.write_char('\n')
}

///|
fn char_literal(ch : Char) -> String {
  "'\\u{\{ch.to_int().to_string(radix=16)}}'"
}

///|
fn extend_range(range : Array[Char], end : Char) -> Unit {
  range[range.length() - 1] = end
}

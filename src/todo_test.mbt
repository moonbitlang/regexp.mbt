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
test "to be discussed" {
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
  // Behavior mismatch between Golang and JS
  let regex = @regexp.compile("((?<a>a)|(?<b>b))+")
  let result = regex.execute("ab")
  inspect(
    result.group_by_name("a"),
    content=
      #|Some("a")
    ,
  )
  inspect(
    result.group_by_name("b"),
    content=
      #|Some("b")
    ,
  )
}

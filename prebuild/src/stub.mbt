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

///| Run the program.
pub fn run() -> Result[Unit, Unit] {
  let mut result = Ok(())
  @promise.spawn(async fn(_defer) raise {
    top() catch {
      error => {
        result = Err(())
        @io.println_sync("Error \{error}", stream=@io.stderr)
      }
    }
  })
  |> ignore
  @io.event_loop.run()
  result
}

///|
const UNICODE_ADDRESS = "www.unicode.org"

///|
const UNICODE_DATABASE_PATH = "/Public/16.0.0/ucd"

///|
/// User should change this function to do what they want
async fn top() -> Unit raise {
  @promise.spawn(handle_case_folding).await()
  @promise.spawn(handle_property_value_aliases).await()
  @promise.spawn(handle_general_category).await()
}

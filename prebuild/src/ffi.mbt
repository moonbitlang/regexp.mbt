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

// DO NOT EDIT!

///|
pub fn wasmExportRun() -> Int {
  let result : Result[Unit, Unit] = run()
  let lowered = match result {
    Ok(_payload) => 0
    Err(_payload2) => 1
  }
  return lowered
}

///|
pub fn cabi_realloc(
  src_offset : Int,
  src_size : Int,
  dst_alignment : Int,
  dst_size : Int,
) -> Int {
  @ffi.cabi_realloc(src_offset, src_size, dst_alignment, dst_size)
}

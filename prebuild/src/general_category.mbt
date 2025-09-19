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
const Unassigned = "Cn"

///|
async fn get_general_category_code_points(
  defer_ : (() -> Unit) -> Unit,
) -> Map[String, Array[Char]] {
  // Get the Unicode data from Unicode.org for general categories
  let request = @http.request(
    UNICODE_ADDRESS,
    path=UNICODE_DATABASE_PATH + "/UnicodeData.txt",
  )
  let data = @http.fetch(request)
  defer_(() => data.drop())
  guard data.consume() is Ok(body)
  defer_(() => body.drop())
  guard body.stream() is Ok(input_stream)
  defer_(() => input_stream.drop())

  // Map to store the character ranges for each category
  let category_ranges : Map[String, Array[Char]] = {
    "LC": [],
    "L": [],
    "M": [],
    "N": [],
    "P": [],
    "S": [],
    "Z": [],
    "C": [],
  }
  category_ranges[Unassigned] = []

  // Process UnicodeData.txt
  // Parse each line and extract the code point and general category
  let regexp = @regexp.compile(
    (
      #|^(?<charcode>[0-9A-F]+);(?<indicator>[^;]*);(?<category>[^;]*);
    ),
  )
  let mut prev_category = ""
  let mut prev_code_point = (-1).unsafe_to_char()
  while true {
    let line = @io.read_line(stream=input_stream) catch {
      @streams.Closed => break
      e => raise e
    }
    let result = regexp.execute(line)
    guard result.matched() else {
      fail("Error: Invalid line format in UnicodeData.txt: \{line}")
    }
    let groups = result.groups()
    let charcode = @strconv.parse_int(
      groups.get("charcode").unwrap().to_string(),
      base=16,
    ).unsafe_to_char()
    let category = groups.get("category").unwrap().to_string()
    // Check for unknown category
    if charcode.to_int() - prev_code_point.to_int() != 1 &&
      not(groups.get("indicator").unwrap().has_suffix("Last>")) {
      category_ranges
      .get(Unassigned)
      .unwrap()
      ..push((prev_code_point.to_int() + 1).unsafe_to_char())
      ..push((charcode.to_int() - 1).unsafe_to_char())
      if prev_category is ("Cc" | "Cf" | "Cs" | "Co" | "Cn") {
        category_ranges
        .get("C")
        .unwrap()
        ..unsafe_pop_back()
        ..push((charcode.to_int() - 1).unsafe_to_char())
      }
      prev_category = Unassigned
    }

    // Update ranges
    let range = if category_ranges.get(category) is Some(ranges) {
      ranges
    } else {
      let range = []
      category_ranges[category] = range
      range
    }
    if category == prev_category {
      range.unsafe_pop_back()
      range.push(charcode)
    } else {
      range..push(charcode)..push(charcode)
    }

    // Handle special case
    if category is ("Lu" | "Ll" | "Lt") {
      if prev_category is ("Lu" | "Ll" | "Lt") {
        category_ranges.get("LC").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("LC").unwrap()..push(charcode)..push(charcode)
      }
    }
    if category is ("Lu" | "Ll" | "Lt" | "Lm" | "Lo") {
      if prev_category is ("Lu" | "Ll" | "Lt" | "Lm" | "Lo") {
        category_ranges.get("L").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("L").unwrap()..push(charcode)..push(charcode)
      }
    }
    if category is ("Mn" | "Mc" | "Me") {
      if prev_category is ("Mn" | "Mc" | "Me") {
        category_ranges.get("M").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("M").unwrap()..push(charcode)..push(charcode)
      }
    }
    if category is ("Nd" | "Nl" | "No") {
      if prev_category is ("Nd" | "Nl" | "No") {
        category_ranges.get("N").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("N").unwrap()..push(charcode)..push(charcode)
      }
    }
    if category is ("Pc" | "Pd" | "Ps" | "Pe" | "Pi" | "Pf" | "Po") {
      if prev_category is ("Pc" | "Pd" | "Ps" | "Pe" | "Pi" | "Pf" | "Po") {
        category_ranges.get("P").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("P").unwrap()..push(charcode)..push(charcode)
      }
    }
    if category is ("Sm" | "Sc" | "Sk" | "So") {
      if prev_category is ("Sm" | "Sc" | "Sk" | "So") {
        category_ranges.get("S").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("S").unwrap()..push(charcode)..push(charcode)
      }
    }
    if category is ("Zs" | "Zl" | "Zp") {
      if prev_category is ("Zs" | "Zl" | "Zp") {
        category_ranges.get("Z").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("Z").unwrap()..push(charcode)..push(charcode)
      }
    }
    if category is ("Cc" | "Cf" | "Cs" | "Co" | "Cn") {
      if prev_category is ("Cc" | "Cf" | "Cs" | "Co" | "Cn") {
        category_ranges.get("C").unwrap()..unsafe_pop_back()..push(charcode)
      } else {
        category_ranges.get("C").unwrap()..push(charcode)..push(charcode)
      }
    }

    // Update
    prev_code_point = charcode
    prev_category = category
  }
  category_ranges
}

///|
async fn handle_general_category(defer_ : (() -> Unit) -> Unit) -> Unit {
  let category_ranges = @promise.spawn(get_general_category_code_points).await()

  // Prepare file. Assume preopen is where the file needs to be written
  guard @preopens.get_directories() is [(preopen, _), ..] else {
    fail("Error: No preopen directories found")
  }
  let file = preopen
    .open_at(
      @fs.PathFlags::default(),
      "general_category.mbt",
      @fs.OpenFlags::default().set(CREATE).set(TRUNCATE),
      @fs.DescriptorFlags::default().set(WRITE),
    )
    .unwrap_or_error()
  defer_(() => file.drop())
  let output_stream = file.write_via_stream(0).unwrap_or_error()
  defer_(() => output_stream.drop())

  // Start writing template
  @io.println(
    (
      #|// generated by prebuild : just -d ./prebuild -f ./prebuild/justfile run
      #|
      #|///|
      #|pub let general_category_ranges : Map[String, Array[Char]] = {
    ),
    stream=output_stream,
  )
  for category_entry in category_ranges.to_array() {
    let (cat, _) = category_entry
    if cat != "Cs" {
      @io.print(
        (
          $|  "\{cat}": \{cat}.iter().collect(),
        ),
        stream=output_stream,
      )
    } else {
      @io.print(
        (
          $|  "\{cat}": \{cat.to_lower()},
        ),
        stream=output_stream,
      )
    }
  } else {
    @io.println(
      (
        #|}
      ),
      stream=output_stream,
    )
  }

  // Write the category ranges
  for category_entry in category_ranges.to_array() {
    let (cat, ranges) = category_entry
    if cat != "Cs" {
      @io.print(
        (
          #|
          #|///|
          $|const \{cat}: String = $|
        ),
        stream=output_stream,
      )
      for ch in ranges {
        @io.print(
          "\\u{\{ch.to_int().to_string(radix=16)}}",
          stream=output_stream,
        )
      }
    } else {
      @io.print(
        (
          #|
          #|///|
          $|let \{cat.to_lower()}: Array[Char] = [
        ),
        stream=output_stream,
      )
      for ch in ranges {
        @io.print(
          "(0x\{ch.to_int().to_string(radix=16)}).unsafe_to_char(), ",
          stream=output_stream,
        )
      }
      @io.println(
        (
          #|]
        ),
        stream=output_stream,
      )
    }
  }
  output_stream.blocking_flush().unwrap()
}

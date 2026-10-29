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
  input : String,
) -> Map[String, Array[Char]] {
  let lines = read_unicode_lines(input, "UnicodeData.txt")

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
  for line in lines {
    let result = regexp.execute(line)
    guard result.matched() else {
      fail("Error: Invalid line format in UnicodeData.txt: \{line}")
    }
    let groups = result.groups()
    let charcode = @string.parse_int(
      groups.get("charcode").unwrap().to_owned(),
      base=16,
    ).unsafe_to_char()
    let category = groups.get("category").unwrap().to_owned()
    // Check for unknown category
    if charcode.to_int() - prev_code_point.to_int() != 1 &&
      !groups.get("indicator").unwrap().has_suffix("Last>") {
      category_ranges
      .get(Unassigned)
      .unwrap()
      ..push((prev_code_point.to_int() + 1).unsafe_to_char())
      .push((charcode.to_int() - 1).unsafe_to_char())
      if prev_category is ("Cc" | "Cf" | "Cs" | "Co" | "Cn") {
        extend_range(
          category_ranges.get("C").unwrap(),
          (charcode.to_int() - 1).unsafe_to_char(),
        )
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
      extend_range(range, charcode)
    } else {
      range..push(charcode).push(charcode)
    }

    // Handle special case
    if category is ("Lu" | "Ll" | "Lt") {
      if prev_category is ("Lu" | "Ll" | "Lt") {
        extend_range(category_ranges.get("LC").unwrap(), charcode)
      } else {
        category_ranges.get("LC").unwrap()..push(charcode).push(charcode)
      }
    }
    if category is ("Lu" | "Ll" | "Lt" | "Lm" | "Lo") {
      if prev_category is ("Lu" | "Ll" | "Lt" | "Lm" | "Lo") {
        extend_range(category_ranges.get("L").unwrap(), charcode)
      } else {
        category_ranges.get("L").unwrap()..push(charcode).push(charcode)
      }
    }
    if category is ("Mn" | "Mc" | "Me") {
      if prev_category is ("Mn" | "Mc" | "Me") {
        extend_range(category_ranges.get("M").unwrap(), charcode)
      } else {
        category_ranges.get("M").unwrap()..push(charcode).push(charcode)
      }
    }
    if category is ("Nd" | "Nl" | "No") {
      if prev_category is ("Nd" | "Nl" | "No") {
        extend_range(category_ranges.get("N").unwrap(), charcode)
      } else {
        category_ranges.get("N").unwrap()..push(charcode).push(charcode)
      }
    }
    if category is ("Pc" | "Pd" | "Ps" | "Pe" | "Pi" | "Pf" | "Po") {
      if prev_category is ("Pc" | "Pd" | "Ps" | "Pe" | "Pi" | "Pf" | "Po") {
        extend_range(category_ranges.get("P").unwrap(), charcode)
      } else {
        category_ranges.get("P").unwrap()..push(charcode).push(charcode)
      }
    }
    if category is ("Sm" | "Sc" | "Sk" | "So") {
      if prev_category is ("Sm" | "Sc" | "Sk" | "So") {
        extend_range(category_ranges.get("S").unwrap(), charcode)
      } else {
        category_ranges.get("S").unwrap()..push(charcode).push(charcode)
      }
    }
    if category is ("Zs" | "Zl" | "Zp") {
      if prev_category is ("Zs" | "Zl" | "Zp") {
        extend_range(category_ranges.get("Z").unwrap(), charcode)
      } else {
        category_ranges.get("Z").unwrap()..push(charcode).push(charcode)
      }
    }
    if category is ("Cc" | "Cf" | "Cs" | "Co" | "Cn") {
      if prev_category is ("Cc" | "Cf" | "Cs" | "Co" | "Cn") {
        extend_range(category_ranges.get("C").unwrap(), charcode)
      } else {
        category_ranges.get("C").unwrap()..push(charcode).push(charcode)
      }
    }

    // Update
    prev_code_point = charcode
    prev_category = category
  }
  category_ranges
}

///|
async fn handle_general_category(input : String, directory : String) -> Unit {
  let category_ranges = get_general_category_code_points(input)

  let output = StringBuilder()

  // Start writing template
  write_line(
    output,
    (
      #|// generated by prebuild : just -d ./prebuild -f ./prebuild/justfile run
      #|
      #|///|
      #|pub let general_category_ranges : Map[String, ArrayView[Char]] = {
    ),
  )

  // Write the category ranges
  for category_entry in category_ranges.to_array() {
    let (cat, ranges) = category_entry
    output.write_string(
      (
        $|  "\{cat}": [
      ),
    )
    if cat != "Cs" {
      for ch in ranges {
        output.write_string("'\\u{\{ch.to_int().to_string(radix=16)}}', ")
      }
    } else {
      output.write_string(
        (
          #|
          #|// Note, since 'Cs' (Surrogate) category contains code points that are
          #|// not valid characters and will not be visited by the regexp library,
          #|// we discard them here.
          #|//
          #|// They should never be used
          #|
        ),
      )
    }
    write_line(
      output,
      (
        #|],
      ),
    )
  }
  write_line(
    output,
    (
      #|}
    ),
  )
  @fs.write_file(
    "\{directory}/general_category.mbt",
    output.to_string(),
    create_mode=CreateOrTruncate,
  )
}

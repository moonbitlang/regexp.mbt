///|
enum CharRange {
  /// Represents some continous range from `start` to `end` (inclusive), 
  /// where the folding target is located at an `offset`
  ContinousRange(Char, Char, Int)
  /// Represents some range from `start` to `end` (inclusive) 
  /// but the chars are not continous (as if they were defined as `aAbBcC`),
  /// where the folding target is located at an `offset`
  AlternatingRange(Char, Char, Int)
}

///|
fn get_char_ranges(mappings : Array[(Char, Char)]) -> Array[CharRange] {
  let ranges = []
  for mapping in mappings {
    let (k, v) = mapping
    let o = v.to_int() - k.to_int()
    guard ranges.pop() is Some(last) else {
      ranges.push(ContinousRange(k, k, v.to_int() - k.to_int()))
    }
    match last {
      ContinousRange(start, end, offset) =>
        if k.to_int() - end.to_int() == 1 && offset == o {
          ranges.push(ContinousRange(start, k, o))
        } else if k.to_int() - end.to_int() == 2 && start == end && offset == o {
          ranges.push(AlternatingRange(start, k, o))
        } else {
          ranges.push(last)
          ranges.push(ContinousRange(k, k, o))
        }
      AlternatingRange(start, end, offset) =>
        if k.to_int() - end.to_int() == 2 && offset == o {
          ranges.push(AlternatingRange(start, k, o))
        } else {
          ranges.push(last)
          ranges.push(ContinousRange(k, k, o))
        }
    }
  }
  ranges
}

///|
pub typealias Engine as T

///|
pub fn compile(regexp : @string.View) -> T raise Error_ {
  regexp |> parse |> Regex::compile
}

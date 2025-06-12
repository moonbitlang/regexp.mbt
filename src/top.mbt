///|
pub typealias Engine as T

///|
pub fn compile(regexp : @string.View) -> T!Error_ {
  regexp |> parse |> Regex::compile
}

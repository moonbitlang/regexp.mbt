///|
test "simple regex test" {
  let regex = @regexp.compile("abc")
  let result = regex.execute("abc").results().collect()
  inspect(
    result,
    content=
      #|["abc"]
    ,
  )
  let result = regex.execute("ab").results().collect()
  inspect(result, content="[]")
  let result = regex.execute("abcd").results().collect()
  inspect(
    result,
    content=
      #|["abc"]
    ,
  )
}

///|
test "simple regex test matching leftmost" {
  let regex = @regexp.compile("a(bc|de)f")
  let result = regex.execute("xxabcf").results().collect()
  inspect(
    result,
    content=
      #|["abcf", "bc"]
    ,
  )
}

///|
test "simple regex test with repeat" {
  let regex = @regexp.compile("a(bc|de){2,}f")
  let result = regex.execute("xxabcdebcf").results().collect()
  inspect(
    result,
    content=
      #|["abcdebcf", "bc"]
    ,
  )
}

///|
test "invalid regex test" {
  guard (try? @regexp.compile("a(b")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=MissingParenthesis, data="")
    ,
  )
  guard (try? @regexp.compile("a(b|c")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=MissingParenthesis, data="")
    ,
  )
  guard (try? @regexp.compile("a|b)")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=UnexpectedParenthesis, data=")")
    ,
  )
  guard (try? @regexp.compile("a|b|c)")) is Err(error)
  error
  |> inspect(
    content=
      #|Error_(err=UnexpectedParenthesis, data=")")
    ,
  )
}

///|
test "to be fixed" {
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
}

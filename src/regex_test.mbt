///|
test "simple regex test" {
  let regex = @regexp.compile("abc")
  let result = regex.execute("abc")
  inspect(result, content="[0, 3]")
  let result = regex.execute("ab")
  inspect(result, content="[]")
  let result = regex.execute("abcd")
  inspect(result, content="[0, 3]")
}

///|
test "simple regex test matching leftmost" {
  let regex = @regexp.compile("a(bc|de)f")
  let result = regex.execute("xxabcf")
  inspect(result, content="[2, 6, 3, 5]")
}

///|
test "simple regex test with repeat" {
  let regex = @regexp.compile("a(bc|de){2,}f")
  let result = regex.execute("xxabcdebcf")
  inspect(result, content="[2, 10, 7, 9]")
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

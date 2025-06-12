///|
test "simple regex test" {
  let regex = @regexp.parse("abc")
  let matcher = regex.compile()
  let result = matcher.execute("abc")
  inspect(result, content="[0, 3]")
  let result = matcher.execute("ab")
  inspect(result, content="[]")
  let result = matcher.execute("abcd")
  inspect(result, content="[0, 3]")
}

///|
test "simple regex test matching leftmost" {
  let regex = @regexp.parse("a(bc|de)f")
  let matcher = regex.compile()
  let result = matcher.execute("xxabcf")
  inspect(result, content="[2, 6, 3, 5]")
}

///|
test "simple regex test with repeat" {
  let regex = @regexp.parse("a(bc|de){2,}f")
  let matcher = regex.compile()
  let result = matcher.execute("xxabcdebcf")
  inspect(result, content="[2, 10, 7, 9]")
}

///|
test "invalid regex test" {
  (try? @regexp.parse("a(b"))
  |> inspect(
    content=
      #|Err(Error_(err=MissingParenthesis, data=""))
    ,
  )
  (try? @regexp.parse("a(b|c"))
  |> inspect(
    content=
      #|Err(Error_(err=MissingParenthesis, data=""))
    ,
  )
  (try? @regexp.parse("a|b)"))
  |> inspect(content="Err(Error_(err=UnexpectedParenthesis, data=\")\"))")
  (try? @regexp.parse("a|b|c)"))
  |> inspect(content="Err(Error_(err=UnexpectedParenthesis, data=\")\"))")
}

///|
test "to be fixed" {
  // This should be allowed in some flavors where the `{` is considered a literal character
  (try? @regexp.parse("a{2"))
  |> inspect(
    content=
      #|Err(Error_(err=InvalidRepeatOp, data=""))
    ,
  )
  // This should be allowed in some flavors where the `}` is considered a literal character
  (try? @regexp.parse("a|b|c}"))
  |> inspect(
    content=
      #|Err(Error_(err=InvalidEscape, data="}"))
    ,
  )
  // This should raise InvalidRepeatOp to align with golang
  (try? @regexp.parse("a++"))
  |> inspect(
    content=
      #|Err(Error_(err=InvalidEscape, data="+"))
    ,
  )
  // This should be a char class with `]` and `[`
  @regexp.parse("[][]")
  |> inspect(
    content="Concat([CharClass([], neg=false), CharClass([], neg=false)])",
  )
}

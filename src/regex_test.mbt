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
}

///|
test "to be fixed" {
  (try? @regexp.parse("a|b)"))
  |> inspect(
    content="Ok(Alternate(CharClass(['a', 'a']), CharClass(['b', 'b'])))",
  )
  (try? @regexp.parse("a|b|c)"))
  |> inspect(
    content="Ok(Alternate(Alternate(CharClass(['a', 'a']), CharClass(['b', 'b'])), CharClass(['c', 'c'])))",
  )
}

# 🔍 regexp.mbt

> ⚠️ **API STABILITY NOTICE**  
> This is a v0.1.0 release with a stabilizing API. While core functionality is complete and well-tested,  
> API changes may occur in future versions as we refine the implementation.

**Lightning-fast regex for MoonBit** — inspired by
[Russ Cox's brilliant regex series](https://swtch.com/~rsc/regexp/regexp1.html).

## ⚡ Quick Start

```moonbit
test {
  // Compile once, use everywhere
  let engine = @regexp.compile("a(bc|de)f")
  let result = engine.execute("xxabcf")
  if result.matched() {
    // ["abcf", "bc"]
    let groups = result.results().collect()
  }
}
```

## 🎯 Core API

### Build & Execute

- `compile(pattern)` → Creates an `Engine`
- `engine.execute(text)` → Returns `MatchResult`

### Inspect Results

- `result.matched()` → `Bool`
- `result.group(index)` → Capture group content
- `result.results()` → Iterator over all matches

### Named Groups & Advanced

- `engine.group_by_name(name)` → Find group index by name
- `result.group_by_name(name)` → Get named group content
- `engine.group_count()` → Total capture groups

## 🎪 Syntax Playground

| Feature         | Example            | What it does                        |
| --------------- | ------------------ | ----------------------------------- |
| **Literals**    | `abc`              | Match exact text                    |
| **Wildcards**   | `a.c`              | `.` matches any character           |
| **Quantifiers** | `a+`, `b*`, `c?`   | One or more, zero or more, optional |
| **Ranges**      | `a{2,5}`           | Between 2-5 repetitions             |
| **Classes**     | `[a-z]`, `[^0-9]`  | Character sets, negated sets        |
| **Groups**      | `(abc)`, `(?:xyz)` | Capturing, non-capturing            |
| **Named**       | `(?<word>abc)`     | Named capture groups                |
| **Choice**      | `cat\|dog`         | Match either option                 |
| **Anchors**     | `^start`, `end$`   | Line boundaries                     |
| **Escapes**     | `\\u{41}`, `\\u0041` | Unicode escapes, standard escapes   |
| **Unicode Props** | `\\p{L}`, `\\p{Nd}` | Unicode general categories         |
| **Backrefs** ⚠️ | `(.)\\1`           | Reference previous captures         |

## 🌍 Unicode Property Support

Match characters by their Unicode general categories:

```moonbit
test "unicode properties" {
  // Matching gc=L
  let regex = @regexp.compile("\\p{Letter}+")
  inspect(
    regex.execute("Hello 世界").results(),
    content=
      #|[Some("Hello")]
    ,
  )

  // Matching gc=N
  let regex = @regexp.compile("\\p{Number}+")
  inspect(
    regex.execute("123 and 456").results(),
    content=
      #|[Some("123")]
    ,
  )
}
```

**Supported Propertes:**
- [General Category](https://www.unicode.org/reports/tr44/#General_Category_Values)

## 🔄 Backreferences

> ⚠️ **Performance Warning**: Backreferences can cause exponential time complexity in worst cases!

```moonbit
test "backreferences" {  
  // Palindrome detection (simple)
  let palindrome = @regexp.compile("^(.)(.)\\2\\1")
  inspect(
    palindrome.execute("abba").results(),
    content=
      #|[Some("abba"), Some("a"), Some("b")]
    ,
  )
  
  // HTML tag matching
  let html_regex = @regexp.compile("<([a-zA-Z]+)[^>]*>(.*?)</\\1>")
  let result = html_regex.execute("<div class='test'>content</div>")
  inspect(
    result.group(1),
    content=
      #|Some("div")
    ,
  )
  inspect(
    result.group(2),
    content=
      #|Some("content")
    ,
  )
}
```

## 💡 Real Examples

```moonbit
test "character classes" {
  // Email validation (simplified)
  let email = @regexp.compile(
    #|[\w-]+@[\w-]+\.\w+
    ,
  )
  let email_result = email.execute("user@example.com").results().collect()
  assert_eq(email_result, ["user@example.com"])
  // Extract numbers
  let numbers = @regexp.compile(
    #|\d+\.\d{2}
    ,
  )
  let result = numbers.execute("Price: $42.99").results().collect()
  assert_eq(result, ["42.99"])

  // Named captures for parsing
  let parser = @regexp.compile(
    #|(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})
    ,
  )
  let date_result = parser.execute("2024-03-15")
  assert_eq(date_result.group_by_name("year"), Some("2024"))
  assert_eq(date_result.group_by_name("month"), Some("03"))
  assert_eq(date_result.group_by_name("day"), Some("15"))
}
```

## 🚨 Error Handling

```moonbit
try {
  @regexp.compile("a(b")  // Oops! Missing )
} catch {
  Error_(MissingParenthesis, _) => println("Fix your regex! 🔧")
}
```

## ⚡ Performance Characteristics

- **Linear time** — No catastrophic backtracking (except backreferences), O(nm) complexity
- **VM-based** — Predictable memory usage
- **Unicode ready** — Full character set and property support

Built for speed, reliability, and developer happiness! 🚀

## 🔍 Implementation Notes

### Behavior Differences from Other Engines

This implementation has some behavior differences compared to other popular regex engines:

1. **Empty Character Class Handling**:
   - In JavaScript: `[][]` is parsed as two character classes with no characters
   - In Golang: `[][]` is parsed as one character class containing `]` and `[`
   - In MoonBit: we follow the JavaScript interpretation

2. **Empty Alternatives Behavior**:
   - Expressions like `(|a)*` and `(|a)+` follow the Golang interpretation
   - See [Golang issue #46123](https://github.com/golang/go/issues/46123) for details

# 🔍 regexp.mbt

> ⚠️ **WARNING: WORK IN PROGRESS**  
> This library is still under active development and may undergo breaking changes.  
> Use with caution as functionality might be incomplete or unstable.

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

## ⚡ Why It's Fast

- **Linear time** — No catastrophic backtracking
- **VM-based** — Predictable memory usage
- **Unicode ready** — Full character set support

Built for speed, reliability, and developer happiness! 🚀

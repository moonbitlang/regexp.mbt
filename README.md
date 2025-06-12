# 🔍 regexp.mbt

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

<!-- We don't have \w or \d yet

## 💡 Real Examples

```moonbit
// Email validation (simplified)
let email = @regexp.compile(r"[\w.-]+@[\w.-]+\.\w+")

// Extract numbers
let numbers = @regexp.compile(r"\d+")
let result = numbers.execute("Price: $42.99")

// Named captures for parsing
let parser = @regexp.compile(r"(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})")
let date_result = parser.execute("2024-03-15")
```

-->

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

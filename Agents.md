# Agents.md - AI Assistant Guide for regexp.mbt

This document provides guidance for AI assistants working on the `regexp.mbt` project - a regular expression library for the MoonBit programming language.

## Project Overview

This is a **regular expression library for MoonBit** inspired by [Russ Cox's regex series](https://swtch.com/~rsc/regexp/regexp1.html). The library implements linear-time regex matching using a VM-based approach to avoid catastrophic backtracking.

### Key Features
- Linear time complexity (no catastrophic backtracking)
- VM-based execution engine
- Unicode support
- Named capture groups
- MoonBit-native implementation

## Development Workflow

### Essential Commands

Before making any changes, always run these commands to ensure project health:

```bash
# Check project for compilation errors and type issues
moon check

# Run all tests
moon test

# When adding/modifying tests with `inspect()`, update expected outputs
moon test --update

# Update interface files (*.mbti) to reflect public API changes
moon info
```

### Testing Guidelines

**CRITICAL**: When writing tests, follow these MoonBit-specific conventions:

✅ **DO USE**:
```moonbit
test "my_feature" {
  let result = some_function()
  inspect(result)  // This will generate expected output
}
```

❌ **DO NOT USE**:
```moonbit
// Avoid these patterns:
assert_eq(a, b)
assert_true(condition) 
inspect(a == b)
```

**Testing Workflow**:
1. Write tests using `inspect(value)` for expected outputs
2. Run `moon test --update` to generate/update expected results
3. **Always review the generated changes** to ensure correctness
4. Commit both test code and updated snapshots

## Project Structure

```
src/
├── top.mbt           # Main public API
├── compile.mbt       # Regex compilation logic
├── parse.mbt         # Pattern parsing
├── impl.mbt          # Core implementation
├── chars.mbt         # Character handling
├── regex_test.mbt    # Main test suite
├── todo_test.mbt     # TODO/future feature tests
├── regexp.mbti       # Public interface file (auto-generated)
└── internal/
    └── unicode/      # Unicode support modules
        ├── *.mbt     # Implementation files
        └── unicode.mbti  # Unicode module interface
```

**Important**: `.mbti` files are **interface files** that define what's publicly visible to other modules. These are auto-generated and should be updated using `moon info` after making API changes.

## Core Components

### 1. Regex Engine (`Engine`)
- Created via `compile(pattern)` 
- Executes pattern matching against text
- Maintains compiled VM instructions

### 2. Match Results (`MatchResult`)
- Returned by `engine.execute(text)`
- Provides access to capture groups
- Supports both indexed and named group access

### 3. Pattern Syntax
The library supports standard regex features:
- Literals, wildcards (`.`)
- Quantifiers (`+`, `*`, `?`, `{n,m}`)
- Character classes (`[a-z]`, `[^0-9]`)
- Groups (capturing `()`, non-capturing `(?:)`, named `(?<name>)`)
- Alternation (`|`)
- Anchors (`^`, `$`)

## Development Guidelines

### Adding New Features

1. **API Design**: Follow existing patterns in `top.mbt`
2. **Implementation**: Core logic typically goes in `impl.mbt` or `compile.mbt`
3. **Interface Updates**: Run `moon info` to update `.mbti` files after API changes
4. **Testing**: Add comprehensive tests with various edge cases
5. **Documentation**: Update README.md with new syntax/features

### Bug Fixes

1. **Reproduce**: Create a failing test case first
2. **Fix**: Implement the minimal necessary change
3. **Verify**: Ensure fix doesn't break existing functionality
4. **Test**: Add regression tests

### Refactoring

1. **Preserve API**: Maintain backward compatibility in public interfaces
2. **Test Coverage**: Ensure all existing tests still pass
3. **Performance**: Maintain linear time complexity guarantees

## Common Patterns

### Error Handling
```moonbit
// Compilation errors
Error_(MissingParenthesis, position)
Error_(InvalidCharacterClass, position)
// Handle gracefully with descriptive messages
```

### Unicode Support
```moonbit
// Use internal/unicode modules for character classification
// Support full Unicode character sets and properties
```

### VM Instructions
```moonbit
// The engine compiles to VM instructions for execution
// Instructions should maintain linear time guarantees
```

## Code Style

- Use descriptive function and variable names
- Prefer pattern matching over conditional chains
- Document complex algorithms with comments
- Keep functions focused and modular
- Follow MoonBit naming conventions

## Performance Considerations

- **Linear Time**: All regex operations must complete in O(n) time
- **Memory**: Avoid exponential memory usage patterns
- **Unicode**: Efficient character classification and case folding
- **Compilation**: Cache compiled patterns when possible

## When Working on This Project

1. **Understand the Goal**: Linear-time regex without backtracking
2. **Check Existing Code**: Study current implementation patterns
3. **Test Thoroughly**: Use `inspect()` and `moon test --update`
4. **Update Interfaces**: Run `moon info` after public API changes
5. **Review Changes**: Always verify generated test outputs and interface files
6. **Maintain Performance**: Preserve linear time guarantees

## Resources

- [Russ Cox's Regex Articles](https://swtch.com/~rsc/regexp/) - Theoretical foundation
- MoonBit Language Documentation
- Unicode Standard for character handling

---

**Remember**: This library prioritizes correctness, performance, and reliability. When in doubt, favor explicit, well-tested implementations over clever optimizations.

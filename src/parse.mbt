// Copyright 2025 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// 正则表达式解析器 - 使用递归下降解析算法
/// 
/// 本解析器实现了一个简化的正则表达式语法，使用 ABNF (Augmented Backus-Naur Form) 描述如下：
/// 
/// ```abnf
/// ; 正则表达式语法 ABNF 规范
/// regex       = expression
/// expression  = sequence *( "|" sequence )           ; 选择：a|b|c
/// sequence    = *term                                ; 序列：abc
/// term        = factor [quantifier]                  ; 带量词的项：a*, b+, c?
/// factor      = char / group / char-class / escape / dot / assertion   ; 基本元素
/// 
/// ; 量词
/// quantifier  = "*" / "+" / "?" / repeat
/// repeat      = "{" number "}" / "{" number "," "}" / "{" number "," number "}"
/// 
/// ; 分组
/// group       = "(" expression ")"                   ; 捕获组：(abc)
///             / "(?<" group-name ">" expression ")"  ; 命名捕获组：(?<name>abc)
/// 
/// ; 字符类
/// char-class  = "[" *char-class-item "]"            ; 字符类：[abc], [a-z]
/// char-class-item = escape / char-range / normal-char
/// char-range  = char-class-char "-" char-class-char  ; 字符范围：a-z, 0-9
/// char-class-char = escape / normal-char             ; 字符类中的字符（任何字符或转义字符）
/// 
/// ; 转义序列
/// escape      = "\" any-char                         ; 转义字符：\n, \*, \\
/// 
/// ; 断言
/// assertion   = "^" / "$"                            ; 断言：^（行首），$（行尾）
/// 
/// ; 任意字符
/// dot         = "."                                  ; 匹配任意字符
/// 
/// ; 普通字符
/// char        = normal-char
/// normal-char = <any character except special chars>
/// special-chars = "*" / "+" / "?" / "|" / "(" / ")" / "[" / "]" / "{" / "}" / "\" / "." / "^" / "$"
/// ```
/// 
/// 解析优先级（从高到低）：
/// 1. 因子 (factor): 字符、分组、字符类、转义、断言
/// 2. 量词 (quantifier): *, +, ?  
/// 3. 连接 (sequence): 隐式连接
/// 4. 选择 (alternation): |
/// 
/// 示例：
/// - `abc`     -> 序列：字符a、字符b、字符c
/// - `a|b`     -> 选择：字符a 或 字符b
/// - `a*`      -> 量词：字符a重复0次或多次
/// - `(a|b)*`  -> 分组加量词：(字符a或字符b)重复0次或多次
/// - `[abc]`   -> 字符类：字符a、b或c中的任意一个
/// - `^abc$`   -> 断言：行首、字符abc、行尾

///|
priv struct Parser {
  mut input : @string.View
}

///| 正则表达式解析错误类型
/// 
/// 定义了解析过程中可能遇到的各种错误情况
pub enum Err {
  InternalError // 内部错误
  InvalidCharClass // 无效的字符类
  InvalidEscape // 无效的转义序列
  InvalidNamedCapture // 无效的命名捕获组
  InvalidRepeatOp // 无效的重复操作符
  InvalidRepeatSize // 无效的重复次数
  MissingBracket // 缺少右方括号 ]
  MissingParenthesis // 缺少右括号 )
  MissingRepeatArgument // 缺少重复参数
  TrailingBackslash // 末尾的反斜杠
  UnexpectedParenthesis // 意外的括号
} derive(Show)

///| 解析错误异常类型
/// 
/// 包含错误信息和相关的字符串视图上下文
pub suberror Error_ {
  Error_(err~ : Err, data~ : @string.View)
} derive(Show)

///| 创建正则表达式解析器
/// 
/// 参数:
/// - `input`: 要解析的正则表达式字符串视图
/// 
/// 返回: 新的解析器实例
fn Parser::new(input : @string.View) -> Parser {
  Parser::{ input, }
}

///| 解析正则表达式的入口函数
/// 
/// 根据 ABNF 规则：`regex = expression`
/// 
/// 参数:
/// - `regex`: 正则表达式字符串
/// 
/// 返回: 解析后的 Regex AST
/// 
/// 抛出: Error_ 当解析失败时
fn parse(regex : @string.View) -> Regex raise Error_ {
  let parser = Parser::new(regex)
  let result = parser.parse_expression()

  // 检查是否有剩余的输入，特别是未匹配的右括号
  if parser.input is [')', ..] {
    raise Error_(err=UnexpectedParenthesis, data=parser.input)
  }
  result
}

///| 解析表达式 (Expression)
/// 
/// 根据 ABNF 规则：`expression = sequence *( "|" sequence )`
/// 
/// 表达式是正则表达式的顶层结构，由一个或多个用 `|` 分隔的序列组成。
/// 这表示选择 (alternation) 操作，匹配任意一个序列即可。
/// 
/// 示例：
/// - `a`       -> 单个序列
/// - `a|b`     -> 两个序列的选择：匹配a或b
/// - `abc|def` -> 两个序列的选择：匹配abc或def
/// - `a|b|c`   -> 多个序列的选择：匹配a、b或c
/// 
/// 返回: 解析后的 Regex AST
fn Parser::parse_expression(self : Parser) -> Regex raise Error_ {
  let mut left = self.parse_sequence()
  while self.input is ['|', .. rest] {
    self.input = rest // 消费 '|'
    let right = self.parse_sequence()
    left = Alternate(left, right)
  }
  left
}

///| 解析序列 (Sequence)
/// 
/// 根据 ABNF 规则：`sequence = *term`
/// 
/// 序列是由连续的项 (term) 组成，表示隐式的连接操作。
/// 每个项必须按顺序匹配才能使整个序列匹配成功。
/// 
/// 示例：
/// - `abc`     -> 三个项的序列：字符a、字符b、字符c
/// - `a*b+`    -> 两个项的序列：量词a*、量词b+
/// - `(ab)c`   -> 两个项的序列：分组(ab)、字符c
/// - ``        -> 空序列（合法）
/// 
/// 解析终止条件：
/// - 遇到 `|` 字符（选择操作符）
/// - 遇到 `)` 字符（分组结束）
/// - 输入结束
/// 
/// 返回: 解析后的 Regex AST
fn Parser::parse_sequence(self : Parser) -> Regex raise Error_ {
  let sequence = []
  while self.input is [ch, ..] && ch != '|' && ch != ')' {
    let term = self.parse_term()
    sequence.push(term)
  }
  match sequence {
    // 空序列被认为是合法的正则表达式（与 Go 的行为一致）
    [] => Empty
    [regex] => regex
    _ => Concat(sequence)
  }
}

///| 解析项 (Term)
/// 
/// 根据 ABNF 规则：`term = factor [quantifier]`
/// 
/// 项是由一个因子 (factor) 加上可选的量词组成。
/// 因子是最基本的正则表达式单元，量词修饰因子的重复次数。
/// 
/// 支持的量词：
/// - `*`: 零次或多次重复 (ZeroOrMore)
/// - `+`: 一次或多次重复 (OneOrMore)  
/// - `?`: 零次或一次重复 (ZeroOrOne)
/// - `{n}`: 恰好n次重复
/// - `{n,}`: 至少n次重复
/// - `{n,m}`: n到m次重复
/// 
/// 示例：
/// - `a`      -> 基本因子：字符a
/// - `a*`     -> 量词项：字符a重复0次或多次
/// - `a+`     -> 量词项：字符a重复1次或多次
/// - `a?`     -> 量词项：字符a重复0次或1次
/// - `a{3}`   -> 量词项：字符a重复恰好3次
/// - `a{2,}`  -> 量词项：字符a重复至少2次
/// - `a{2,5}` -> 量词项：字符a重复2到5次
/// - `(ab)*`  -> 量词项：分组(ab)重复0次或多次
/// 
/// 返回: 解析后的 Regex AST
fn Parser::parse_term(self : Parser) -> Regex raise Error_ {
  let mut base = self.parse_factor()

  // 处理量词
  match self.input {
    ['*', .. rest] =>
      if rest is ['?', .. rest] {
        // 处理懒惰量词 '*?'
        self.input = rest // 消费 '*?'
        base = ZeroOrMore(base, greedy=false)
      } else {
        // 处理贪婪量词 '*'
        self.input = rest // 消费 '*'
        base = ZeroOrMore(base, greedy=true)
      }
    ['+', .. rest] =>
      if rest is ['?', .. rest] {
        // 处理懒惰量词 '+?'
        self.input = rest // 消费 '+?'
        base = OneOrMore(base, greedy=false)
      } else {
        // 处理贪婪量词 '+'
        self.input = rest // 消费 '+'
        base = OneOrMore(base, greedy=true)
      }
    ['?', .. rest] =>
      if rest is ['?', .. rest] {
        // 处理懒惰量词 '??'
        self.input = rest // 消费 '??'
        base = ZeroOrOne(base, greedy=false)
      } else {
        // 处理贪婪量词 '?'
        self.input = rest // 消费 '?'
        base = ZeroOrOne(base, greedy=true)
      }
    ['{', ..rest] => {
      self.input = rest
      // 处理重复量词 {n}, {n,}, {n,m}
      let repeat_result = self.parse_repeat()
      let greedy = match self.input {
        ['?', .. rest] => {
          self.input = rest // 消费 '?'
          false
        }
        _ => true
      }
      base = Repeat(base, greedy~, min=repeat_result.0, max=repeat_result.1)
    }
    _ => ()
  }
  base
}

///| 解析因子 (Factor)
/// 
/// 根据 ABNF 规则：`factor = char / group / char-class / escape / dot / assertion`
/// 
/// 因子是正则表达式的最小单元，可以是：
/// - 分组：`(expression)` - 用括号包围的子表达式
/// - 字符类：`[abc]` - 匹配指定字符集合中的任意一个字符
/// - 任意字符：`.` - 匹配任意一个字符
/// - 断言：`^` - 行首断言，`$` - 行尾断言
/// - 转义字符：`\c` - 转义后的字符，如 `\*`、`\\`
/// - 普通字符：除特殊字符外的任意字符
/// 
/// 特殊字符需要转义才能作为字面量使用：
/// `*` `+` `?` `|` `(` `)` `[` `]` `{` `}` `\` `.` `^` `$`
/// 
/// 示例：
/// - `a`       -> 字符：匹配字符'a'
/// - `(abc)`   -> 分组：捕获组，匹配序列'abc'
/// - `[abc]`   -> 字符类：匹配'a'、'b'或'c'
/// - `\.`      -> 转义字符：匹配字面量'.'
/// - `.`       -> 任意字符：匹配任何字符
/// - `^`       -> 断言：行首断言
/// - `$`       -> 断言：行尾断言
/// 
/// 返回: 解析后的 Regex AST
/// 
/// 抛出: Error_ 当遇到无效语法时
fn Parser::parse_factor(self : Parser) -> Regex raise Error_ {
  match self.input {
    ['(', .. rest] => {
      self.input = rest // 消费 '('
      // 检查是否是捕获组
      if self.input is ['?', ':', .. rest] {
        self.input = rest // 消费 '?:'
        // 非捕获组 (?:...)
        let expr = self.parse_expression()
        guard self.input is [')', .. rest] else {
          raise Error_(err=MissingParenthesis, data=self.input)
        }
        self.input = rest // 消费 ')'
        expr
      } else {
        // 检查是否是命名捕获组 (?<name>...)
        let name = if self.input is ['?', '<', .. rest] {
          self.input = rest // 消费 '?<'
          let name = self.parse_group_name()
          guard self.input is ['>', .. rest] else {
            raise Error_(err=InvalidNamedCapture, data=self.input)
          }
          self.input = rest // 消费 '>'
          Some(name)
        } else {
          None
        }
        // 普通捕获组
        let expr = self.parse_expression()
        guard self.input is [')', .. rest] else {
          raise Error_(err=MissingParenthesis, data=self.input)
        }
        self.input = rest // 消费 ')'
        Capture(expr, name~)
      }
    }
    ['[', .. rest] => {
      self.input = rest
      self.parse_char_class()
    }
    ['.', .. rest] => {
      self.input = rest // 消费 '.'
      CharClass(['\u{0}', '\u{10FFFF}'], neg=false)
    }
    ['^', .. rest] => {
      self.input = rest // 消费 '^'
      Assertion(BeginLine)
    }
    ['$', .. rest] => {
      self.input = rest // 消费 '$'
      Assertion(EndLine)
    }
    ['\\', .. rest] => {
      self.input = rest // 消费 '\'
      guard self.input is [c, .. rest] else {
        raise Error_(err=TrailingBackslash, data=self.input)
      }
      self.input = rest
      match c {
        'd' => CharClass(['0', '9'], neg=false) // 数字字符类
        'D' => CharClass(['0', '9'], neg=true) // 非数字字符类
        'w' => CharClass(['a', 'z', 'A', 'Z', '0', '9', '_', '_'], neg=false) // 单词字符类
        'W' => CharClass(['a', 'z', 'A', 'Z', '0', '9', '_', '_'], neg=true) // 非单词字符类
        _ => CharClass([c, c], neg=false)
      }
    }
    [c, ..] if Parser::is_special_char(c) =>
      raise Error_(err=InvalidEscape, data=self.input)
    [c, .. rest] => {
      self.input = rest
      CharClass([c, c], neg=false)
    }
    "" => raise Error_(err=InternalError, data=self.input)
  }
}

///| 解析字符类 (Character Class)
/// 
/// 根据 ABNF 规则：`char-class = "[" *char-class-item "]"`
/// 
/// 字符类是用方括号包围的字符集合，匹配其中任意一个字符。
/// 支持转义字符和字符范围语法。
/// 
/// 示例：
/// - `[abc]`   -> 匹配字符 'a'、'b' 或 'c'
/// - `[a-z]`   -> 字符范围：匹配 'a' 到 'z' 之间的任意字符
/// - `[a-zA-Z]` -> 多个范围：匹配 'a' 到 'z' 或 'A' 到 'Z' 之间的任意字符
/// - `[a-\]]`  -> 字符范围：匹配 'a' 到 ']' 之间的任意字符
/// - `[\[\]]`  -> 转义的方括号字符
/// - `[\\]`    -> 转义的反斜杠字符
/// 
/// 字符类项 (char-class-item) 可以是：
/// - 字符范围：`a-z` - 从字符 'a' 到 字符 'z' 的范围
/// - 转义字符：`\c` - 任何被反斜杠转义的字符（包括 `\]`）
/// - 普通字符：任何非特殊字符
/// 
/// 输入：假设已经消费了左方括号 `[`
/// 
/// 返回: CharClass(chars) - 包含字符范围列表的字符类 AST
/// 
/// 抛出: Error_ 当字符类格式错误时
fn Parser::parse_char_class(self : Parser) -> Regex raise Error_ {
  let neg = if self.input is ['^', .. rest] {
    self.input = rest // 消费 '^'
    true
  } else {
    false
  }
  let chars = []
  while self.input is [ch, .. rest] && ch != ']' {
    let start_char = match ch {
      '\\' => {
        guard rest is [ch, .. rest] else {
          raise Error_(err=TrailingBackslash, data=self.input)
        }
        self.input = rest
        match ch {
          'd' => {
            ['0', '9'].each(chars.push(_)) // 数字字符类
            continue
          }
          'D' => {
            ['\u{0}', '/', ':', '\u{10FFFF}'].each(chars.push(_)) // 非数字字符类
            continue
          }
          'w' => {
            ['a', 'z', 'A', 'Z', '0', '9', '_', '_'].each(chars.push(_)) // 单词字符类
            continue
          }
          'W' => {
            ['\u{0}', '/', ':', '@', '[', '^', '`', '`', '{', '\u{10FFFF}'].each(
              chars.push(_),
            ) // 非单词字符类
            continue
          }
          _ => ch
        }
      }
      _ => {
        self.input = rest
        ch
      }
    }

    // 检查是否是字符范围 (如 a-z)
    if self.input is ['-', .. rest] {
      // 查看 '-' 后面的字符，确保不是 ']' 且有更多字符
      let input_copy = self.input
      self.input = rest // 消费 '-'
      if self.input is [ch, .. rest] && ch != ']' {
        // 解析范围的结束字符
        let end_char = match ch {
          '\\' => {
            guard rest is [ch, .. rest] else {
              raise Error_(err=TrailingBackslash, data=self.input)
            }
            self.input = rest
            ch
          }
          _ => {
            self.input = rest
            ch
          }
        }

        // 检查范围的结束字符是否有效
        if end_char < start_char {
          raise Error_(err=InvalidCharClass, data=self.input)
        }

        // 添加范围：起始字符和结束字符
        chars.push(start_char)
        chars.push(end_char)
      } else {
        // '-' 后面是 ']' 或已到达输入末尾，说明 '-' 是字面量字符，不是范围操作符
        self.input = input_copy // 恢复输入状态
        chars.push(start_char)
        chars.push(start_char)
      }
    } else {
      // 普通字符，不是范围，表示为单字符范围
      chars.push(start_char)
      chars.push(start_char)
    }
  }
  guard self.input is [']', .. rest] else {
    raise Error_(err=MissingBracket, data=self.input)
  }
  self.input = rest // 消费 ']'
  CharClass(chars, neg~)
}

///| 检查字符是否为正则表达式特殊字符
/// 
/// 特殊字符需要转义才能作为字面量字符使用
/// 
/// 参数:
/// - `c`: 要检查的字符
/// 
/// 返回: 如果是特殊字符则返回 true
fn Parser::is_special_char(c : Char) -> Bool {
  c
  is ('*'
  | '+'
  | '?'
  | '|'
  | '('
  | ')'
  | '['
  | ']'
  | '{'
  | '}'
  | '.'
  | '^'
  | '$')
}

///| 解析重复量词 (Repeat Quantifier)
/// 
/// 根据 ABNF 规则：`repeat = "{" number "}" / "{" number "," "}" / "{" number "," number "}"`
/// 
/// 重复量词指定了前面的元素应该重复的次数：
/// - `{n}`: 恰好重复 n 次
/// - `{n,}`: 至少重复 n 次
/// - `{n,m}`: 重复 n 到 m 次（包含边界）
/// 
/// 示例：
/// - `a{3}` -> 字符 'a' 恰好重复 3 次
/// - `b{2,}` -> 字符 'b' 至少重复 2 次
/// - `c{1,5}` -> 字符 'c' 重复 1 到 5 次
/// 
/// 输入：假设已经消费了左大括号 `{`
/// 
/// 返回: (min, max) 元组，其中：
/// - min: 最小重复次数
/// - max: 最大重复次数（None 表示无限制）
/// 
/// 抛出: Error_ 当重复量词格式错误时
fn Parser::parse_repeat(self : Parser) -> (UInt, UInt?) raise Error_ {

  // 解析第一个数字（最小重复次数）
  let min = self.parse_number()
  match self.input {
    ['}', .. rest] => {
      // {n} 格式：恰好重复 n 次
      self.input = rest
      (min, Some(min))
    }
    [',', .. rest] => {
      self.input = rest // 消费 ','
      match self.input {
        ['}', .. rest] => {
          // {n,} 格式：至少重复 n 次
          self.input = rest
          (min, None)
        }
        _ => {
          // {n,m} 格式：重复 n 到 m 次
          let max = self.parse_number()
          guard self.input is ['}', .. rest] else {
            raise Error_(err=InvalidRepeatOp, data=self.input)
          }
          self.input = rest // 消费 '}'

          // 验证范围的有效性
          if max < min {
            raise Error_(err=InvalidRepeatSize, data=self.input)
          }
          (min, Some(max))
        }
      }
    }
    _ => raise Error_(err=InvalidRepeatOp, data=self.input)
  }
}

///| 解析数字
/// 
/// 从当前输入位置解析一个十进制数字序列。
/// 数字必须至少包含一位数字字符。
/// 
/// 示例：
/// - `123` -> 123
/// - `0` -> 0
/// - `42` -> 42
/// 
/// 返回: 解析得到的整数值
/// 
/// 抛出: Error_ 当没有找到有效数字时
fn Parser::parse_number(self : Parser) -> UInt raise Error_ {
  let mut result = 0U
  let mut has_digits = false
  while self.input is [ch, .. rest] && ch >= '0' && ch <= '9' {
    has_digits = true
    result = result * 10U + (ch.to_int() - '0'.to_int()).reinterpret_as_uint()
    self.input = rest
  }
  if not(has_digits) {
    raise Error_(err=MissingRepeatArgument, data=self.input)
  }
  result
}

///| 解析命名捕获组的组名
/// 
/// 组名必须是有效的标识符，只能包含字母、数字和下划线，且必须以字母或下划线开头。
/// 
/// 示例：
/// - `name`     -> 有效的组名
/// - `group1`   -> 有效的组名
/// - `_test`    -> 有效的组名
/// - `1invalid` -> 无效的组名（以数字开头）
/// 
/// 返回: 解析得到的组名字符串
/// 
/// 抛出: Error_ 当组名格式错误时
fn Parser::parse_group_name(self : Parser) -> String raise Error_ {
  let mut name = ""
  let mut first = true
  while self.input is [ch, .. rest] && ch != '>' {
    if first {
      // 第一个字符必须是字母或下划线
      if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_' {
        name += ch.to_string()
        self.input = rest
        first = false
      } else {
        raise Error_(err=InvalidNamedCapture, data=self.input)
      }
    } else if (
      // 后续字符可以是字母、数字或下划线
        ch >= 'a' && ch <= 'z'
      ) ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '_' {
      name += ch.to_string()
      self.input = rest
    } else {
      raise Error_(err=InvalidNamedCapture, data=self.input)
    }
  }

  // 检查组名是否为空
  if name == "" {
    raise Error_(err=InvalidNamedCapture, data=self.input)
  }
  name
}

///| 测试示例：解析带有捕获组和量词的复杂正则表达式
/// 
/// 测试正则表达式 "a(b|c)*d":
/// - 字符 'a'
/// - 捕获组 (b|c) 重复0次或多次
/// - 字符 'd'
/// 
/// 预期匹配字符串 "abbd":
/// - 完整匹配范围: [0, 4]
/// - 第一个捕获组最后匹配: [2, 3] (字符 'b')
test "parse complex regex with capture group and quantifier" {
  let regex = parse("a(b|c)*d")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abbd", capture_count)
  inspect(result, content="[0, 4, 2, 3]")
}

///| 测试示例：解析多分支选择表达式
/// 
/// 测试正则表达式 "abc|def|ghi":
/// - 三个选择分支: "abc", "def", "ghi"
/// - 匹配其中任意一个即可
/// 
/// 预期匹配字符串 "abcdefghi" 中的第一个分支 "abc":
/// - 匹配范围: [0, 3]
test "parse multi-branch alternation expression" {
  let regex = parse("abc|def|ghi")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abcdefghi", capture_count)
  inspect(result, content="[0, 3]")
}

///| 测试示例：解析点字符（任意字符匹配）
/// 
/// 测试正则表达式 "a.c":
/// - 字符 'a'
/// - 任意字符 '.'
/// - 字符 'c'
/// 
/// 预期匹配字符串 "abc", "axc", "a1c" 等:
/// - 匹配范围: [0, 3]
test "parse dot character (any character match)" {
  let regex = parse("a.c")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "axc", capture_count)
  inspect(result, content="[0, 3]")
  let result = vm(instructions, "a1c", capture_count)
  inspect(result, content="[0, 3]")
}

///| 测试示例：解析字符类范围语法
/// 
/// 测试正则表达式 "[a-z]":
/// - 字符范围：匹配 'a' 到 'z' 之间的任意字符
/// 
/// 预期匹配字符串 "hello" 中的第一个字符 'h':
/// - 匹配范围: [0, 1]
test "parse character class range syntax" {
  let regex = parse("[a-z]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "hello", capture_count)
  inspect(result, content="[0, 1]")
}

///| 测试示例：解析多个字符类范围
/// 
/// 测试正则表达式 "[a-zA-Z]":
/// - 两个字符范围：'a' 到 'z' 和 'A' 到 'Z'
/// - 匹配任意英文字母
/// 
/// 预期匹配字符串 "Hello123" 中的第一个字符 'H':
/// - 匹配范围: [0, 1]
test "parse multiple character class ranges" {
  let regex = parse("[a-zA-Z]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "Hello123", capture_count)
  inspect(result, content="[0, 1]")
}

///| 测试示例：解析混合字符类（范围和单个字符）
/// 
/// 测试正则表达式 "[a-z0-9_]":
/// - 字符范围：'a' 到 'z'
/// - 字符范围：'0' 到 '9'  
/// - 单个字符：'_'
/// 
/// 预期匹配字符串 "_test123" 中的第一个字符 '_':
/// - 匹配范围: [0, 1]
test "parse mixed character class (ranges and individual characters)" {
  let regex = parse("[a-z0-9_]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "_test123", capture_count)
  inspect(result, content="[0, 1]")
}

///| 测试示例：解析字符类中的字面量连字符
/// 
/// 测试正则表达式 "[abc-]":
/// - 单个字符：'a', 'b', 'c'
/// - 字面量连字符：'-'（位于末尾，不构成范围）
/// 
/// 预期匹配字符串 "-" 中的连字符:
/// - 匹配范围: [0, 1]
test "parse literal hyphen in character class" {
  let regex = parse("[abc-]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "-", capture_count)
  inspect(result, content="[0, 1]")
}

///| 测试示例：解析带转义字符的字符类范围
/// 
/// 测试正则表达式 "[\]-a]":
/// - 使用转义字符 '\]' 来包含右方括号
/// - 字符范围：从 ']' 到 'a'
/// 
/// 预期匹配字符串 "]" 中的 ']' 字符:
/// - 匹配范围: [0, 1]
test "parse character class range with escaped characters" {
  let regex = parse("[\\]-a]")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "]", capture_count)
  inspect(result, content="[0, 1]")

  // 测试无效情况：结束字符小于起始字符
  let regex = try? parse("[a-\\]]")
  inspect(
    regex,
    content=
      #|Err(Error_(err=InvalidCharClass, data="]"))
    ,
  )
}

///| 测试示例：解析重复量词 {n}
/// 
/// 测试正则表达式 "a{3}":
/// - 字符 'a' 恰好重复 3 次
/// 
/// 预期匹配字符串 "aaa":
/// - 匹配范围: [0, 3]
test "parse exact repeat quantifier {n}" {
  let regex = parse("a{3}")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "aaa", capture_count)
  inspect(result, content="[0, 3]")

  // 不匹配少于3个a的情况
  let result = vm(instructions, "aa", capture_count)
  inspect(result, content="[]")

  // 匹配多于3个a的情况（只匹配前3个）
  let result = vm(instructions, "aaaa", capture_count)
  inspect(result, content="[0, 3]")
}

///| 测试示例：解析重复量词 {n,}
/// 
/// 测试正则表达式 "b{2,}":
/// - 字符 'b' 重复至少 2 次
/// 
/// 预期匹配字符串 "bb", "bbb", "bbbb":
/// - 匹配范围: [0, 字符串长度]
test "parse minimum repeat quantifier {n,}" {
  let regex = parse("b{2,}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 匹配恰好2个b
  let result = vm(instructions, "bb", capture_count)
  inspect(result, content="[0, 2]")

  // 匹配3个b
  let result = vm(instructions, "bbb", capture_count)
  inspect(result, content="[0, 3]")

  // 不匹配少于2个b的情况
  let result = vm(instructions, "b", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：解析重复量词 {n,m}
/// 
/// 测试正则表达式 "c{2,4}":
/// - 字符 'c' 重复 2 到 4 次
/// 
/// 预期匹配字符串 "cc", "ccc", "cccc":
/// - 匹配范围: [0, 实际匹配长度]
test "parse range repeat quantifier {n,m}" {
  let regex = parse("c{2,4}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 匹配2个c
  let result = vm(instructions, "cc", capture_count)
  inspect(result, content="[0, 2]")

  // 匹配3个c
  let result = vm(instructions, "ccc", capture_count)
  inspect(result, content="[0, 3]")

  // 匹配4个c
  let result = vm(instructions, "cccc", capture_count)
  inspect(result, content="[0, 4]")

  // 匹配超过4个c的情况（只匹配前4个）
  let result = vm(instructions, "ccccc", capture_count)
  inspect(result, content="[0, 4]")

  // 不匹配少于2个c的情况
  let result = vm(instructions, "c", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：解析懒惰重复量词 {n,}?
/// 
/// 测试正则表达式 "d{2,}?":
/// - 字符 'd' 重复至少 2 次，懒惰模式
/// 
/// 懒惰模式会匹配尽可能少的字符
test "parse lazy minimum repeat quantifier {n,}?" {
  let regex = parse("d{2,}?")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 懒惰模式匹配最少的字符数
  let result = vm(instructions, "ddd", capture_count)
  inspect(result, content="[0, 2]")
}

///| 测试示例：解析复杂的重复量词表达式
/// 
/// 测试正则表达式 "a{2}b{1,3}c{2,}":
/// - 字符 'a' 恰好 2 次
/// - 字符 'b' 1 到 3 次
/// - 字符 'c' 至少 2 次
test "parse complex repeat quantifier expression" {
  let regex = parse("a{2}b{1,3}c{2,}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 匹配 "aabccc"
  let result = vm(instructions, "aabccc", capture_count)
  inspect(result, content="[0, 6]")

  // 不匹配 "aabbbbcc"（b超过3个）
  let result = vm(instructions, "aabbbbcc", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：解析带分组的重复量词
/// 
/// 测试正则表达式 "(ab){2}":
/// - 分组 (ab) 恰好重复 2 次
test "parse repeat quantifier with groups" {
  let regex = parse("(ab){2}")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 匹配 "abab"
  let result = vm(instructions, "abab", capture_count)
  inspect(result, content="[0, 4, 2, 4]")
}

///| 测试示例：测试重复量词的错误情况
/// 
/// 测试各种无效的重复量词语法
test "parse repeat quantifier error cases" {
  // 测试 {m,n} 其中 m > n 的情况
  let regex = try? parse("a{5,2}")
  inspect(
    regex,
    content=
      #|Err(Error_(err=InvalidRepeatSize, data=""))
    ,
  )

  // 测试缺少数字的情况
  let regex = try? parse("a{}")
  inspect(regex, content="Err(Error_(err=MissingRepeatArgument, data=\"}\"))")

  // 测试缺少右括号的情况
  let regex = try? parse("a{2")
  inspect(regex, content="Err(Error_(err=InvalidRepeatOp, data=\"\"))")

  // 测试无效格式的情况
  let regex = try? parse("a{2,3,4}")
  inspect(regex, content="Err(Error_(err=InvalidRepeatOp, data=\",4}\"))")
}

///| 测试示例：解析非捕获组
/// 
/// 测试正则表达式 "(?:abc)":
/// - 非捕获组：匹配 "abc"，但不捕获
test "parse non-capturing group" {
  let regex = parse("(?:abc)")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")
}

///| 测试示例：解析命名捕获组
/// 
/// 测试正则表达式 "(?<name>abc)":
/// - 命名捕获组：名称为 "name"，匹配 "abc"
/// 
/// 预期匹配字符串 "abc":
/// - 匹配范围: [0, 3, 0, 3] (整体匹配和命名组匹配)
test "parse named capture group" {
  let regex = parse("(?<name>abc)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3, 0, 3]")

  // 验证命名组映射
  inspect(map.get("name"), content="Some(1)")
}

///| 测试示例：解析复杂的命名捕获组表达式
/// 
/// 测试正则表达式 "(?<first>a+)(?<second>b+)":
/// - 第一个命名捕获组：名称为 "first"，匹配一个或多个 'a'
/// - 第二个命名捕获组：名称为 "second"，匹配一个或多个 'b'
/// 
/// 预期匹配字符串 "aaabbb":
/// - 匹配范围: [0, 6, 0, 3, 3, 6]
test "parse complex named capture group expression" {
  let regex = parse("(?<first>a+)(?<second>b+)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "aaabbb", capture_count)
  inspect(result, content="[0, 6, 0, 3, 3, 6]")

  // 验证命名组映射
  inspect(map.get("first"), content="Some(1)")
  inspect(map.get("second"), content="Some(2)")
}

///| 测试示例：解析嵌套的命名捕获组
/// 
/// 测试正则表达式 "(?<outer>a(?<inner>bc)d)":
/// - 外层命名捕获组：名称为 "outer"
/// - 内层命名捕获组：名称为 "inner"
/// 
/// 预期匹配字符串 "abcd":
/// - 匹配范围: [0, 4, 0, 4, 1, 3]
test "parse nested named capture groups" {
  let regex = parse("(?<outer>a(?<inner>bc)d)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "abcd", capture_count)
  inspect(result, content="[0, 4, 0, 4, 1, 3]")

  // 验证命名组映射
  inspect(map.get("outer"), content="Some(1)")
  inspect(map.get("inner"), content="Some(2)")
}

///| 测试示例：混合使用命名捕获组和普通捕获组
/// 
/// 测试正则表达式 "(a)(?<named>b)(c)":
/// - 第一个普通捕获组：匹配 "a"
/// - 命名捕获组：名称为 "named"，匹配 "b"
/// - 第二个普通捕获组：匹配 "c"
/// 
/// 预期匹配字符串 "abc":
/// - 匹配范围: [0, 3, 0, 1, 1, 2, 2, 3]
test "parse mixed named and regular capture groups" {
  let regex = parse("(a)(?<named>b)(c)")
  let { instructions, capture: capture_count, map } = regex.compile()
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3, 0, 1, 1, 2, 2, 3]")

  // 验证命名组映射（第二个捕获组，索引为2）
  inspect(map.get("named"), content="Some(2)")
}

///| 测试示例：命名捕获组的错误情况
/// 
/// 测试各种无效的命名捕获组语法
test "parse named capture group error cases" {
  // 测试空组名
  let regex = try? parse("(?<>abc)")
  inspect(regex, content="Err(Error_(err=InvalidNamedCapture, data=\">abc)\"))")

  // 测试以数字开头的组名
  let regex = try? parse("(?<1invalid>abc)")
  inspect(
    regex,
    content="Err(Error_(err=InvalidNamedCapture, data=\"1invalid>abc)\"))",
  )

  // 测试包含非法字符的组名
  let regex = try? parse("(?<na-me>abc)")
  inspect(
    regex,
    content="Err(Error_(err=InvalidNamedCapture, data=\"-me>abc)\"))",
  )

  // 测试缺少右尖括号
  let regex = try? parse("(?<name abc)")
  inspect(regex, content="Err(Error_(err=InvalidNamedCapture, data=\" abc)\"))")

  // 测试缺少右括号
  let regex = try? parse("(?<name>abc")
  inspect(regex, content="Err(Error_(err=MissingParenthesis, data=\"\"))")
}

///| 测试示例：有效的组名格式
/// 
/// 测试各种有效的组名格式
test "parse valid group name formats" {
  // 以字母开头
  let regex = parse("(?<group>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("group"))
    ,
  )

  // 以下划线开头
  let regex = parse("(?<_group>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("_group"))
    ,
  )

  // 包含数字
  let regex = parse("(?<group1>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("group1"))
    ,
  )

  // 包含多个下划线
  let regex = parse("(?<my_group_1>abc)")
  inspect(
    (regex : Regex),
    content=
      #|Capture(Concat([CharClass(['a', 'a'], neg=false), CharClass(['b', 'b'], neg=false), CharClass(['c', 'c'], neg=false)]), name=Some("my_group_1"))
    ,
  )
}

///| 测试示例：解析行首断言 ^
/// 
/// 测试正则表达式 "^abc":
/// - 行首断言：^
/// - 字符序列：abc
/// 
/// 预期匹配以 "abc" 开头的行：
/// - 匹配 "abc" 本身: [0, 3]
/// - 匹配 "abc\ndef": [0, 3] (第一行)
/// - 匹配 "def\nabc": [4, 7] (第二行)
/// - 不匹配 "xabc": [] (不在行首)
test "parse line begin assertion ^" {
  let regex = parse("^abc")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配行首的情况
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")

  // 测试多行字符串中第一行匹配的情况
  let result = vm(instructions, "abc\ndef", capture_count)
  inspect(result, content="[0, 3]")
  // 测试多行字符串中第二行匹配的情况
  let result = vm(instructions, "def\nabc", capture_count)
  inspect(result, content="[4, 7]")

  // 测试不在行首的情况（应该不匹配）
  let result = vm(instructions, "xabc", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：解析行尾断言 $
/// 
/// 测试正则表达式 "abc$":
/// - 字符序列：abc
/// - 行尾断言：$
/// 
/// 预期匹配以 "abc" 结尾的行：
/// - 匹配 "abc" 本身: [0, 3]
/// - 匹配 "abc\ndef": [0, 3] (第一行)
/// - 匹配 "def\nabc": [4, 7] (第二行)
/// - 不匹配 "abcx": [] (不在行尾)
test "parse line end assertion $" {
  let regex = parse("abc$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配行尾的情况
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")

  // 测试多行字符串中第一行匹配的情况
  let result = vm(instructions, "abc\ndef", capture_count)
  inspect(result, content="[0, 3]")

  // 测试多行字符串中第二行匹配的情况
  let result = vm(instructions, "def\nabc", capture_count)
  inspect(result, content="[4, 7]")

  // 测试不在行尾的情况（应该不匹配）
  let result = vm(instructions, "abcx", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：解析行首和行尾断言组合 ^...$
/// 
/// 测试正则表达式 "^abc$":
/// - 行首断言：^
/// - 字符序列：abc
/// - 行尾断言：$
/// 
/// 预期匹配整行都是 "abc" 的情况：
/// - 匹配 "abc": [0, 3]
/// - 不匹配 "abcd": [] (行尾有额外字符)
/// - 不匹配 "xabc": [] (行首有额外字符)
test "parse line begin and end assertion ^...$" {
  let regex = parse("^abc$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配整行的情况
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3]")

  // 测试行尾有额外字符的情况（应该不匹配）
  let result = vm(instructions, "abcd", capture_count)
  inspect(result, content="[]")

  // 测试行首有额外字符的情况（应该不匹配）
  let result = vm(instructions, "xabc", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：解析多行模式下的断言
/// 
/// 测试正则表达式 "^line" 在多行文本中的匹配：
/// - 应该匹配每行开头的 "line"
/// 
/// 测试字符串 "line1\nline2\nnot line":
/// - 应该匹配第一行的 "line": [0, 4]
test "parse multiline assertions" {
  let regex = parse("^line")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试多行文本中第一行匹配
  let result = vm(instructions, "line1\nline2\nnot line", capture_count)
  inspect(result, content="[0, 4]")

  // 测试行尾断言在多行文本中的匹配
  let regex = parse("line$")
  let { instructions, capture: capture_count, .. } = regex.compile()
  let result = vm(instructions, "not line\nline2\nthis line", capture_count)
  inspect(result, content="[4, 8]") // 匹配第一行的 "line"
}

///| 测试示例：断言与量词的组合
/// 
/// 测试正则表达式 "^a+$":
/// - 行首断言：^
/// - 字符 'a' 重复一次或多次
/// - 行尾断言：$
/// 
/// 预期匹配整行都是 'a' 字符的情况
test "parse assertion with quantifiers" {
  let regex = parse("^a+$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配整行都是 'a' 的情况
  let result = vm(instructions, "aaa", capture_count)
  inspect(result, content="[0, 3]")

  // 测试单个 'a' 的情况
  let result = vm(instructions, "a", capture_count)
  inspect(result, content="[0, 1]")

  // 测试包含其他字符的情况（应该不匹配）
  let result = vm(instructions, "aab", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：断言与捕获组的组合
/// 
/// 测试正则表达式 "^(abc)$":
/// - 行首断言：^
/// - 捕获组：(abc)
/// - 行尾断言：$
/// 
/// 预期捕获整行的内容
test "parse assertion with capture groups" {
  let regex = parse("^(abc)$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配并捕获整行
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[0, 3, 0, 3]")

  // 测试不匹配的情况
  let result = vm(instructions, "abcd", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：转义断言字符
/// 
/// 测试正则表达式 "\\^abc\\$":
/// - 转义的 '^' 字符
/// - 字符序列：abc
/// - 转义的 '$' 字符
/// 
/// 预期匹配字面量字符串 "^abc$"
test "parse escaped assertion characters" {
  let regex = parse("\\^abc\\$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配字面量 "^abc$"
  let result = vm(instructions, "^abc$", capture_count)
  inspect(result, content="[0, 5]")

  // 测试不匹配没有字面量符号的情况
  let result = vm(instructions, "abc", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：断言字符在字符类中
/// 
/// 测试正则表达式 "[^$]":
/// - 字符类：匹配除了 '$' 之外的任意字符
/// 
/// 在字符类中，^ 在首位表示否定，$ 被当作普通字符处理
test "parse assertion characters in character class" {
  let regex = parse("[^$]")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配普通字符
  let result = vm(instructions, "a", capture_count)
  inspect(result, content="[0, 1]")

  // 测试匹配 '^' 字符（因为它不是 '$'）
  let result = vm(instructions, "^", capture_count)
  inspect(result, content="[0, 1]")

  // 测试不匹配 '$' 字符
  let result = vm(instructions, "$", capture_count)
  inspect(result, content="[]")
}

///| 测试示例：复杂的断言表达式
/// 
/// 测试正则表达式 "^(hello|world)$":
/// - 行首断言：^
/// - 选择组：(hello|world)
/// - 行尾断言：$
/// 
/// 预期匹配整行是 "hello" 或 "world" 的情况
test "parse complex assertion expression" {
  let regex = parse("^(hello|world)$")
  let { instructions, capture: capture_count, .. } = regex.compile()

  // 测试匹配 "hello"
  let result = vm(instructions, "hello", capture_count)
  inspect(result, content="[0, 5, 0, 5]")

  // 测试匹配 "world"
  let result = vm(instructions, "world", capture_count)
  inspect(result, content="[0, 5, 0, 5]")

  // 测试不匹配其他内容
  let result = vm(instructions, "hello world", capture_count)
  inspect(result, content="[]")
}

///|
test "to be fixed" {
  // This should be a char class with `]` and `[`
  parse("[][]")
  |> inspect(
    content="Concat([CharClass([], neg=false), CharClass([], neg=false)])",
  )
}

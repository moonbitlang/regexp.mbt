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
/// factor      = char / group / char-class / escape / dot   ; 基本元素
/// 
/// ; 量词
/// quantifier  = "*" / "+" / "?"
/// 
/// ; 分组
/// group       = "(" expression ")"                   ; 捕获组：(abc)
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
/// ; 任意字符
/// dot         = "."                                  ; 匹配任意字符
/// 
/// ; 普通字符
/// char        = normal-char
/// normal-char = <any character except special chars>
/// special-chars = "*" / "+" / "?" / "|" / "(" / ")" / "[" / "]" / "{" / "}" / "\" / "."
/// ```
/// 
/// 解析优先级（从高到低）：
/// 1. 因子 (factor): 字符、分组、字符类、转义
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
pub type! Error_ {
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
pub fn parse(regex : @string.View) -> Regex!Error_ {
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
fn Parser::parse_expression(self : Parser) -> Regex!Error_ {
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
fn Parser::parse_sequence(self : Parser) -> Regex!Error_ {
  let sequence = []
  while self.input is [ch, ..] && ch != '|' && ch != ')' {
    let term = self.parse_term()
    sequence.push(term)
  }
  match sequence.length() {
    // 空序列被认为是合法的正则表达式（与 Go 的行为一致）
    0 => Empty
    1 => sequence[0]
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
/// 
/// 示例：
/// - `a`   -> 基本因子：字符a
/// - `a*`  -> 量词项：字符a重复0次或多次
/// - `a+`  -> 量词项：字符a重复1次或多次
/// - `a?`  -> 量词项：字符a重复0次或1次
/// - `(ab)*` -> 量词项：分组(ab)重复0次或多次
/// 
/// 返回: 解析后的 Regex AST
fn Parser::parse_term(self : Parser) -> Regex!Error_ {
  let mut base = self.parse_factor()

  // 处理量词
  match self.input {
    ['*', .. rest] =>
      if rest is ['?', .. rest] {
        // 处理懒惰量词 '*?'
        self.input = rest // 消费 '*'
        base = ZeroOrMore(base, lazy=true)
      } else {
        // 处理贪婪量词 '*'
        self.input = rest // 消费 '*'
        base = ZeroOrMore(base, lazy=false)
      }
    ['+', .. rest] =>
      if rest is ['?', .. rest] {
        // 处理懒惰量词 '+?'
        self.input = rest // 消费 '+'
        base = OneOrMore(base, lazy=true)
      } else {
        // 处理贪婪量词 '+'
        self.input = rest // 消费 '+'
        base = OneOrMore(base, lazy=false)
      }
    ['?', .. rest] =>
      if rest is ['?', .. rest] {
        // 处理懒惰量词 '??'
        self.input = rest // 消费 '?'
        base = ZeroOrOne(base, lazy=true)
      } else {
        // 处理贪婪量词 '?'
        self.input = rest // 消费 '?'
        base = ZeroOrOne(base, lazy=false)
      }
    _ => ()
  }
  base
}

///| 解析因子 (Factor)
/// 
/// 根据 ABNF 规则：`factor = char / group / char-class / escape / dot`
/// 
/// 因子是正则表达式的最小单元，可以是：
/// - 分组：`(expression)` - 用括号包围的子表达式
/// - 字符类：`[abc]` - 匹配指定字符集合中的任意一个字符
/// - 任意字符：`.` - 匹配任意一个字符
/// - 转义字符：`\c` - 转义后的字符，如 `\*`、`\\`
/// - 普通字符：除特殊字符外的任意字符
/// 
/// 特殊字符需要转义才能作为字面量使用：
/// `*` `+` `?` `|` `(` `)` `[` `]` `{` `}` `\` `.`
/// 
/// 示例：
/// - `a`       -> 字符：匹配字符'a'
/// - `(abc)`   -> 分组：捕获组，匹配序列'abc'
/// - `[abc]`   -> 字符类：匹配'a'、'b'或'c'
/// - `\.`      -> 转义字符：匹配字面量'.'
/// - `.`       -> 任意字符：匹配任何字符
/// 
/// 返回: 解析后的 Regex AST
/// 
/// 抛出: Error_ 当遇到无效语法时
fn Parser::parse_factor(self : Parser) -> Regex!Error_ {
  match self.peek_char() {
    Some('(') => {
      self.consume_char() // 消费 '('
      let expr = self.parse_expression()
      guard self.input is [')', ..] else {
        raise Error_(err=MissingParenthesis, data=self.input)
      }
      self.consume_char() // 消费 ')'
      Capture(expr)
    }
    Some('[') => self.parse_char_class()
    Some('.') => {
      self.consume_char() // 消费 '.'
      CharClass(['\u{0}', '\u{10FFFF}'])
    }
    Some('\\') => {
      self.consume_char() // 消费 '\'
      guard self.peek_char() is Some(c) else {
        raise Error_(err=TrailingBackslash, data=self.input)
      }
      self.consume_char()
      CharClass([c, c])
    }
    Some(c) if Parser::is_special_char(c) =>
      raise Error_(err=InvalidEscape, data=self.input)
    Some(c) => {
      self.consume_char()
      CharClass([c, c])
    }
    None => raise Error_(err=InternalError, data=self.input)
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
/// 返回: CharClass(chars) - 包含字符范围列表的字符类 AST
/// 
/// 抛出: Error_ 当字符类格式错误时
fn Parser::parse_char_class(self : Parser) -> Regex!Error_ {
  self.consume_char() // 消费 '['
  let chars = []
  while self.input is [ch, .. rest] && ch != ']' {
    let start_char = match ch {
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
  guard self.input is [']', ..] else {
    raise Error_(err=MissingBracket, data=self.input)
  }
  self.consume_char() // 消费 ']'
  CharClass(chars)
}

///| 查看当前字符但不消费
/// 
/// 返回: 当前位置的字符，如果已到达输入末尾则返回 None
fn Parser::peek_char(self : Parser) -> Char? {
  match self.input {
    [ch, ..] => Some(ch)
    _ => None
  }
}

///| 消费当前字符并移动到下一个位置
/// 
/// 修改解析器的内部状态，将输入指针向前移动一位
fn Parser::consume_char(self : Parser) -> Unit {
  match self.input {
    [_, .. rest] => self.input = rest
    _ => ()
  }
}

///| 检查是否还有更多字符可以解析
/// 
/// 返回: 如果输入中还有字符则返回 true，否则返回 false
fn Parser::has_more(self : Parser) -> Bool {
  not(self.input is "")
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
  c is ('*' | '+' | '?' | '|' | '(' | ')' | '[' | ']' | '{' | '}' | '.')
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
test {
  let regex = parse("a(b|c)*d")
  let { instructions, capture_count } = regex.compile()
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
test {
  let regex = parse("abc|def|ghi")
  let { instructions, capture_count } = regex.compile()
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
test {
  let regex = parse("a.c")
  let { instructions, capture_count } = regex.compile()
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
test {
  let regex = parse("[a-z]")
  let { instructions, capture_count } = regex.compile()
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
test {
  let regex = parse("[a-zA-Z]")
  let { instructions, capture_count } = regex.compile()
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
test {
  let regex = parse("[a-z0-9_]")
  let { instructions, capture_count } = regex.compile()
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
test {
  let regex = parse("[abc-]")
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "-", capture_count)
  inspect(result, content="[0, 1]")
}

///| 测试示例：解析带转义字符的字符类范围
/// 
/// 测试正则表达式 "[a-\]]":
/// - 字符范围：从 'a' 到 ']' 的范围
/// - 使用转义来包含 ']' 字符
/// 
/// 预期匹配字符串 "]" 中的 ']' 字符:
/// - 匹配范围: [0, 1]
test {
  let regex = parse("[\\]-a]")
  let { instructions, capture_count } = regex.compile()
  let result = vm(instructions, "]", capture_count)
  inspect(result, content="[0, 1]")

  // invalid case:
  let regex = try? parse("[a-\\]]")
  inspect(
    regex,
    content=
      #|Err(Error_(err=InvalidCharClass, data="]"))
    ,
  )
}

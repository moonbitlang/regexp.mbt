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

///| 编译正则表达式为执行引擎
/// 
/// 将正则表达式字符串解析并编译为可重用的执行引擎。
/// 编译后的引擎可以多次执行，避免重复解析和编译的开销。
/// 
/// 参数:
/// - `regexp`: 正则表达式字符串视图
/// 
/// 返回: 编译后的正则表达式执行引擎
/// 
/// 抛出: Error_ 当正则表达式语法错误时
/// 
/// 示例:
/// ```moonbit skip
/// let engine = compile("a(bc|de)f")
/// let result = engine.execute("xxabcf")
/// ```
pub fn compile(
  regexp : @string.View,
  flags~ : @string.View = ""
) -> Engine raise Error_ {
  regexp
  |> parse(flags={
    multiline: flags.contains("m"),
    singleline: flags.contains("s"),
    ignore_case: flags.contains("i"),
  })
  |> Regex::compile
}

///| 通过组名获取捕获组的索引
/// 
/// 查找指定名称的捕获组在结果中的索引位置。
/// 用于访问命名捕获组，如 `(?<name>pattern)` 形式定义的组。
/// 
/// 参数:
/// - `self`: 正则表达式执行引擎
/// - `name`: 捕获组的名称
/// 
/// 返回: 捕获组的索引，如果组名不存在则返回 None
/// 
/// 示例:
/// ```moonbit skip
/// let engine = compile("(?<word>\\w+)")
/// let index = engine.group_by_name("word")  // Some(1)
/// ```
pub fn Engine::group_by_name(self : Engine, name : String) -> Int? {
  self.map.get(name)
}

///| 获取正则表达式中捕获组的总数
/// 
/// 返回正则表达式模式中定义的捕获组数量，包括命名和匿名捕获组。
/// 索引为 0 的组始终表示整个匹配，实际的捕获组从索引 1 开始。
/// 
/// 参数:
/// - `self`: 正则表达式执行引擎
/// 
/// 返回: 捕获组的总数（不包括索引 0 的完整匹配）
/// 
/// 示例:
/// ```moonbit skip
/// let engine = compile("(a)(b|c)")
/// let count = engine.group_count()  // 2
/// ```
pub fn Engine::group_count(self : Self) -> Int {
  self.capture
}

///| 获取正则表达式中所有命名捕获组的名称
/// 
/// 返回一个迭代器，包含正则表达式中所有命名捕获组的名称。
/// 只返回显式命名的捕获组，如 `(?<name>pattern)` 形式定义的组。
/// 
/// 参数:
/// - `self`: 正则表达式执行引擎
/// 
/// 返回: 包含所有组名的迭代器
/// 
/// 示例:
/// ```moonbit skip skip
/// let engine = compile("(?<first>a)(?<second>b)")
/// let names = engine.group_names().collect()  // ["first", "second"]
/// ```
pub fn Engine::group_names(self : Self) -> Iter[String] {
  self.map.keys()
}

///| 对输入文本执行正则表达式匹配
/// 
/// 使用已编译的正则表达式引擎对指定的输入文本进行匹配，
/// 返回包含匹配结果和捕获组信息的 MatchResult 对象。
/// 采用最左匹配策略，返回第一个找到的匹配。
/// 
/// 参数:
/// - `self`: 正则表达式执行引擎
/// - `input`: 要进行匹配的输入文本
/// 
/// 返回: 匹配结果对象，包含匹配状态和捕获组信息
/// 
/// 示例:
/// ```moonbit skip
/// let engine = compile("a(bc|de)f")
/// let result = engine.execute("xxabcf")
/// if result.matched() { /* 处理匹配结果 */ }
/// ```
pub fn Engine::execute(self : Engine, input : @string.View) -> MatchResult {
  {
    input,
    captures: vm(self.instructions, input, self.capture),
    names: self.map,
  }
}

///| 正则表达式匹配结果
/// 
/// 包含正则表达式匹配的完整结果信息，包括：
/// - 原始输入文本
/// - 捕获组的位置信息数组
/// - 命名捕获组的映射关系
/// 
/// 捕获组数组的结构：
/// - 索引 0,1: 完整匹配的开始和结束位置
/// - 索引 2,3: 第一个捕获组的开始和结束位置
/// - 索引 4,5: 第二个捕获组的开始和结束位置
/// - 以此类推...
struct MatchResult {
  input : @string.View
  captures : Array[Int]
  names : Map[String, Int]
}

///| 检查是否匹配成功
/// 
/// 判断正则表达式是否在输入文本中找到了匹配。
/// 如果捕获组数组为空，表示没有找到任何匹配。
/// 
/// 参数:
/// - `self`: 匹配结果对象
/// 
/// 返回: 如果找到匹配则返回 true，否则返回 false
/// 
/// 示例:
/// ```moonbit skip
/// let result = engine.execute("text")
/// if result.matched() {
///   println("匹配成功")
/// }
/// ```
pub fn MatchResult::matched(self : Self) -> Bool {
  not(self.captures is [])
}

///| 通过索引获取捕获组的内容
/// 
/// 根据捕获组的索引返回对应的匹配文本。
/// 索引 0 表示完整匹配，索引 1 及以上表示各个捕获组。
/// 
/// 参数:
/// - `self`: 匹配结果对象
/// - `index`: 捕获组的索引（0 表示完整匹配）
/// 
/// 返回: 
/// - Some(view): 捕获组对应的文本视图
/// - None: 索引无效或该捕获组未匹配
/// 
/// 示例:
/// ```moonbit skip
/// let result = engine.execute("abc")
/// let full_match = result.group(0)    // Some("abc")
/// let first_group = result.group(1)   // Some("bc")
/// ```
pub fn MatchResult::group(self : Self, index : Int) -> @string.View? {
  if self.captures.is_empty() ||
    index < 0 ||
    index >= self.captures.length() / 2 {
    return None
  }
  let start = self.captures[index * 2]
  let end = self.captures[index * 2 + 1]
  if start < 0 || end < start || end > self.input.length() {
    return None
  }
  Some(self.input.view(start_offset=start, end_offset=end))
}

///| 通过组名获取命名捕获组的内容
/// 
/// 根据命名捕获组的名称返回对应的匹配文本。
/// 适用于 `(?<name>pattern)` 形式定义的命名捕获组。
/// 
/// 参数:
/// - `self`: 匹配结果对象  
/// - `name`: 捕获组的名称
/// 
/// 返回: 
/// - Some(view): 命名捕获组对应的文本视图
/// - None: 该命名组未匹配到内容
/// 
/// 抛出: Error_ 当指定的组名不存在时
/// 
/// 示例:
/// ```moonbit skip
/// let result = engine.execute("abc")
/// let word = result.group_by_name("word")  // Some("abc")
/// ```
pub fn MatchResult::group_by_name(
  self : Self,
  name : String
) -> @string.View? raise {
  guard self.names.get(name) is Some(index) else {
    fail("Group name '\{name}' does not exist")
  }
  self.group(index)
}

///| 获取所有有效捕获组的内容迭代器
/// 
/// 返回一个迭代器，包含所有成功匹配的捕获组内容，
/// 包括完整匹配（索引 0）和所有捕获组。只返回有效的匹配内容，
/// 跳过未匹配的捕获组。
/// 
/// 参数:
/// - `self`: 匹配结果对象
/// 
/// 返回: 包含所有有效捕获组内容的迭代器
/// 
/// 示例:
/// ```moonbit skip
/// let result = engine.execute("abc")
/// let all_groups = result.results().collect()  // ["abc", "bc"]
/// ```
pub fn MatchResult::results(self : Self) -> Iter[@string.View?] {
  Iter::new(fn(yield_) {
    for i = 0; i < self.captures.length() / 2; i = i + 1 {
      let start = self.captures[i * 2]
      let end = self.captures[i * 2 + 1]
      if start == -1 && end == -1 {
        guard yield_(None) is IterContinue else { return IterEnd }
      } else {
        guard yield_(Some(self.input.view(start_offset=start, end_offset=end)))
          is IterContinue else {
          return IterEnd
        }
      }
    } else {
      IterContinue
    }
  })
}

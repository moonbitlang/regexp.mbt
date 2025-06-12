///|
fn is_word_char(c : Char) -> Bool {
  // Check if the character is a word character (alphanumeric or underscore)
  return (c >= 'a' && c <= 'z') ||
    (c >= 'A' && c <= 'Z') ||
    (c >= '0' && c <= '9') ||
    c == '_'
}

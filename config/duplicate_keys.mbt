///|
// Check before the JSON parser can overwrite duplicate component IDs. Strings
// are decoded with the standard parser so escaped spellings compare equally.
fn validate_keys(source : String) -> Unit raise {
  let scopes : Array[Map[String, Bool]?] = []
  let mut i = 0
  while i < source.length() {
    match source[i] {
      '{' => {
        scopes.push(Some(Map([])))
        i += 1
      }
      '[' => {
        scopes.push(None)
        i += 1
      }
      '}' | ']' => {
        let _ = scopes.pop()
        i += 1
      }
      '"' => {
        let start = i
        i += 1
        while i < source.length() && source[i] != '"' {
          if source[i] == '\\' {
            i += 1
          }
          i += 1
        }
        if i >= source.length() {
          error("config", "unterminated string")
        }
        i += 1
        let end = i
        while i < source.length() &&
              (
                source[i] == ' ' ||
                source[i] == '\n' ||
                source[i] == '\r' ||
                source[i] == '\t'
              ) {
          i += 1
        }
        if i < source.length() &&
          source[i] == ':' &&
          scopes.last() is Some(Some(keys)) {
          let key : String = @json.from_json(
            @json.parse(source[start:end].to_owned()),
          )
          if keys.contains(key) {
            error("config", "duplicate key " + key)
          }
          keys[key] = true
        }
      }
      _ => i += 1
    }
    if scopes.length() > 64 {
      error("config", "nesting limit exceeded")
    }
  }
}

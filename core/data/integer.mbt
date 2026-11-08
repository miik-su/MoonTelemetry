///|
// Preserve the parser's original numeric lexeme; never round through Double.
fn integer_json(value : Json) -> Json raise DataError {
  let text = match value {
    String(s) => s
    Number(_, repr=Some(s)) => s
    Number(n, repr=None) => {
      guard n >= -9007199254740991.0 && n <= 9007199254740991.0 else {
        raise Invalid("64-bit number requires an exact JSON lexeme")
      }
      n.to_string()
    }
    _ => raise Invalid("expected integer string or number")
  }
  let text = text.to_lower()
  let parts = text.split("e").collect()
  guard parts.length() <= 2 else { raise Invalid("invalid integer exponent") }
  let mut exponent = 0
  if parts.length() == 2 {
    let s = parts[1].to_owned()
    let negative = s.has_prefix("-")
    let offset = if negative || s.has_prefix("+") { 1 } else { 0 }
    guard s.length() > offset else { raise Invalid("empty exponent") }
    for i in offset..<s.length() {
      guard s[i] >= '0' && s[i] <= '9' && exponent <= 100 else {
        raise Invalid("integer exponent out of bounds")
      }
      exponent = exponent * 10 + s[i].to_int() - 48
    }
    if negative {
      exponent = -exponent
    }
  }
  let mantissa = parts[0].to_owned()
  let negative = mantissa.has_prefix("-")
  let offset = if negative { 1 } else { 0 }
  let digits = StringBuilder()
  let mut fraction = 0
  let mut dot = false
  for i in offset..<mantissa.length() {
    let c = mantissa[i]
    if c == '.' && !dot {
      dot = true
    } else {
      guard c >= '0' && c <= '9' else {
        raise Invalid("invalid integer digits")
      }
      digits.write_char(mantissa.get_char(i).unwrap())
      if dot {
        fraction += 1
      }
    }
  }
  let raw = digits.to_string()
  guard !raw.is_empty() else { raise Invalid("missing integer digits") }
  let mut first = 0
  while first < raw.length() && raw[first] == '0' {
    first += 1
  }
  if first == raw.length() {
    return Json::string("0")
  }
  let shift = exponent - fraction
  let mut last = raw.length()
  if shift < 0 {
    guard -shift < raw.length() - first else {
      raise Invalid("fractional integer")
    }
    for i in (raw.length() + shift)..<raw.length() {
      if raw[i] != '0' {
        raise Invalid("fractional integer")
      }
    }
    last += shift
  }
  guard last - first + shift.max(0) <= 20 else {
    raise Invalid("integer overflow")
  }
  let result = StringBuilder()
  if negative {
    result.write_char('-')
  }
  result.write_string(raw[first:last].to_owned())
  for _ in 0..<shift.max(0) {
    result.write_char('0')
  }
  Json::string(result.to_string())
}

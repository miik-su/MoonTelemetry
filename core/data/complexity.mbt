///|
// Scan before recursive JSON parsing; delimiters inside strings do not count.
fn validate_json_text(text : String, limits : Limits) -> Unit raise DataError {
  let mut depth = 0
  let mut tokens = 0
  let mut quoted = false
  let mut escaped = false
  for c in text {
    if quoted {
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == '"' {
        quoted = false
      }
    } else {
      if c == '"' {
        quoted = true
        tokens += 1
      }
      if c == '{' || c == '[' {
        depth += 1
        tokens += 1
      }
      if c == '}' || c == ']' {
        depth -= 1
      }
      if c == ',' {
        tokens += 1
      }
      if depth > limits.max_nesting_depth ||
        tokens > limits.max_total_fields_per_request {
        raise Invalid("JSON complexity limit exceeded")
      }
    }
  }
}

///|
fn validate_json_shape(
  j : Json,
  counts : Array[Int32],
  depth : Int32,
  limits : Limits,
) -> Unit raise DataError {
  if depth > limits.max_nesting_depth {
    raise Invalid("OTLP nesting limit exceeded")
  }
  match j {
    Object(m) =>
      for key, v in m {
        counts[0] += 1
        if counts[0] > limits.max_total_fields_per_request {
          raise Invalid("OTLP field limit exceeded")
        }
        if v is Array(a) {
          if ["logRecords", "spans", "dataPoints"].contains(key) {
            counts[1] += a.length()
          }
          if (key == "attributes" || key == "filteredAttributes") &&
            a.length() > limits.max_attributes_per_record {
            raise Invalid("attribute limit exceeded")
          }
          if counts[1] > limits.max_records_per_request {
            raise Invalid("record limit exceeded")
          }
        }
        validate_json_shape(v, counts, depth + 1, limits)
      }
    Array(a) =>
      for v in a {
        validate_json_shape(v, counts, depth + 1, limits)
      }
    _ => ()
  }
}

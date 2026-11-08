///|
pub struct Endpoint {
  origin : String
  base_path : String
}

///|
fn self_endpoint(value : String) -> Endpoint raise {
  endpoint(value)
}

///|
pub fn endpoint(value : String) -> Endpoint raise {
  for c in value {
    if c <= ' ' || c == '\\' || c == '\u007f' {
      error("endpoint", "whitespace/control characters are forbidden")
    }
  }
  let parts = value.split("://").collect()
  if parts.length() != 2 || !(parts[0] == "http" || parts[0] == "https") {
    error("endpoint", "HTTP(S) scheme required")
  }
  if value.contains("@") || value.contains("?") || value.contains("#") {
    error("endpoint", "userinfo query and fragment are forbidden")
  }
  let segments = parts[1].split("/").collect()
  let authority = segments[0].to_owned()
  if authority.is_empty() {
    error("endpoint", "host required")
  }
  let mut host = authority
  let mut port = ""
  if authority.has_prefix("[") {
    let pieces = authority.split("]").collect()
    if pieces.length() != 2 {
      error("endpoint", "invalid IPv6 authority")
    }
    host = pieces[0][1:].to_owned()
    let suffix = pieces[1].to_owned()
    if !suffix.is_empty() {
      if !suffix.has_prefix(":") {
        error("endpoint", "invalid port")
      }
      port = suffix[1:].to_owned()
      if port.is_empty() {
        error("endpoint", "empty port")
      }
    }
    let _ = @socket.Addr::parse("[" + host + "]:1") catch {
      _ => raise @component.Configuration("endpoint: invalid IPv6 address")
    }
  } else {
    let pieces = authority.split(":").collect()
    if pieces.length() > 2 {
      error("endpoint", "IPv6 addresses require brackets")
    }
    host = pieces[0].to_owned()
    if pieces.length() == 2 {
      port = pieces[1].to_owned()
      if port.is_empty() {
        error("endpoint", "empty port")
      }
    }
    if host.is_empty() || host.length() > 253 {
      error("endpoint", "invalid hostname")
    }
    for label in host.split(".") {
      if label.is_empty() ||
        label.length() > 63 ||
        label.has_prefix("-") ||
        label.has_suffix("-") {
        error("endpoint", "invalid DNS label")
      }
      for c in label {
        if !((c >= 'a' && c <= 'z') ||
          (c >= 'A' && c <= 'Z') ||
          (c >= '0' && c <= '9') ||
          c == '-') {
          error("endpoint", "invalid hostname character")
        }
      }
    }
    if host.split(".").all(s => s.iter().all(c => c >= '0' && c <= '9')) {
      let _ = @socket.Addr::parse(host + ":1") catch {
        _ => raise @component.Configuration("endpoint: invalid IPv4 address")
      }
    }
  }
  if !port.is_empty() {
    let mut n = 0
    for c in port {
      if c < '0' || c > '9' || n > 65535 {
        error("endpoint", "invalid port")
      }
      n = n * 10 + c.to_int() - 48
    }
    if n < 1 || n > 65535 {
      error("endpoint", "port out of range")
    }
  }
  let path_parts = segments[1:].map(s => s.to_owned())
  for s in path_parts {
    if s == "." || s == ".." || s.contains("%") {
      error("endpoint", "dot segments and escaped paths unsupported")
    }
  }
  let path = if path_parts.is_empty() { "" } else { "/" + path_parts.join("/") }
  let path = if path.has_suffix("/") {
    path[:path.length() - 1].to_owned()
  } else {
    path
  }
  { origin: parts[0].to_owned() + "://" + authority, base_path: path, }
}

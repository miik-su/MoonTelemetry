///|
pub fn file_path(value : String) -> String raise @component.CollectorError {
  if value.is_empty() {
    error("file.path", "path required")
  }
  for c in value {
    if c < ' ' || c == '\u007f' {
      error("file.path", "control character forbidden")
    }
  }
  let path = value.replace(old="\\", new="/")
  if path.has_prefix("//") {
    error("file.path", "UNC/device paths unsupported")
  }
  let absolute = path.has_prefix("/") ||
    (path.length() > 2 && path[1] == ':' && path[2] == '/')
  let base = if absolute {
    path
  } else {
    @env.current_dir().unwrap_or(".").replace(old="\\", new="/") + "/" + path
  }
  let parts : Array[String] = []
  for item in base.split("/") {
    let s = item.to_owned()
    if s.is_empty() || s == "." {
      continue
    }
    if s == ".." {
      if parts.is_empty() {
        error("file.path", "path escapes root")
      }
      let _ = parts.pop()
      continue
    }
    let stem = s.split(".").next().unwrap_or("").to_owned().to_upper()
    if [
        "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6",
        "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7",
        "LPT8", "LPT9",
      ].contains(stem) ||
      s.has_suffix(" ") ||
      s.has_suffix(".") {
      error("file.path", "nonportable file name")
    }
    parts.push(s)
  }
  if parts.is_empty() || path.has_suffix("/") {
    error("file.path", "file name required")
  }
  let joined = (if base.has_prefix("/") { "/" } else { "" }) + parts.join("/")
  // Windows paths are case-insensitive. Linux paths retain their case.
  if joined.length() > 1 && joined[1] == ':' {
    joined.to_lower()
  } else {
    joined
  }
}

///|
extern "C" fn current_rss() -> Int64 = "moontelemetry_current_rss"

///|
/// Current resident memory in bytes; unavailable platforms return None.
/// Observation only: this is not an allocator limit or admission counter.
pub fn rss_bytes() -> Int64? {
  let value = current_rss()
  if value >= 0L {
    Some(value)
  } else {
    None
  }
}

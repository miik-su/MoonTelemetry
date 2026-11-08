///|
/// Logical byte budget for the single cooperative Native event loop.
/// Operations contain no suspension point; sharing across OS threads is unsupported.
pub struct MemoryBudget {
  limit : Int64
  mut retained : Int64
}

///|
pub fn MemoryBudget::new(limit : Int64) -> MemoryBudget raise CollectorError {
  guard limit > 0 else { raise Configuration("memory budget must be positive") }
  { limit, retained: 0L, }
}

///|
pub fn MemoryBudget::reserve(self : MemoryBudget, bytes : Int64) -> Bool {
  if bytes < 0 || bytes > self.limit - self.retained {
    return false
  }
  self.retained += bytes
  true
}

///|
pub fn MemoryBudget::release(self : MemoryBudget, bytes : Int64) -> Unit {
  guard bytes >= 0 && bytes <= self.retained else {
    abort("unbalanced memory budget release")
  }
  self.retained -= bytes
}

///|
pub fn MemoryBudget::used(self : MemoryBudget) -> Int64 {
  self.retained
}

///|
pub fn MemoryBudget::available(self : MemoryBudget) -> Int64 {
  self.limit - self.retained
}

///|
pub fn MemoryBudget::is_overloaded(self : MemoryBudget) -> Bool {
  self.available() == 0L
}

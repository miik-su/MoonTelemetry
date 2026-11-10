///|
priv struct RequestMemory {
  global : @component.MemoryBudget
  requests : @component.MemoryBudget
  mut held : Int64
}

///|
#derive(Debug)
priv suberror ReservationError {
  RequestBudgetExhausted
  GlobalBudgetExhausted
}

///|
fn RequestMemory::reserve(
  self : RequestMemory,
  bytes : Int64,
) -> Unit raise ReservationError {
  if !self.requests.reserve(bytes) {
    raise RequestBudgetExhausted
  }
  if !self.global.reserve(bytes) {
    self.requests.release(bytes)
    raise GlobalBudgetExhausted
  }
  self.held += bytes
}

///|
fn RequestMemory::release(self : RequestMemory) -> Unit {
  self.requests.release(self.held)
  self.global.release(self.held)
  self.held = 0L
}

///|
fn reserve_growth(
  memory : RequestMemory,
  capacity : Array[Int32],
  target : Int32,
) -> Unit raise ReservationError {
  if target > capacity[0] {
    memory.reserve((target - capacity[0]).to_int64() * 3L)
    capacity[0] = target
  }
}

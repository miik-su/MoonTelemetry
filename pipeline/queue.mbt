///|
pub struct Packet {
  signal : @data.Signal
  body : Bytes
  count : Int32
}

///|
pub fn Packet::new(input : @data.Envelope) -> Packet raise {
  {
    signal: input.signal(),
    body: input.encode(json=false),
    count: input.count(),
  }
}

///|
pub fn Packet::decode(self : Packet) -> @data.Envelope raise {
  @data.decode(self.signal, self.body, json=false, limits={
    max_records_per_request: self.count.max(1),
    max_attributes_per_record: 256,
    max_total_fields_per_request: self.body.length().max(1),
    max_nesting_depth: 64,
  })
}

///|
pub fn Packet::count(self : Packet) -> Int32 {
  self.count
}

///|
pub struct Queue {
  budget : @component.MemoryBudget
  slots : Array[Packet?]
  max_bytes : Int32
  mut head : Int32
  mut tail : Int32
  mut length : Int32
  mut bytes : Int32
  mut inflight : Packet?
  mut accepting : Bool
  mut accepted : Int64
  mut delivered : Int64
  mut dropped : Int64
  mut overflow_dropped : Int64
}

///|
pub fn Queue::new(
  capacity~ : Int32,
  max_bytes~ : Int32,
  budget? : @component.MemoryBudget,
) -> Queue raise @component.CollectorError {
  guard capacity > 0 && capacity <= 65536 && max_bytes > 0 else {
    raise @component.Configuration("invalid queue bounds")
  }
  {
    budget: budget.unwrap_or(@component.MemoryBudget::new(max_bytes.to_int64())),
    slots: Array::make(capacity, None),
    max_bytes,
    head: 0,
    tail: 0,
    length: 0,
    bytes: 0,
    inflight: None,
    accepting: true,
    accepted: 0L,
    delivered: 0L,
    dropped: 0L,
    overflow_dropped: 0L,
  }
}

///|
pub fn Queue::can_accept(self : Queue, p : Packet) -> Bool {
  self.accepting &&
  self.length + (if self.inflight is Some(_) { 1 } else { 0 }) <
  self.slots.length() &&
  p.body.length() <= self.max_bytes - self.bytes
}

///|
pub fn Queue::push(self : Queue, p : Packet) -> Bool {
  if !self.can_accept(p) {
    return false
  }
  if !self.budget.reserve(p.body.length().to_int64()) {
    return false
  }
  self.enqueue(p)
  true
}

///|
fn Queue::enqueue(self : Queue, p : Packet) -> Unit {
  self.slots[self.tail] = Some(p)
  self.tail = (self.tail + 1) % self.slots.length()
  self.length += 1
  self.bytes += p.body.length()
  self.accepted += p.count.to_int64()
}

///|
// Single worker per queue. Budget stays charged during network retries.
pub fn Queue::take(self : Queue) -> Packet? {
  if self.inflight is Some(p) {
    return Some(p)
  }
  if self.length == 0 {
    return None
  }
  let p = self.slots[self.head]
  self.slots[self.head] = None
  self.head = (self.head + 1) % self.slots.length()
  self.length -= 1
  self.inflight = p
  p
}

///|
pub fn Queue::finish(self : Queue, rejected~ : Int32 = 0) -> Unit {
  if self.inflight is Some(p) {
    let dropped = rejected.max(0).min(p.count)
    self.delivered += (p.count - dropped).to_int64()
    self.dropped += dropped.to_int64()
    self.bytes -= p.body.length()
    self.budget.release(p.body.length().to_int64())
    self.inflight = None
  }
}

///|
pub fn Queue::stop(self : Queue) -> Unit {
  self.accepting = false
}

///|
pub fn Queue::empty(self : Queue) -> Bool {
  self.length == 0 && self.inflight is None
}

///|
pub fn Queue::stats(self : Queue) -> Json {
  {
    "accepted": Json::string(self.accepted.to_string()),
    "delivered": Json::string(self.delivered.to_string()),
    "dropped": Json::string(self.dropped.to_string()),
    "overflowDropped": Json::string(self.overflow_dropped.to_string()),
    "queuedBatches": Json::number(self.length.to_double()),
    "retainedBytes": Json::number(self.bytes.to_double()),
  }
}

///|
pub fn Queue::record_overflow(self : Queue, p : Packet) -> Unit {
  self.overflow_dropped += p.count.to_int64()
}

///|
pub fn Queue::discard_all(self : Queue) -> Unit {
  for ;; {
    match self.take() {
      Some(p) => self.finish(rejected=p.count)
      None => break
    }
  }
}

///|
pub struct Fanout {
  queues : Array[Queue]
}

///|
pub fn Fanout::new(queues : Array[Queue]) -> Fanout {
  { queues, }
}

///|
// Atomic admission within the cooperative scheduler: no await between check/push.
pub fn Fanout::submit(
  self : Fanout,
  p : Packet,
) -> Unit raise @component.CollectorError {
  guard self.queues.all(q => q.can_accept(p)) else {
    raise @component.Backpressure("destination queue full or draining")
  }
  let reserved : Array[Queue] = []
  for q in self.queues {
    if !q.budget.reserve(p.body.length().to_int64()) {
      for previous in reserved {
        previous.budget.release(p.body.length().to_int64())
      }
      raise @component.Backpressure("global memory budget exhausted")
    }
    reserved.push(q)
  }
  for q in self.queues {
    q.enqueue(p)
  }
}

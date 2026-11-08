///|
pub struct Batch {
  signal : @data.Signal
  size : Int32
  timeout_ms : Int32
  max_bytes : Int32
  pending : Array[@data.Envelope]
  mut records : Int32
  mut bytes : Int32
  mut since : Int64
}

///|
pub fn Batch::new(
  signal : @data.Signal,
  size~ : Int32,
  timeout_ms~ : Int32,
  max_bytes~ : Int32,
) -> Batch raise @component.CollectorError {
  guard size > 0 && timeout_ms > 0 && max_bytes > 0 else {
    raise @component.Configuration("batch limits must be positive")
  }
  {
    signal,
    size,
    timeout_ms,
    max_bytes,
    pending: [],
    records: 0,
    bytes: 0,
    since: 0L,
  }
}

///|
pub fn Batch::can_accept(self : Batch, input : @data.Envelope) -> Bool raise {
  input.signal() == self.signal &&
  input.encode(json=false).length() <= self.max_bytes
}

///|
pub fn Batch::push(
  self : Batch,
  input : @data.Envelope,
  now~ : Int64,
) -> Array[@data.Envelope] raise {
  guard self.can_accept(input) else {
    raise @component.Backpressure("batch request exceeds byte budget")
  }
  let bytes = input.encode(json=false).length()
  let out = []
  if self.bytes > self.max_bytes - bytes {
    if self.flush() is Some(e) {
      out.push(e)
    }
  }
  if self.pending.is_empty() {
    self.since = now
  }
  self.pending.push(input)
  self.records += input.count()
  self.bytes += bytes
  if self.records >= self.size {
    if self.flush() is Some(e) {
      out.push(e)
    }
  }
  out
}

///|
pub fn Batch::tick(self : Batch, now~ : Int64) -> @data.Envelope? raise {
  if !self.pending.is_empty() && now - self.since >= self.timeout_ms.to_int64() {
    self.flush()
  } else {
    None
  }
}

///|
pub fn Batch::flush(self : Batch) -> @data.Envelope? raise {
  if self.pending.is_empty() {
    return None
  }
  let result = if self.pending.any(item => item is Future(_, _, _)) {
    @data.merge_future(self.signal, self.pending)
  } else {
    match self.signal {
      Logs => {
        let all = []
        for item in self.pending {
          if item is Logs(x) {
            all.append(x.resource_logs)
          }
        }
        @data.Envelope::Logs({ resource_logs: all, })
      }
      Metrics => {
        let all = []
        for item in self.pending {
          if item is Metrics(x) {
            all.append(x.resource_metrics)
          }
        }
        @data.Envelope::Metrics({ resource_metrics: all, })
      }
      Traces => {
        let all = []
        for item in self.pending {
          if item is Traces(x) {
            all.append(x.resource_spans)
          }
        }
        @data.Envelope::Traces({ resource_spans: all, })
      }
    }
  }
  self.pending.clear()
  self.records = 0
  self.bytes = 0
  Some(result)
}

///|
pub fn admit(input : @data.Envelope, max_bytes : Int32) -> Unit raise {
  guard max_bytes > 0 && input.encode(json=false).length() <= max_bytes else {
    raise @component.Backpressure("memory_limiter request byte budget exceeded")
  }
}

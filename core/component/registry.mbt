///|
pub(all) suberror CollectorError {
  Configuration(String)
  Backpressure(String)
  Stopped
} derive(Debug)

///|
pub(all) enum Kind {
  Receiver
  Processor
  Exporter
} derive(Eq, Debug)

///|
pub(all) enum State {
  Created
  Running
  Draining
  Closed
} derive(Eq, Debug)

///|
pub struct Lifecycle {
  mut state : State
}

///|
pub fn Lifecycle::new() -> Lifecycle {
  { state: Created, }
}

///|
pub fn Lifecycle::state(self : Lifecycle) -> State {
  self.state
}

///|
pub fn Lifecycle::start(self : Lifecycle) -> Unit raise CollectorError {
  guard self.state == Created else {
    raise Configuration("component already started or closed")
  }
  self.state = Running
}

///|
pub fn Lifecycle::drain(self : Lifecycle) -> Unit {
  if self.state == Running {
    self.state = Draining
  }
}

///|
pub fn Lifecycle::close(self : Lifecycle) -> Unit {
  self.state = Closed
}

///|
pub struct Registry {
  entries : Map[String, Kind]
}

///|
pub fn Registry::new() -> Registry {
  { entries: Map([]), }
}

///|
pub fn Registry::register(
  self : Registry,
  name : String,
  kind : Kind,
) -> Unit raise CollectorError {
  let key = kind_key(kind) + ":" + name
  guard !name.is_empty() && !self.entries.contains(key) else {
    raise Configuration("duplicate or empty component: " + name)
  }
  self.entries[key] = kind
}

///|
fn kind_key(k : Kind) -> String {
  match k {
    Receiver => "receiver"
    Processor => "processor"
    Exporter => "exporter"
  }
}

///|
pub fn Registry::contains(self : Registry, name : String, kind : Kind) -> Bool {
  self.entries.contains(kind_key(kind) + ":" + name)
}

///|
pub fn builtins() -> Registry {
  let r = Registry::new()
  try! r.register("otlp", Receiver)
  for name in ["attributes", "resource", "filter", "batch", "memory_limiter"] {
    try! r.register(name, Processor)
  }
  for name in ["debug", "file", "otlp"] {
    try! r.register(name, Exporter)
  }
  r
}

///|
/// Processors must return independently owned envelopes when they mutate input.
pub(open) trait Processor {
  fn process(Self, @data.Envelope) -> @data.Envelope raise
}

///|
pub(open) trait Exporter {
  async fn export(Self, @data.Envelope) -> Unit
  async fn close(Self) -> Unit
}

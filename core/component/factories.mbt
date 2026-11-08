///|
pub struct Factories {
  processors : Map[String, (Json) -> &Processor raise]
  exporters : Map[String, (Json) -> &Exporter raise]
  names : Registry
}

///|
pub fn Factories::new() -> Factories {
  { processors: Map([]), exporters: Map([]), names: builtins(), }
}

///|
pub fn Factories::register_processor(
  self : Factories,
  name : String,
  factory : (Json) -> &Processor raise,
) -> Unit raise CollectorError {
  self.names.register(name, Processor)
  self.processors[name] = factory
}

///|
pub fn Factories::register_exporter(
  self : Factories,
  name : String,
  factory : (Json) -> &Exporter raise,
) -> Unit raise CollectorError {
  self.names.register(name, Exporter)
  self.exporters[name] = factory
}

///|
pub fn Factories::processor(
  self : Factories,
  name : String,
  config : Json,
) -> &Processor raise {
  match self.processors.get(name) {
    Some(factory) => factory(config)
    None => raise Configuration("unknown processor type: " + name)
  }
}

///|
pub fn Factories::exporter(
  self : Factories,
  name : String,
  config : Json,
) -> &Exporter raise {
  match self.exporters.get(name) {
    Some(factory) => factory(config)
    None => raise Configuration("unknown exporter type: " + name)
  }
}

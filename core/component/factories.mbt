///|
pub struct Factories {
  processors : Map[String, (Json) -> &Processor raise]
  exporters : Map[String, (Json) -> &Exporter raise]
  names : Registry
}

///|
/// Compatibility level for the in-process Processor/Exporter contract.
pub fn plugin_api_version() -> Int32 {
  1
}

///|
fn check_plugin_api(version : Int32) -> Unit raise CollectorError {
  guard version == plugin_api_version() else {
    raise Configuration("unsupported plugin API version")
  }
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
  api_version~ : Int32 = 1,
) -> Unit raise CollectorError {
  check_plugin_api(api_version)
  self.names.register(name, Processor)
  self.processors[name] = factory
}

///|
pub fn Factories::register_exporter(
  self : Factories,
  name : String,
  factory : (Json) -> &Exporter raise,
  api_version~ : Int32 = 1,
) -> Unit raise CollectorError {
  check_plugin_api(api_version)
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

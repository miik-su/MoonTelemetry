///|
pub(all) enum Command {
  Run(String)
  Validate(String)
  Version
  Components
  Help
} derive(Eq, Debug)

///|
pub fn parse(
  args : ArrayView[String],
) -> Command raise @component.CollectorError {
  match args {
    [] | ["--help"] | ["help"] => Help
    ["version"] => Version
    ["components"] => Components
    ["run", "--config", path] if !path.is_empty() => Run(path)
    ["validate", "--config", path] if !path.is_empty() => Validate(path)
    _ =>
      raise @component.Configuration(
        "usage: moontelemetry <run|validate> --config <file.json> | version | components",
      )
  }
}

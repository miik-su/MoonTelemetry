///|
async fn main {
  @signal.set_global_cancellation_signals([SIGINT, SIGTERM])
  let args = @env.args()
  match @cli.parse(args[1:]) {
    Help =>
      println(
        "moontelemetry <run|validate> --config <file.json> | version | components",
      )
    Version => println("MoonTelemetry " + @component.version())
    Components =>
      for item in @component.catalog() {
        println(item.name + ": " + item.description)
      }
    Validate(path) => {
      let config = @config.parse(
        @fs.read_file(path).text(),
        env=@env.get_env_var,
      )
      let runtime = @service.Runtime::new(config)
      runtime.preflight()
      println("Configuration valid: \{config.pipelines.length()} pipeline(s)")
    }
    Run(path) => {
      let config = @config.parse(
        @fs.read_file(path).text(),
        env=@env.get_env_var,
      )
      let runtime = @service.Runtime::new(config)
      println(
        "MoonTelemetry starting: \{config.pipelines.length()} pipeline(s); Ctrl+C to drain",
      )
      runtime.run()
      println("MoonTelemetry stopped: " + runtime.health().stringify())
    }
  }
}

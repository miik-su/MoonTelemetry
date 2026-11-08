///|
test "CLI commands reject missing paths and unknown arguments" {
  assert_eq(@cli.parse(["run", "--config", "config.json"]), Run("config.json"))
  assert_eq(@cli.parse(["version"]), Version)
  for
    args in [
      ["run"],
      ["run", "--config"],
      ["run", "--bad", "x"],
      ["version", "extra"],
    ] {
    assert_true(
      try {
        let _ = @cli.parse(args)
        false
      } catch {
        _ => true
      },
    )
  }
}

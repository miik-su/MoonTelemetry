///|
test "unsupported plugin API never reserves a name or calls a factory" {
  let factories = @component.Factories::new()
  assert_eq(@component.plugin_api_version(), 1)
  assert_true(
    try {
      factories.register_processor(
        "versioned",
        _ => abort("factory must not run"),
        api_version=2,
      )
      false
    } catch {
      _ => true
    },
  )
  factories.register_processor(
    "versioned",
    _ => abort("registration must not instantiate"),
    api_version=1,
  )
  assert_true(
    try {
      factories.register_exporter(
        "versioned",
        _ => abort("factory must not run"),
        api_version=0,
      )
      false
    } catch {
      _ => true
    },
  )
  factories.register_exporter("versioned", _ => {
    abort("registration must not instantiate")
  })
}

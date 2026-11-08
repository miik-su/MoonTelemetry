///|
test "normalized path aliases and unsafe file names" {
  assert_eq(
    @config.file_path("./out.jsonl"),
    @config.file_path("tmp/../out.jsonl"),
  )
  for
    path in [
      "NUL", "dir/CON.txt", "file\nname", "//server/share", "dir/", "out.jsonl:stream",
      "C:/../out.jsonl", "out?.jsonl", "C:relative.jsonl",
    ] {
    assert_true(
      try {
        let _ = @config.file_path(path)
        false
      } catch {
        _ => true
      },
      msg=path,
    )
  }
}

///|
test "global file retention budget sums independent destinations" {
  let source : Json = {
    "receivers": { "otlp": {} },
    "exporters": {
      "file/a": { "path": "a.jsonl", "max_bytes": 100, "max_files": 3 },
      "file/b": { "path": "b.jsonl", "max_bytes": 100, "max_files": 3 },
    },
    "service": {
      "file_budget_bytes": 600,
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": [],
          "exporters": ["file/a", "file/b"],
        },
      },
    },
  }
  assert_eq(@config.parse(source.stringify()).file_budget_bytes, 600)
  assert_true(
    try {
      let _ = @config.parse(source.stringify().replace(old="600", new="599"))
      false
    } catch {
      _ => true
    },
  )
}

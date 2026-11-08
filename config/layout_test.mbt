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

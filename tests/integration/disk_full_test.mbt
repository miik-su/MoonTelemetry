///|
#cfg(all(target="native", not(platform="windows")))
async test "actual ENOSPC write failure is counted without leaking budget" {
  // Linux /dev/full rejects writes with ENOSPC without filling a filesystem.
  // The low-level destination is exercised directly; config preflight rejects
  // device outputs and is intentionally not bypassed in the running service.
  // Refuse a missing/regular/symlink path so a permissions failure cannot be
  // mistaken for the intended full-device write, or create a new /dev file.
  assert_eq(@fs.kind("/dev/full", follow_symlink=false), @fs.CharDevice)
  let budget = @component.MemoryBudget::new(1000000L)
  let destination = @exporter.Destination::new(File("/dev/full"), budget~)
  let input = @data.decode(
    Logs,
    @fs.read_file("tests/fixtures/logs.json").binary(),
    json=true,
  )
  assert_true(
    try {
      let _ = destination.send(input)
      false
    } catch {
      _ => true
    },
  )
  assert_eq(budget.used(), 0L)
  guard destination.stats() is Object(stats) else {
    abort("missing file failure stats")
  }
  assert_eq(stats.get("failedBatches"), Some(Json::string("1")))
  assert_eq(stats.get("rejectedRecords"), Some(Json::string("1")))
  assert_eq(stats.get("lastErrorClass"), Some(Json::string("file_io_error")))
  destination.close()
}

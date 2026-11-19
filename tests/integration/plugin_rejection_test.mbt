///|
priv struct RejectionProbe {
  rejected : Int32
}

///|
impl @component.Exporter for RejectionProbe with fn send(self, _input) {
  @async.sleep(15)
  self.rejected
}

///|
impl @component.Exporter for RejectionProbe with fn close(_self) {
  ()
}

///|
async test "invalid plugin rejection counts fail closed and expose safe duration statistics" {
  let input = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "scopeLogs": [
          { "logRecords": [{ "body": { "stringValue": "synthetic" } }] },
        ],
      },
    ],
  })
  for rejected in [-1, 2] {
    let budget = @component.MemoryBudget::new(1000000L)
    let destination = @exporter.Destination::new(
      Plugin(RejectionProbe::{ rejected, }),
      budget~,
    )
    assert_eq(destination.send(input), 1)
    assert_eq(budget.used(), 0L)
    guard destination.stats() is Object(stats) else { abort("missing stats") }
    assert_eq(stats.get("failedBatches"), Some(Json::string("1")))
    assert_eq(stats.get("successfulBatches"), Some(Json::string("0")))
    assert_eq(stats.get("rejectedRecords"), Some(Json::string("1")))
    assert_eq(
      stats.get("lastErrorClass"),
      Some(Json::string("invalid_rejected_count")),
    )
    assert_eq(stats.get("sendCalls"), Some(Json::string("1")))
    assert_eq(stats.get("activeSends"), Some(Json::number(0)))
    assert_false(stats.get("lastSendDurationMs") == Some(Json::string("0")))
    assert_eq(stats.get("totalSendDurationMs"), stats.get("maxSendDurationMs"))
    destination.close()
  }
}

///|
pub struct ReceiverStats {
  mut requests : Int64
  mut successes : Int64
  mut rejected : Int64
  mut timeouts : Int64
  mut connections : Int32
  mut last_status : Int32
}

///|
pub fn ReceiverStats::new() -> ReceiverStats {
  {
    requests: 0L,
    successes: 0L,
    rejected: 0L,
    timeouts: 0L,
    connections: 0,
    last_status: 0,
  }
}

///|
pub fn ReceiverStats::to_json(self : ReceiverStats) -> Json {
  {
    "requests": Json::string(self.requests.to_string()),
    "successfulRequests": Json::string(self.successes.to_string()),
    "rejectedRequests": Json::string(self.rejected.to_string()),
    "timeouts": Json::string(self.timeouts.to_string()),
    "activeConnections": Json::number(self.connections.to_double()),
    "lastRejectedStatus": Json::number(self.last_status.to_double()),
  }
}

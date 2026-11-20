///|
struct SelfMetrics {
  spec : @config.SelfMetricsSpec
  destination : @exporter.Destination
  mut snapshot_failures : Int64
}

///|
fn metric_point(
  name : String,
  unit : String,
  value : Int64,
  when_ns : String,
  start_ns? : String,
) -> Json {
  let point : Map[String, Json] = Map([
    ("timeUnixNano", Json::string(when_ns)),
    ("asInt", Json::string(value.to_string())),
  ])
  let metric : Map[String, Json] = Map([
    ("name", Json::string("moontelemetry." + name)),
    ("unit", Json::string(unit)),
  ])
  if start_ns is Some(start) {
    point["startTimeUnixNano"] = Json::string(start)
    metric["sum"] = {
      "aggregationTemporality": 2,
      "isMonotonic": true,
      "dataPoints": [Json::object(point)],
    }
  } else {
    metric["gauge"] = { "dataPoints": [Json::object(point)] }
  }
  Json::object(metric)
}

///|
fn Runtime::self_metrics_snapshot(
  self : Runtime,
  instance_id : String,
  started_ms : Int64,
  sampled_ms : Int64,
) -> @data.Envelope raise {
  let start_ns = (started_ms * 1000000L).to_string()
  let when_ns = (sampled_ms * 1000000L).to_string()
  let mut receiver_requests = 0L
  let mut receiver_successes = 0L
  let mut receiver_rejections = 0L
  let mut receiver_timeouts = 0L
  let mut active_connections = 0L
  for _, stats in self.receiver_stats {
    receiver_requests += stats.requests
    receiver_successes += stats.successes
    receiver_rejections += stats.rejected
    receiver_timeouts += stats.timeouts
    active_connections += stats.connections.to_int64()
  }
  let mut processed = 0L
  let mut filtered = 0L
  let mut processor_dropped = 0L
  let mut routing_failures = 0L
  let mut accepted_copies = 0L
  let mut delivered_copies = 0L
  let mut rejected_copies = 0L
  let mut overflow_copies = 0L
  let mut shutdown_lost_copies = 0L
  let mut retained_bytes = 0L
  for route in self.routes {
    processed += route.processed
    filtered += route.filtered
    processor_dropped += route.dropped
    routing_failures += route.routing_failures
    for output in route.outputs {
      let queue = output.0
      accepted_copies += queue.accepted
      delivered_copies += queue.delivered
      rejected_copies += queue.dropped
      overflow_copies += queue.overflow_dropped
      shutdown_lost_copies += queue.shutdown_lost
      retained_bytes += queue.bytes.to_int64()
    }
  }
  let metrics = []
  for
    (name, unit, value) in [
      ("receiver.requests", "{request}", receiver_requests),
      ("receiver.successes", "{request}", receiver_successes),
      ("receiver.rejections", "{request}", receiver_rejections),
      ("receiver.timeouts", "{request}", receiver_timeouts),
      ("processor.processed", "{record}", processed),
      ("processor.filtered", "{record}", filtered),
      ("processor.failed", "{record}", processor_dropped),
      ("routing.failed_outputs", "{batch}", routing_failures),
      ("output.accepted", "{copy}", accepted_copies),
      ("output.delivered", "{copy}", delivered_copies),
      ("output.rejected", "{copy}", rejected_copies),
      ("output.overflow", "{copy}", overflow_copies),
      ("output.shutdown_lost", "{copy}", shutdown_lost_copies),
    ] {
    metrics.push(metric_point(name, unit, value, when_ns, start_ns~))
  }
  for
    (name, unit, value) in [
      ("receiver.active_connections", "{connection}", active_connections),
      ("output.retained_bytes", "By", retained_bytes),
      ("memory.logical_used", "By", self.budget.used()),
      ("memory.logical_available", "By", self.budget.available()),
      ("memory.request_used", "By", self.requests.used()),
      ("memory.request_available", "By", self.requests.available()),
    ] {
    metrics.push(metric_point(name, unit, value, when_ns))
  }
  if @memory.rss_bytes() is Some(bytes) {
    metrics.push(metric_point("process.rss", "By", bytes, when_ns))
  }
  @data.from_json(Metrics, {
    "resourceMetrics": [
      {
        "resource": {
          "attributes": [
            {
              "key": "service.name",
              "value": { "stringValue": "moontelemetry" },
            },
            {
              "key": "service.version",
              "value": { "stringValue": Json::string(@component.version()) },
            },
            {
              "key": "service.instance.id",
              "value": { "stringValue": Json::string(instance_id) },
            },
          ],
        },
        "scopeMetrics": [
          {
            "scope": { "name": "moontelemetry.self" },
            "metrics": Json::array(metrics),
          },
        ],
      },
    ],
  })
}

///|
async fn export_self_metrics(
  runtime : Runtime,
  metrics : SelfMetrics,
  started : Int64,
) -> Unit {
  let mut last_sampled = started
  for ;; {
    @async.sleep(metrics.spec.interval_ms)
    // Keep cumulative points ordered even if the wall clock moves backwards.
    last_sampled = @async.now().max(last_sampled + 1L)
    let snapshot = runtime.self_metrics_snapshot(
      metrics.spec.instance_id,
      started,
      last_sampled,
    ) catch {
      _ => {
        metrics.snapshot_failures += 1L
        continue
      }
    }
    let _ = metrics.destination.send(snapshot) catch {
      error =>
        if @async.is_being_cancelled() {
          raise error
        } else {
          snapshot.count()
        }
    }
  }
}

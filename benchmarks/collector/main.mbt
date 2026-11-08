///|
async fn main {
  let args = @env.args()
  let seconds = if args.length() == 1 {
    5
  } else if args.length() == 2 && args[1] == "--soak" {
    60
  } else if args.length() == 3 && args[1] == "--seconds" {
    let mut seconds = 0
    for c in args[2] {
      guard c >= '0' && c <= '9' && seconds <= 86400 else {
        abort("--seconds must be an integer between 1 and 86400")
      }
      seconds = seconds * 10 + c.to_int() - 48
    }
    guard seconds >= 1 && seconds <= 86400 else {
      abort("--seconds must be an integer between 1 and 86400")
    }
    seconds
  } else {
    abort("usage: collector [--soak | --seconds 1..86400]")
  }
  let directory = @fs.tmpdir(prefix="moontelemetry-benchmark-")
  defer @fs.rmdir(directory, recursive=true)
  let temporary = @http.Server(@socket.Addr::new(2130706433U, 0))
  let port = temporary.addr.port()
  temporary.close()
  let cfg : Json = {
    "receivers": {
      "otlp": { "port": Json::number(port.to_double()), "max_body_bytes": 8192 },
    },
    "processors": {
      "batch": { "size": 128, "timeout_ms": 50, "max_bytes": 1048576 },
    },
    "exporters": {
      "file": {
        "path": Json::string(directory + "/telemetry.jsonl"),
        "max_bytes": 1048576,
        "max_files": 3,
      },
    },
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": ["batch"],
          "exporters": ["file"],
        },
      },
    },
  }
  let runtime = @service.Runtime::new(@config.parse(cfg.stringify()))
  let body = @fs.read_file("tests/fixtures/logs.json").binary()
  let samples : Array[Int64] = Array::make(10000, 0L)
  let totals = [0, 0, 0]
  let codes : Map[String, Int32] = Map([])
  let peak = [@memory.rss_bytes().unwrap_or(0L)]
  let start = @async.now()
  @async.with_task_group(async fn(group) {
    let collector = group.spawn(async fn() {
      runtime.run(stop_after_ms=seconds * 1000 + 500)
    })
    @async.sleep(50)
    for _ in 0..<8 {
      group.spawn_bg(async fn() {
        let mut retained_client : @http.Client? = None
        defer (if retained_client is Some(client) { client.close() })
        while @async.now() - start < seconds.to_int64() * 1000L {
          let before = @async.now()
          try {
            let client = match retained_client {
              Some(client) => client
              None => {
                let client = @http.Client("http://127.0.0.1:\{port}")
                retained_client = Some(client)
                client
              }
            }
            let response = client.post(
              "/v1/logs",
              body,
              extra_headers=Map::from_array([
                (
                  @http.CaseInsensitiveString("Content-Type"),
                  "application/json",
                ),
              ]),
            )
            let _ = client.read_all()
            let code = response.code.to_string()
            codes[code] = codes.get(code).unwrap_or(0) + 1
            if response.headers
              .get(@http.CaseInsensitiveString("Connection"))
              .unwrap_or("")
              .to_lower() ==
              "close" {
              client.close()
              retained_client = None
            }
            if response.code == 200 {
              totals[0] += 1
            } else {
              totals[1] += 1
            }
          } catch {
            _ => {
              totals[2] += 1
              if retained_client is Some(client) {
                client.close()
              }
              retained_client = None
              @async.sleep(10)
            }
          }
          let n = totals[0] + totals[1] + totals[2]
          samples[(n - 1) % samples.length()] = @async.now() - before
          if n % 128 == 0 {
            peak[0] = peak[0].max(@memory.rss_bytes().unwrap_or(0L))
          }
        }
      })
    }
    collector.wait()
  })
  let count = (totals[0] + totals[1] + totals[2]).min(samples.length())
  let values = samples[:count].to_owned()
  values.sort()
  let percentile = (p : Int32) => {
    if count > 0 {
      values[(count - 1) * p / 100]
    } else {
      0L
    }
  }
  let output : Json = {
    "seconds": Json::number(seconds.to_double()),
    "concurrency": 8,
    "accepted": Json::number(totals[0].to_double()),
    "rejected": Json::number(totals[1].to_double()),
    "transportErrors": Json::number(totals[2].to_double()),
    "httpStatusCounts": Json::object(
      codes.map((_, count) => Json::number(count.to_double())),
    ),
    "acceptedPerSecond": Json::number(
      totals[0].to_double() / seconds.to_double(),
    ),
    "latencySampleCount": Json::number(count.to_double()),
    "p50Ms": Json::string(percentile(50).to_string()),
    "p95Ms": Json::string(percentile(95).to_string()),
    "p99Ms": Json::string(percentile(99).to_string()),
    "peakHarnessRssBytes": Json::string(peak[0].to_string()),
    "finalHarnessRssBytes": Json::string(
      @memory.rss_bytes().unwrap_or(0L).to_string(),
    ),
    "collector": runtime.health(),
  }
  println(output.stringify())
}

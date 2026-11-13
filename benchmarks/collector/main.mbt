///|
async fn main {
  let opts = options(@env.args())
  let seconds = opts.seconds
  let directory = @fs.tmpdir(prefix="moontelemetry-benchmark-")
  defer @fs.rmdir(directory, recursive=true)
  let temporary = @http.Server(@socket.Addr::new(2130706433U, 0))
  let port = temporary.addr.port()
  temporary.close()
  let slow = @http.Server(@socket.Addr::new(2130706433U, 0))
  defer slow.close()
  let exporters : Map[String, Json] = {
    "file": {
      "path": Json::string(directory + "/telemetry.jsonl"),
      "max_bytes": 1048576,
      "max_files": 3,
    },
  }
  let destinations = [Json::string("file")]
  if opts.scenario == "slow" {
    exporters["otlp/slow"] = {
      "endpoint": Json::string("http://127.0.0.1:\{slow.addr.port()}"),
      "json": true,
      "attempt_timeout_ms": 200,
      "total_timeout_ms": 300,
      "retries": 0,
    }
    destinations.push(Json::string("otlp/slow"))
  }
  let cfg : Json = {
    "receivers": {
      "otlp": {
        "port": Json::number(port.to_double()),
        "max_connections": Json::number(opts.clients.max(32).to_double()),
      },
    },
    "processors": {
      "batch": { "size": 128, "timeout_ms": 50, "max_bytes": 1048576 },
    },
    "exporters": Json::object(exporters),
    "service": {
      "pipelines": {
        "logs": {
          "receivers": ["otlp"],
          "processors": ["batch"],
          "exporters": Json::array(destinations),
        },
      },
    },
  }
  let runtime = @service.Runtime::new(@config.parse(cfg.stringify()))
  let body = if opts.scenario == "large" {
    let payload = Array::make(524288, "x").join("")
    @utf8.encode(
      (
        {
          "resourceLogs": [
            {
              "scopeLogs": [
                {
                  "logRecords": [
                    { "body": { "stringValue": Json::string(payload) } },
                  ],
                },
              ],
            },
          ],
        } : Json).stringify(),
    )
  } else {
    @fs.read_file("tests/fixtures/logs.json").binary()
  }
  let samples : Array[Int64] = Array::make(10000, 0L)
  let sample_ids : Array[Int32] = Array::make(10000, 0)
  let next_sample = [128]
  let totals = [0, 0, 0]
  let codes : Map[String, Int32] = Map([])
  let peak = [@memory.rss_bytes().unwrap_or(0L)]
  let start = [0L]
  let last_progress = [0L]
  let recovered = [0L]
  let progress = @env.get_env_var("MOONTELEMETRY_BENCHMARK_PROGRESS_PATH")
  if progress is Some(path) {
    @fs.write_file(path, "")
  }
  @async.with_task_group(async fn(group) {
    let collector = group.spawn(async fn() { runtime.run() })
    let slow_task = group.spawn(async fn() {
      if opts.scenario == "slow" {
        slow.run_forever(async fn(_, reader, conn) {
          try {
            let _ = reader.read_all()
            if @async.now() - start[0] < seconds.to_int64() * 500L {
              @async.sleep(2000)
            }
            conn.send_response(
              200,
              "OK",
              extra_headers=Map::from_array([
                (
                  @http.CaseInsensitiveString("Content-Type"),
                  "application/json",
                ),
              ]),
            )
            conn.write(b"{}")
            conn.end_response()
          } catch {
            _ => ()
          } // Clients deliberately time out during the slow phase.
        })
      }
    })
    @async.with_timeout(5000, async fn() {
      for ;; {
        let ready = try {
          let probe = @http.Client("http://127.0.0.1:\{port}")
          defer probe.close()
          let response = probe.get("/health/ready")
          let _ = probe.read_all()
          response.code == 200
        } catch {
          _ => false
        }
        if ready {
          break
        }
        @async.sleep(10)
      }
    })
    start[0] = @async.now()
    @async.with_task_group(fn(clients) {
      for _ in 0..<opts.clients {
        clients.spawn_bg(async fn() {
          let mut retained_client : @http.Client? = None
          defer (if retained_client is Some(client) { client.close() })
          while @async.now() - start[0] < seconds.to_int64() * 1000L {
            let before = @async.now()
            let outcome = Some(
              @async.with_timeout(10000, async fn() {
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
                if response.headers
                  .get(@http.CaseInsensitiveString("Connection"))
                  .unwrap_or("")
                  .to_lower() ==
                  "close" {
                  client.close()
                  retained_client = None
                }
                response.code
              }),
            ) catch {
              _ => {
                if retained_client is Some(client) {
                  client.close()
                }
                retained_client = None
                None
              }
            }
            // Finish timeout cleanup before assigning one unique sample ID.
            // There is no suspension between counters and ring-buffer writes.
            match outcome {
              Some(code) => {
                codes[code.to_string()] = codes
                  .get(code.to_string())
                  .unwrap_or(0) +
                  1
                if code == 200 {
                  totals[0] += 1
                } else {
                  totals[1] += 1
                }
              }
              None => totals[2] += 1
            }
            let n = totals[0] + totals[1] + totals[2]
            samples[(n - 1) % samples.length()] = @async.now() - before
            sample_ids[(n - 1) % samples.length()] = n
            if n >= next_sample[0] {
              next_sample[0] = n + 128
              let now = @async.now()
              let rss = @memory.rss_bytes().unwrap_or(0L)
              peak[0] = peak[0].max(rss)
              let health = runtime.health()
              if opts.scenario == "slow" &&
                recovered[0] == 0L &&
                now - start[0] >= seconds.to_int64() * 500L {
                if health is Object(root) &&
                  root.get("pipelines") is Some(Array(pipes)) &&
                  pipes[0] is Object(pipe) &&
                  pipe.get("outputs") is Some(Array(outputs)) {
                  for output in outputs {
                    if output is Object(q) &&
                      q.get("destination") is Some(Object(d)) &&
                      d.get("componentId") == Some(Json::string("otlp/slow")) &&
                      d.get("successfulBatches") != Some(Json::string("0")) {
                      recovered[0] = now - start[0] - seconds.to_int64() * 500L
                    }
                  }
                }
              }
              if progress is Some(path) && now - last_progress[0] >= 10000L {
                last_progress[0] = now
                let snapshot : Json = {
                  "elapsedMs": Json::string((now - start[0]).to_string()),
                  "accepted": Json::number(totals[0].to_double()),
                  "rejected": Json::number(totals[1].to_double()),
                  "transportErrors": Json::number(totals[2].to_double()),
                  "rssBytes": Json::string(rss.to_string()),
                  "collector": health,
                }
                @fs.write_file(
                  path,
                  snapshot.stringify() + "\n",
                  append=true,
                  create_mode=OpenOrCreate,
                )
              }
            }
            if outcome is None {
              @async.sleep(10)
            }
          }
        })
      }
    })
    collector.cancel()
    collector.wait()
    slow_task.cancel()
  })
  let count = (totals[0] + totals[1] + totals[2]).min(samples.length())
  let completed = totals[0] + totals[1] + totals[2]
  for i in 0..<count {
    let sequence = completed - count + i + 1
    assert_eq(sample_ids[(sequence - 1) % samples.length()], sequence)
  }
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
    "concurrency": Json::number(opts.clients.to_double()),
    "scenario": Json::string(opts.scenario),
    "requestBodyBytes": Json::number(body.length().to_double()),
    "sourceRevision": Json::string(
      @env.get_env_var("MOONTELEMETRY_BENCHMARK_REVISION").unwrap_or(
        @env.get_env_var("GITHUB_SHA").unwrap_or("unrecorded"),
      ),
    ),
    "recordedAtUnixMs": Json::string(@async.now().to_string()),
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
    "latencySequenceVerified": true,
    "p50Ms": Json::string(percentile(50).to_string()),
    "p95Ms": Json::string(percentile(95).to_string()),
    "p99Ms": Json::string(percentile(99).to_string()),
    "peakHarnessRssBytes": Json::string(peak[0].to_string()),
    "finalHarnessRssBytes": Json::string(
      @memory.rss_bytes().unwrap_or(0L).to_string(),
    ),
    "slowRecoveryObservedMs": if recovered[0] > 0L {
      Json::string(recovered[0].to_string())
    } else {
      Json::null()
    },
    "collector": runtime.health(),
  }
  println(output.stringify())
  if @env.get_env_var("MOONTELEMETRY_BENCHMARK_RESULT_PATH") is Some(path) {
    @fs.write_file(path, output.stringify() + "\n")
  }
}

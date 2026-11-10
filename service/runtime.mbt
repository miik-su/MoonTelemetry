///|
struct Route {
  spec : @config.PipelineSpec
  input : @pipeline.Queue
  outputs : Array[(@pipeline.Queue, @exporter.Destination)]
  batch : @processor.Batch?
  pending : Array[@pipeline.Packet]
  mut complete : Bool
  mut filtered : Int64
  mut dropped : Int64
  mut processed : Int64
  mut shutdown_lost : Int64
  mut last_failure_component : String
  mut last_failure_class : String
  mut last_failure_ms : Int64
}

///|
pub struct Runtime {
  receiver_stats : Map[String, @otlp.ReceiverStats]
  budget : @component.MemoryBudget
  requests : @component.MemoryBudget
  workspace : Int64
  config : @config.Config
  routes : Array[Route]
  lifecycle : @component.Lifecycle
  mut draining : Bool
  destinations : Array[@exporter.Destination]
}

///|
pub fn Runtime::new(config : @config.Config) -> Runtime raise {
  let budget = @component.MemoryBudget::new(
    config.memory_budget_bytes.to_int64(),
  )
  let requests = @component.MemoryBudget::new(
    config.request_memory_budget_bytes.to_int64(),
  )
  let mut workspace = 0L
  let destinations = Map([])
  for id, spec in config.exporters {
    let policy = config.export_policies.get(id)
    destinations[id] = @exporter.Destination::new(
      spec,
      max_response_bytes=config.response_limits.get(id).unwrap_or(4194304),
      budget~,
      id~,
      total_timeout_ms=policy.map(p => p.total_timeout_ms).unwrap_or(30000),
      max_retry_delay_ms=policy.map(p => p.max_retry_delay_ms).unwrap_or(10000),
    )
  }
  let routes = []
  let receiver_stats = config.receivers.map((_, _) => @otlp.ReceiverStats::new())
  for spec in config.pipelines {
    workspace += config.queue_bytes.to_int64() * 3L
    let mut batch = None
    for p in spec.processors {
      if p is Batch(size~, timeout_ms~, max_bytes~) {
        workspace += max_bytes.to_int64() * 3L
        guard max_bytes <= config.queue_bytes else {
          raise @component.Configuration(
            "batch max_bytes must not exceed service.queue_bytes",
          )
        }
        batch = Some(
          @processor.Batch::new(spec.signal, size~, timeout_ms~, max_bytes~),
        )
      }
    }
    let outputs = spec.exporters.map(id => {
      (
        @pipeline.Queue::new(
          capacity=config.queue_capacity,
          max_bytes=config.queue_bytes,
          budget~,
        ),
        destinations[id],
      )
    })
    routes.push(Route::{
      spec,
      input: @pipeline.Queue::new(
        capacity=config.queue_capacity,
        max_bytes=config.queue_bytes,
        budget~,
      ),
      outputs,
      batch,
      pending: [],
      complete: false,
      filtered: 0L,
      dropped: 0L,
      processed: 0L,
      shutdown_lost: 0L,
      last_failure_component: "",
      last_failure_class: "",
      last_failure_ms: 0L,
    })
  }
  if workspace + config.request_memory_budget_bytes.to_int64() >=
    config.memory_budget_bytes.to_int64() {
    raise @component.Configuration(
      "global budget must cover workspaces, request budget and queue headroom",
    )
  }
  {
    budget,
    requests,
    workspace,
    config,
    receiver_stats,
    routes,
    lifecycle: @component.Lifecycle::new(),
    draining: false,
    destinations: destinations.values().collect(),
  }
}

///|
pub fn Runtime::submit(
  self : Runtime,
  receiver : String,
  input : @data.Envelope,
) -> Int32 raise {
  if self.lifecycle.state() != Running {
    raise @component.Stopped
  }
  let routes = self.routes.filter(r => {
    r.spec.signal == input.signal() && r.spec.receivers.contains(receiver)
  })
  if routes.is_empty() {
    raise @component.NotConfigured
  }
  for r in routes {
    for p in r.spec.processors {
      if p is Memory(limit) {
        @processor.admit(input, limit)
      }
    }
  }
  let packet = @pipeline.Packet::new(input)
  if self.config.delivery_policy == "reject_on_overload" &&
    routes.any(r => r.outputs.any(pair => !pair.0.can_accept(packet))) {
    raise @component.Backpressure(
      "an attached output is already full or draining",
    )
  }
  @pipeline.Fanout::new(routes.map(r => r.input)).submit(packet)
  0
}

///|
pub fn Runtime::health(self : Runtime) -> Json {
  {
    "status": Json::string(
      match self.lifecycle.state() {
        Created => "created"
        Running => "ready"
        Draining => "draining"
        Closed => "closed"
      },
    ),
    "logicalMemoryUsed": Json::string(self.budget.used().to_string()),
    "deliveryPolicy": Json::string(self.config.delivery_policy),
    "requestMemoryUsed": Json::string(self.requests.used().to_string()),
    "rssBytes": match @memory.rss_bytes() {
      Some(bytes) => Json::string(bytes.to_string())
      None => Json::null()
    },
    "receivers": Json::object(
      self.receiver_stats.map((_, stats) => stats.to_json()),
    ),
    "pipelines": Json::array(
      self.routes.map(r => {
        (
          {
            "id": Json::string(r.spec.id),
            "input": r.input.stats(),
            "filtered": Json::string(r.filtered.to_string()),
            "processorDropped": Json::string(r.dropped.to_string()),
            "processedRecords": Json::string(r.processed.to_string()),
            "processorFailedRecords": Json::string(r.dropped.to_string()),
            "lastFailureComponentId": Json::string(r.last_failure_component),
            "lastErrorClass": Json::string(r.last_failure_class),
            "lastFailureUnixMs": Json::string(r.last_failure_ms.to_string()),
            "shutdownLostRecords": Json::string(r.shutdown_lost.to_string()),
            "outputs": Json::array(
              r.outputs.map(pair => {
                let j = pair.0.stats()
                if j is Object(m) {
                  m["destination"] = pair.1.stats()
                }
                j
              }),
            ),
          } : Json)
      }),
    ),
  }
}

///|
fn emit(route : Route, packet : @pipeline.Packet) -> Unit {
  for pair in route.outputs {
    if !pair.0.push(packet) {
      pair.0.record_overflow(packet)
    }
  }
}

///|
fn stage(route : Route, input : @data.Envelope) -> Unit raise {
  if input.count() > 0 {
    route.pending.push(@pipeline.Packet::new(input))
  }
}

///|
async fn process_loop(runtime : Runtime, route : Route) -> Unit {
  for ;; {
    while !route.pending.is_empty() {
      emit(route, route.pending[0])
      let _ = route.pending.remove(0)
    }
    if route.batch is Some(batch) && batch.tick(now=@async.now()) is Some(out) {
      stage(route, out)
      continue
    }
    match route.input.take() {
      Some(packet) => {
        let mut failed_component = route.spec.id
        let mut error_class = "decode_error"
        try {
          let mut input = packet.decode()
          for i, p in route.spec.processors {
            failed_component = route.spec.processor_ids[i]
            error_class = "processor_error"
            match p {
              Transform(t) => input = t.process(input)
              Plugin(p) => input = p.process(input)
              Memory(limit) => @processor.admit(input, limit)
              Batch(..) => ()
            }
          }
          route.filtered += (packet.count() - input.count()).max(0).to_int64()
          failed_component = route.spec.id
          error_class = "batch_or_encoding_error"
          if route.batch is Some(batch) {
            for out in batch.push(input, now=@async.now()) {
              stage(route, out)
            }
          } else {
            stage(route, input)
          }
          route.input.finish()
          route.processed += input.count().to_int64()
        } catch {
          _ => {
            route.last_failure_component = failed_component
            route.last_failure_class = error_class
            route.last_failure_ms = @async.now()
            route.dropped += packet.count().to_int64()
            route.input.finish(rejected=packet.count())
          }
        }
      }
      None => {
        if runtime.draining {
          if route.batch is Some(batch) && batch.flush() is Some(out) {
            stage(route, out)
            continue
          }
          route.complete = true
          return
        }
        @async.sleep(10)
      }
    }
  }
}

///|
async fn export_loop(
  runtime : Runtime,
  route : Route,
  queue : @pipeline.Queue,
  destination : @exporter.Destination,
) -> Unit {
  for ;; {
    match queue.take() {
      Some(p) => {
        let rejected = destination.send(p.decode()) catch {
          e => {
            if @async.is_being_cancelled() {
              raise e
            }
            p.count()
          }
        }
        queue.finish(rejected~)
      }
      None => {
        if runtime.draining && route.complete {
          return
        }
        @async.sleep(10)
      }
    }
  }
}

///|
async fn workers(runtime : Runtime) -> Unit {
  @async.with_task_group(group => {
    for route in runtime.routes {
      group.spawn_bg(async fn() { process_loop(runtime, route) })
      for pair in route.outputs {
        group.spawn_bg(async fn() {
          export_loop(runtime, route, pair.0, pair.1)
        })
      }
    }
  })
}

///|
pub async fn Runtime::run(self : Runtime, stop_after_ms? : Int32) -> Unit {
  errdefer @async.protect_from_cancel(async fn() {
    self.lifecycle.close()
    close_destinations(self)
  })
  self.run_inner(stop_after_ms?)
}

///|
async fn close_destinations(runtime : Runtime) -> Unit {
  @async.with_task_group(group => {
    for destination in runtime.destinations {
      group.spawn_bg(async fn() {
        @async.with_timeout(runtime.config.shutdown_timeout_ms, async fn() {
          destination.close()
        }) catch {
          _ => ()
        }
      })
    }
  })
}

///|
async fn Runtime::run_inner(self : Runtime, stop_after_ms? : Int32) -> Unit {
  self.preflight()
  self.lifecycle.start()
  errdefer self.lifecycle.close()
  if !self.budget.reserve(self.workspace) {
    raise @component.Configuration(
      "global budget cannot cover pipeline workspaces",
    )
  }
  defer self.budget.release(self.workspace)
  let servers : Array[@http.Server] = []
  defer (for server in servers {
    server.close()
  })
  let active = self.config.receivers
    .iter()
    .filter(kv => self.routes.any(r => r.spec.receivers.contains(kv.0)))
    .collect()
  let addresses : Array[@socket.Addr] = []
  for pair in active {
    let address = @socket.Addr::resolve(pair.1.host, port=pair.1.port)
    if addresses.any(a => a == address) {
      raise @component.Configuration(
        "receiver names resolve to the same listener endpoint",
      )
    }
    addresses.push(address)
  }
  for address in addresses {
    servers.push(
      @http.Server(address) catch {
        _ =>
          raise @component.Configuration(
            "receiver endpoint unavailable: " + address.to_string(),
          )
      },
    )
  }
  let failure : Error? = try {
    let _ = @async.handle_cancellation(async fn() {
      let serve_all = async fn() {
        @async.with_task_group(group => {
          group.spawn_bg(async fn() { workers(self) })
          for i, pair in active {
            group.spawn_bg(async fn() {
              @otlp.serve(
                servers[i],
                pair.1,
                input => self.submit(pair.0, input),
                health=() => self.health(),
                budget=self.budget,
                requests=self.requests,
                limits=self.config.limits,
                stats=self.receiver_stats[pair.0],
              )
            })
          }
        })
      }
      match stop_after_ms {
        Some(ms) =>
          @async.with_timeout(ms, serve_all) catch {
            @async.TimeoutError => ()
            e => raise e
          }
        None => serve_all()
      }
    })
    None
  } catch {
    e => Some(e)
  }
  @async.protect_from_cancel(async fn() {
    self.lifecycle.drain()
    self.draining = true
    for server in servers {
      server.close()
    }
    for route in self.routes {
      route.input.stop()
    }
    @async.with_timeout(self.config.shutdown_timeout_ms, async fn() {
      workers(self)
    }) catch {
      _ =>
        for route in self.routes {
          route.input.discard_all()
          if route.batch is Some(batch) && batch.flush() is Some(e) {
            route.shutdown_lost += e.count().to_int64()
          }
          for p in route.pending {
            route.shutdown_lost += p.count().to_int64()
          }
          route.pending.clear()
          for pair in route.outputs {
            pair.0.discard_all()
          }
        }
    }
    for route in self.routes {
      for pair in route.outputs {
        pair.0.stop()
      }
    }
    self.lifecycle.close()
    close_destinations(self)
  })
  if failure is Some(e) {
    raise e
  }
}

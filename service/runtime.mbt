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
}

///|
pub struct Runtime {
  config : @config.Config
  routes : Array[Route]
  lifecycle : @component.Lifecycle
  mut draining : Bool
  destinations : Array[@exporter.Destination]
}

///|
pub fn Runtime::new(config : @config.Config) -> Runtime raise {
  let destinations = Map([])
  for id, spec in config.exporters {
    destinations[id] = @exporter.Destination::new(spec)
  }
  let routes = []
  for spec in config.pipelines {
    let mut batch = None
    for p in spec.processors {
      if p is Batch(size~, timeout_ms~, max_bytes~) {
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
        ),
        destinations[id],
      )
    })
    routes.push(Route::{
      spec,
      input: @pipeline.Queue::new(
        capacity=config.queue_capacity,
        max_bytes=config.queue_bytes,
      ),
      outputs,
      batch,
      pending: [],
      complete: false,
      filtered: 0L,
      dropped: 0L,
    })
  }
  {
    config,
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
    raise @component.Backpressure("no pipeline for receiver and signal")
  }
  for r in routes {
    for p in r.spec.processors {
      if p is Memory(limit) {
        @processor.admit(input, limit)
      }
    }
  }
  @pipeline.Fanout::new(routes.map(r => r.input)).submit(
    @pipeline.Packet::new(input),
  )
  0
}

///|
pub fn Runtime::health(self : Runtime) -> Json {
  {
    "status": Json::string(
      if self.lifecycle.state() == Running {
        "ready"
      } else {
        "draining"
      },
    ),
    "pipelines": Json::array(
      self.routes.map(r => {
        (
          {
            "id": Json::string(r.spec.id),
            "input": r.input.stats(),
            "filtered": Json::string(r.filtered.to_string()),
            "processorDropped": Json::string(r.dropped.to_string()),
            "outputs": Json::array(r.outputs.map(pair => pair.0.stats())),
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
      Some(packet) =>
        try {
          let mut input = packet.decode()
          for p in route.spec.processors {
            match p {
              Transform(t) => input = t.process(input)
              Plugin(p) => input = p.process(input)
              Memory(limit) => @processor.admit(input, limit)
              Batch(..) => ()
            }
          }
          route.filtered += (packet.count() - input.count()).max(0).to_int64()
          if route.batch is Some(batch) {
            for out in batch.push(input, now=@async.now()) {
              stage(route, out)
            }
          } else {
            stage(route, input)
          }
          route.input.finish()
        } catch {
          _ => route.input.finish(rejected=packet.count())
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
  @async.with_task_group(async fn(group) {
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
  self.lifecycle.start()
  errdefer self.lifecycle.close()
  let servers : Array[@http.Server] = []
  defer (for server in servers {
    server.close()
  })
  let active = self.config.receivers
    .iter()
    .filter(kv => self.routes.any(r => r.spec.receivers.contains(kv.0)))
    .collect()
  for pair in active {
    servers.push(
      @http.Server(@socket.Addr::resolve(pair.1.host, port=pair.1.port)),
    )
  }
  let _ = @async.handle_cancellation(async fn() {
    let serve_all = async fn() {
      @async.with_task_group(async fn(group) {
        group.spawn_bg(async fn() { workers(self) })
        for i, pair in active {
          group.spawn_bg(async fn() {
            @otlp.serve(
              servers[i],
              pair.1,
              input => self.submit(pair.0, input),
              health=() => self.health(),
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
            route.dropped += e.count().to_int64()
          }
          for p in route.pending {
            route.dropped += p.count().to_int64()
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
    @async.with_timeout(self.config.shutdown_timeout_ms, async fn() {
      for destination in self.destinations {
        destination.close()
      }
    }) catch {
      _ => ()
    }
  })
}

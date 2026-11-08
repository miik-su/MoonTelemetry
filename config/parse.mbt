///|
fn error(
  path : String,
  message : String,
) -> Unit raise @component.CollectorError {
  raise @component.Configuration(path + ": " + message)
}

///|
fn object(
  j : Json,
  path : String,
) -> Map[String, Json] raise @component.CollectorError {
  match j {
    Object(m) => m
    _ => {
      error(path, "expected object")
      Map([])
    }
  }
}

///|
fn fields(
  m : Map[String, Json],
  allowed : Array[String],
  path : String,
) -> Unit raise @component.CollectorError {
  for k, _ in m {
    if !allowed.contains(k) {
      error(path + "." + k, "unknown field")
    }
  }
}

///|
fn text(
  m : Map[String, Json],
  k : String,
  default : String,
  path : String,
) -> String raise @component.CollectorError {
  match m.get(k) {
    None => default
    Some(String(s)) => s
    _ => {
      error(path + "." + k, "expected string")
      ""
    }
  }
}

///|
fn number(
  m : Map[String, Json],
  k : String,
  default : Int32,
  path : String,
  max~ : Int32 = 1073741824,
  min~ : Int32 = 1,
) -> Int32 raise @component.CollectorError {
  match m.get(k) {
    None => default
    Some(Number(n, ..)) if n >= min.to_double() &&
      n <= max.to_double() &&
      n.to_int().to_double() == n => n.to_int()
    _ => {
      error(path + "." + k, "expected positive integer within limit")
      0
    }
  }
}

///|
fn boolean(
  m : Map[String, Json],
  k : String,
  default : Bool,
  path : String,
) -> Bool raise @component.CollectorError {
  match m.get(k) {
    None => default
    Some(True) => true
    Some(False) => false
    _ => {
      error(path + "." + k, "expected boolean")
      false
    }
  }
}

///|
fn names(
  m : Map[String, Json],
  k : String,
  path : String,
) -> Array[String] raise @component.CollectorError {
  let out = []
  match m.get(k) {
    Some(Array(a)) =>
      for v in a {
        match v {
          String(s) if !s.is_empty() && !out.contains(s) => out.push(s)
          _ => error(path + "." + k, "expected unique nonempty string IDs")
        }
      }
    _ => error(path + "." + k, "expected array")
  }
  out
}

///|
fn component_type(id : String) -> String {
  id.split("/").next().unwrap_or("").to_owned()
}

///|
fn action(j : Json, path : String) -> @processor.Action raise {
  let m = object(j, path)
  fields(m, ["action", "key", "value"], path)
  let key = text(m, "key", "", path)
  if key.is_empty() {
    error(path, "action key required")
  }
  let op = text(m, "action", "upsert", path)
  if op == "delete" {
    return @processor.Delete(key)
  }
  let value = m.get("value").unwrap_or(Json::null())
  // A generated AnyValue decoder validates the typed value later; require the
  // OTLP oneof shape up front, including for unused components.
  let v = object(value, path + ".value")
  fields(
    v,
    [
      "stringValue", "boolValue", "intValue", "doubleValue", "bytesValue", "arrayValue",
      "kvlistValue",
    ],
    path + ".value",
  )
  if v.length() != 1 {
    error(path, "value must contain one OTLP AnyValue field")
  }
  let _ = @data.from_json(Logs, {
    "resourceLogs": [
      {
        "resource": {
          "attributes": [{ "key": Json::string(key), "value": value }],
        },
      },
    ],
  })
  match op {
    "upsert" => @processor.Upsert(key, value)
    "insert" => @processor.Insert(key, value)
    "update" => @processor.Update(key, value)
    _ => {
      error(path, "unknown action")
      @processor.Delete(key)
    }
  }
}

///|
fn processor_spec(
  id : String,
  j : Json,
  factories : @component.Factories,
) -> ProcessorSpec raise {
  let m = object(j, "processors." + id)
  let p = "processors." + id
  match component_type(id) {
    "memory_limiter" => {
      fields(m, ["max_bytes"], p)
      Memory(number(m, "max_bytes", 16777216, p))
    }
    "batch" => {
      fields(m, ["size", "timeout_ms", "max_bytes"], p)
      Batch(
        size=number(m, "size", 512, p),
        timeout_ms=number(m, "timeout_ms", 1000, p, max=600000),
        max_bytes=number(m, "max_bytes", 16777216, p),
      )
    }
    "attributes" | "resource" => {
      fields(m, ["actions"], p)
      let a = match m.get("actions") {
        Some(Array(a)) => a.map(j => action(j, p + ".actions"))
        _ => {
          error(p, "actions array required")
          []
        }
      }
      Transform(
        if component_type(id) == "resource" {
          @processor.Resource(a)
        } else {
          @processor.Attributes(a)
        },
      )
    }
    "filter" => {
      fields(m, ["key", "equals"], p)
      let key = text(m, "key", "", p)
      if key.is_empty() || !m.contains("equals") {
        error(p, "key and equals required")
      }
      Transform(@processor.DropAttribute(key, m.get("equals").unwrap()))
    }
    _ => Plugin(factories.processor(component_type(id), j))
  }
}

///|
pub fn parse(
  source : String,
  env~ : (String) -> String? = _ => None,
  factories~ : @component.Factories = @component.Factories::new(),
) -> Config raise {
  validate_keys(source)
  let root = object(expand(@json.parse(source), env), "config")
  fields(root, ["receivers", "processors", "exporters", "service"], "config")
  let receivers = Map([])
  let processors = Map([])
  let exporters = Map([])
  let registry = @component.builtins()
  for
    id, j in object(root.get("receivers").unwrap_or(Json::null()), "receivers") {
    let p = "receivers." + id
    if !registry.contains(component_type(id), Receiver) {
      error(p, "unknown receiver type")
    }
    let m = object(j, p)
    fields(
      m,
      ["host", "port", "max_body_bytes", "timeout_ms", "max_connections"],
      p,
    )
    let host = text(m, "host", "127.0.0.1", p)
    if host.is_empty() {
      error(p, "host must not be empty")
    }
    receivers[id] = ReceiverSpec::{
      host,
      port: number(m, "port", 4318, p, max=65535),
      max_body_bytes: number(m, "max_body_bytes", 67108864, p),
      timeout_ms: number(m, "timeout_ms", 10000, p, max=600000),
      max_connections: number(m, "max_connections", 128, p, max=65536),
    }
  }
  for id, j in object(root.get("processors").unwrap_or({}), "processors") {
    processors[id] = processor_spec(id, j, factories)
  }
  for
    id, j in object(root.get("exporters").unwrap_or(Json::null()), "exporters") {
    let p = "exporters." + id
    let m = object(j, p)
    exporters[id] = match component_type(id) {
      "debug" => {
        fields(m, ["detailed"], p)
        Debug(detailed=boolean(m, "detailed", false, p))
      }
      "file" => {
        fields(m, ["path", "max_bytes", "max_files"], p)
        let path = text(m, "path", "", p)
        if path.is_empty() {
          error(p, "path required")
        }
        RotatingFile(
          path=file_path(path),
          max_bytes=number(m, "max_bytes", 67108864, p),
          max_files=number(m, "max_files", 5, p, max=100),
        )
      }
      "otlp" => {
        fields(m, ["endpoint", "json", "timeout_ms", "retries"], p)
        let endpoint = text(m, "endpoint", "", p)
        let _ = self_endpoint(endpoint)
        Otlp(
          endpoint~,
          json=boolean(m, "json", false, p),
          timeout_ms=number(m, "timeout_ms", 10000, p, max=600000),
          retries=number(m, "retries", 3, p, max=10, min=0),
        )
      }
      _ => Plugin(factories.exporter(component_type(id), j))
    }
  }
  let service = object(root.get("service").unwrap_or(Json::null()), "service")
  fields(
    service,
    [
      "pipelines", "queue_capacity", "queue_bytes", "shutdown_timeout_ms", "memory_budget_bytes",
      "request_memory_budget_bytes", "max_total_connections",
    ],
    "service",
  )
  let pipelines = []
  for
    id, j in object(
      service.get("pipelines").unwrap_or(Json::null()),
      "service.pipelines",
    ) {
    let p = "service.pipelines." + id
    let signal = match @data.signal_from_name(component_type(id)) {
      Some(s) => s
      None => {
        error(p, "unknown signal")
        @data.Signal::Logs
      }
    }
    let m = object(j, p)
    fields(m, ["receivers", "processors", "exporters"], p)
    let rs = names(m, "receivers", p)
    let ps = names(m, "processors", p)
    let es = names(m, "exporters", p)
    if rs.is_empty() || es.is_empty() {
      error(p, "receiver and exporter required")
    }
    for r in rs {
      if !receivers.contains(r) {
        error(p, "unknown receiver " + r)
      }
    }
    for e in es {
      if !exporters.contains(e) {
        error(p, "unknown exporter " + e)
      }
    }
    let specs = []
    for i, id in ps {
      match processors.get(id) {
        Some(spec) => {
          if spec is Batch(..) && i != ps.length() - 1 {
            error(p, "batch must be last")
          }
          specs.push(spec)
        }
        None => error(p, "unknown processor " + id)
      }
    }
    pipelines.push(PipelineSpec::{
      id,
      signal,
      receivers: rs,
      processors: specs,
      exporters: es,
    })
  }
  if pipelines.is_empty() {
    error("service.pipelines", "at least one pipeline required")
  }
  let file_paths : Map[String, Bool] = Map([])
  for _, spec in exporters {
    if spec is RotatingFile(path~, ..) {
      if file_paths.contains(path) {
        error("exporters", "duplicate normalized file path")
      }
      file_paths[path] = true
    }
  }
  let listeners : Array[(String, Int32)] = []
  for id, r in receivers {
    if pipelines.any(p => p.receivers.contains(id)) {
      for previous in listeners {
        if previous.1 == r.port &&
          (
            previous.0 == r.host.to_lower() ||
            ["0.0.0.0", "::", "[::]"].contains(previous.0) ||
            ["0.0.0.0", "::", "[::]"].contains(r.host)
          ) {
          error("receivers", "overlapping listener endpoints")
        }
      }
      listeners.push((r.host.to_lower(), r.port))
    }
  }
  let memory_budget_bytes = number(
    service, "memory_budget_bytes", 1073741824, "service",
  )
  let request_memory_budget_bytes = number(
    service, "request_memory_budget_bytes", 268435456, "service",
  )
  let max_total_connections = number(
    service,
    "max_total_connections",
    1024,
    "service",
    max=65536,
  )
  if request_memory_budget_bytes > memory_budget_bytes {
    error("service", "request budget exceeds global budget")
  }
  let mut connections = 0L
  for id, r in receivers {
    if pipelines.any(p => p.receivers.contains(id)) {
      connections += r.max_connections.to_int64()
      if r.max_body_bytes.to_int64() * 3L >
        request_memory_budget_bytes.to_int64() {
        error("receivers." + id, "request budget must cover three body buffers")
      }
    }
  }
  if connections > max_total_connections.to_int64() {
    error("service", "total receiver connection limit exceeded")
  }
  {
    memory_budget_bytes,
    request_memory_budget_bytes,
    max_total_connections,
    receivers,
    exporters,
    pipelines,
    queue_capacity: number(service, "queue_capacity", 64, "service", max=65536),
    queue_bytes: number(service, "queue_bytes", 33554432, "service"),
    shutdown_timeout_ms: number(
      service,
      "shutdown_timeout_ms",
      30000,
      "service",
      max=600000,
    ),
  }
}

///|
fn expand(
  j : Json,
  env : (String) -> String?,
) -> Json raise @component.CollectorError {
  match j {
    String(s) if s.has_prefix("${env:") && s.has_suffix("}") => {
      let name = s[6:s.length() - 1].to_owned()
      match env(name) {
        Some(v) => Json::string(v)
        None => {
          error("environment", "missing variable " + name)
          Json::null()
        }
      }
    }
    Object(m) => {
      let out = Map([])
      for k, v in m {
        out[k] = expand(v, env)
      }
      Json::object(out)
    }
    Array(a) => Json::array(a.map(j => expand(j, env)))
    _ => j
  }
}

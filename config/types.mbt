///|
pub(all) enum ProcessorSpec {
  Plugin(&@component.Processor)
  Transform(@processor.Transform)
  Memory(Int32)
  Batch(size~ : Int32, timeout_ms~ : Int32, max_bytes~ : Int32)
}

///|
pub(all) enum ExporterSpec {
  Plugin(&@component.Exporter)
  Debug(detailed~ : Bool)
  File(String)
  RotatingFile(path~ : String, max_bytes~ : Int32, max_files~ : Int32)
  Otlp(endpoint~ : String, json~ : Bool, timeout_ms~ : Int32, retries~ : Int32)
}

///|
pub struct ReceiverSpec {
  host : String
  port : Int32
  max_body_bytes : Int32
  timeout_ms : Int32
  max_connections : Int32
  header_timeout_ms : Int32
  body_idle_timeout_ms : Int32
  processing_timeout_ms : Int32
  health_enabled : Bool
  health_token : String
  auth_token : String
  allowed_ips : Array[String]
  allow_remote_without_auth : Bool
}

///|
pub struct PipelineSpec {
  id : String
  signal : @data.Signal
  receivers : Array[String]
  processors : Array[ProcessorSpec]
  processor_ids : Array[String]
  exporters : Array[String]
}

///|
pub struct Config {
  limits : @data.Limits
  response_limits : Map[String, Int32]
  memory_budget_bytes : Int32
  file_budget_bytes : Int32
  request_memory_budget_bytes : Int32
  max_total_connections : Int32
  receivers : Map[String, ReceiverSpec]
  exporters : Map[String, ExporterSpec]
  pipelines : Array[PipelineSpec]
  queue_capacity : Int32
  queue_bytes : Int32
  shutdown_timeout_ms : Int32
}

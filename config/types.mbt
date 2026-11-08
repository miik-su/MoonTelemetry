///|
pub(all) enum ProcessorSpec {
  Transform(@processor.Transform)
  Memory(Int32)
  Batch(size~ : Int32, timeout_ms~ : Int32, max_bytes~ : Int32)
}

///|
pub(all) enum ExporterSpec {
  Debug(detailed~ : Bool)
  File(String)
  Otlp(endpoint~ : String, json~ : Bool, timeout_ms~ : Int32, retries~ : Int32)
}

///|
pub struct ReceiverSpec {
  host : String
  port : Int32
  max_body_bytes : Int32
  timeout_ms : Int32
  max_connections : Int32
}

///|
pub struct PipelineSpec {
  id : String
  signal : @data.Signal
  receivers : Array[String]
  processors : Array[ProcessorSpec]
  exporters : Array[String]
}

///|
pub struct Config {
  receivers : Map[String, ReceiverSpec]
  exporters : Map[String, ExporterSpec]
  pipelines : Array[PipelineSpec]
  queue_capacity : Int32
  queue_bytes : Int32
  shutdown_timeout_ms : Int32
}

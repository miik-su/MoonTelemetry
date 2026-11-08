///|
pub struct ComponentDescriptor {
  name : String
  kind : Kind
  description : String
}

///|
pub fn catalog() -> Array[ComponentDescriptor] {
  [
    {
      name: "otlp",
      kind: Receiver,
      description: "OTLP HTTP JSON/protobuf receiver",
    },
    {
      name: "payload_size_guard",
      kind: Processor,
      description: "Serialized request/result size admission guard",
    },
    {
      name: "memory_limiter",
      kind: Processor,
      description: "Compatibility alias for payload_size_guard",
    },
    {
      name: "resource",
      kind: Processor,
      description: "Resource attribute actions",
    },
    {
      name: "attributes",
      kind: Processor,
      description: "Record and data point attribute actions",
    },
    {
      name: "filter",
      kind: Processor,
      description: "Drop records matching an attribute value",
    },
    {
      name: "redaction",
      kind: Processor,
      description: "Mask sensitive nested attributes and optional log bodies",
    },
    {
      name: "batch",
      kind: Processor,
      description: "Bounded size/time batching",
    },
    {
      name: "debug",
      kind: Exporter,
      description: "Console summaries or detailed telemetry",
    },
    {
      name: "file",
      kind: Exporter,
      description: "Bounded rotating JSONL files",
    },
    {
      name: "otlp",
      kind: Exporter,
      description: "OTLP HTTP persistent connections and bounded retries",
    },
  ]
}

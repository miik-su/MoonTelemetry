///|
async fn main {
  let resource = @resource.Resource::builder_empty()
    .with_service_name("moontelemetry-demo")
    .build()
  guard @otlp.SpanExporter::builder().with_http().build() is Ok(traces) else {
    abort("invalid trace exporter configuration")
  }
  guard @otlp.LogExporter::builder().with_http().build() is Ok(logs) else {
    abort("invalid log exporter configuration")
  }
  guard @otlp.MetricExporter::builder().with_http().build() is Ok(metrics) else {
    abort("invalid metric exporter configuration")
  }
  @sdk.set_tracer_provider(
    @sdk.tracer_provider_builder()
    .with_resource(resource)
    .with_batch_exporter(traces.into_span_exporter())
    .build(),
  )
  @sdk.set_logger_provider(
    @sdk.logger_provider_builder()
    .with_resource(resource)
    .with_batch_exporter(logs.into_log_exporter())
    .build(),
  )
  @sdk.set_meter_provider(
    @sdk.meter_provider_builder()
    .with_resource(resource)
    .with_periodic_reader(metrics.into_periodic_reader(interval_millis=60000))
    .build(),
  )
  let span = @otel.tracer("demo").start("checkout")
  let logger = @otel.logger("demo")
  let record = logger.create_log_record()
  record.set_body(String("checkout accepted"))
  record.set_severity_number(Info)
  let context = span.span_context()
  record.set_trace_context(
    context.trace_id(),
    context.span_id(),
    trace_flags=Some(context.trace_flags()),
  )
  logger.emit(record)
  @otel.meter("demo").u64_counter("checkout.attempts").build().add(1UL)
  span.end()
  @async.sleep(0)
  @sdk.force_flush()
  @sdk.shutdown()
  println("SDK demo flushed logs, metrics and traces")
}

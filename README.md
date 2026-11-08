# MoonTelemetry

MoonBit 原生可观测性 Collector：接收 Logs、Metrics、Traces，按配置处理，
通过独立有界队列转发到 Debug、JSONL 文件和 OTLP/HTTP 目标。

核心、网络服务、CLI、处理器、演示和基准均使用 MoonBit；网络与协议依赖
moonbitlang/async 和 moonbit-community/opentelemetry 的生成模型。

## 运行

需要 MoonBit Native 工具链及 C 编译器。本次验证工具链：
`moon 0.1.20261023`，Windows x64 / MSVC。

```sh
moon update
moon run cmd/moontelemetry -- validate --config examples/collector.json
moon run cmd/moontelemetry -- run --config examples/collector.json
```

另开终端运行真正的 MoonBit SDK 应用：

```sh
moon run examples/sdk-demo
```

默认 Collector 监听 `127.0.0.1:4318`，结果追加到 `telemetry.jsonl`。
SDK demo 使用 HTTP/Protobuf，默认目标为本机 4318；SDK 自身支持通过
`OTEL_EXPORTER_OTLP_ENDPOINT` 设置目标。HTTP/JSON 的三信号链路另有 SDK
golden fixtures 集成验证。查看状态：`GET /health`。

```sh
moon run cmd/moontelemetry -- version
moon run cmd/moontelemetry -- components
moon run benchmarks --release
```

## 支持范围

| 部分 | 当前实现 |
| --- | --- |
| Receiver | POST /v1/logs、/v1/metrics、/v1/traces；JSON、Protobuf、gzip |
| Processor | memory_limiter、resource、attributes、filter、batch |
| Exporter | debug、追加 JSONL、OTLP HTTP/JSON 和 HTTP/Protobuf |
| Pipeline | 按顺序处理、多 receiver、独立目标队列、重试、有界关闭 |
| 扩展 | MoonBit Processor/Exporter trait + 配置工厂注册 |
| 配置 | 严格 JSON、默认值、引用校验、重复键校验、环境变量 |

当前是首个可运行版本，不宣称完整 OTLP 一致性认证或生产环境长期稳定性。
详细协议边界见 [COMPATIBILITY.md](COMPATIBILITY.md)，运行与交付语义见
[docs/OPERATIONS.md](docs/OPERATIONS.md)，验证证据见 [docs/VALIDATION.md](docs/VALIDATION.md)。

## 配置

完整示例见 [examples/collector.json](examples/collector.json)。组件 ID 可使用
`otlp/secondary`、`file/archive` 等形式；pipeline ID 可使用 `logs/a`。
仅 pipeline 引用的 receiver 会监听。batch 必须排在处理器列表末尾。
属性值采用 OTLP AnyValue，例如 `{"stringValue":"development"}`。
filter 的 `key` + `equals` 删除具有指定记录属性的数据；指标过滤以数据点为单位。
`${env:VARIABLE}` 可替换整个字符串值；不展开任意字符串模板。

默认请求体上限 64 MiB（压缩前后分别检查）；默认每个队列 64 个批次、32 MiB
序列化数据。`memory_limiter.max_bytes` 是单次请求/处理结果的序列化字节预算，
不是 RSS 限制。内存预算和过载策略见运行文档。

## 开发和关键验证

```sh
moon check
moon test -p core/data
moon test -p processor
moon test -p config
moon test -p tests/integration
moon fmt
moon info
```

本次开发按用户要求仅执行相关包和关键集成测试，没有运行全量测试。
API 接口由 `moon info` 生成在各包的 `pkg.generated.mbti` 中。
架构参考 Go OpenTelemetry Collector 的组件与 service pipeline 分离方式；
详见 [ARCHITECTURE.md](ARCHITECTURE.md)。

Apache-2.0。上游 fixtures 的来源见 [tests/fixtures/README.md](tests/fixtures/README.md)。

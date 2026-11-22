# 条件路由与自身指标

```sh
moon run cmd/moontelemetry --target native -- validate --config examples/routing-self-metrics.json
```

[示例配置](../examples/routing-self-metrics.json)将日志脱敏并分批，按严重度分流到两个
Debug 目标。运行示例时，在 14318 端口提供独立 OTLP 接收端，或修改 `otlp/self.endpoint`。
配置校验检查结构和预算，连接由运行时建立。

## 条件路由

在 `service.pipelines.<id>.routing` 配置 `rules` 和 `default_exporters`。
每条规则包含 `exporter` 和 [过滤器表达式](FILTERING.md) `condition`。每管线允许
1–16 条规则、最多 16 个目标。规则和兜底只能引用管线挂载的目标。兜底至少一个，
每个挂载目标都要被规则或兜底引用。

Logs、Span、指标点分别在处理与 Batch 之后匹配。每条记录发往所有命中的目标，
同一目标最多一份。只有一条规则都未命中才使用兜底。一个目标可同时作为匹配目标和
兜底。每份副本保留其所属资源、作用域和指标元数据，空组随未选中的记录一起移除。
普通管线省略 `routing` 时继续整批广播。

资源属性和日志严重度按现有过滤语义解释。脱敏删除的字段无法参与匹配。
`processedRecords` 按管线记录计数，各出口的 `accepted`、`delivered` 和
`overflowDropped` 分别按目标副本计数。`routingFailedOutputs` 记录无法构建的
目标批次；失败目标不会收到原始未筛选数据。路由消耗额外工作预算。

`reject_on_overload` 在入队前保守检查所有挂载目标，此时尚未执行处理和条件匹配。
目标暂时拥堵可能拒收一条本来会发往其他目标的记录。HTTP 200 仍表示易失输入入队。

## 自身指标

省略 `service.self_metrics` 时关闭。启用时指定一个独立的 `otlp/<id>` 出口，不得
挂载到业务管线。每个同时运行的实例使用唯一且不含敏感信息的 `instance_id`，
允许 1–128 个 ASCII 字母、数字、点、下划线或连字符。默认间隔 30000 毫秒，
允许 1000–3600000 毫秒。一次发送完成后再等待下一间隔，最多一个批次在途。

发送到配置基址下的 `/v1/metrics`，支持 JSON 和 Protobuf。复用已有 HTTP 期限、
重试和全局逻辑预算。自身快照不走业务队列，也不把该出口的发送数纳入下一次快照。
请指向独立接收端，避免把指标经外部配置转发回同一实例。健康 JSON 的
`selfMetrics` 提供诊断。退出时停止采样并取消在途发送，最后一次快照不保证送达。

| 前缀 | 类型 | 含义 |
| --- | --- | --- |
| `moontelemetry.receiver.*` | 累计 Sum、活动连接 Gauge | 接收请求、成功、拒绝和超时；分类沿用接收统计 |
| `moontelemetry.processor.*` | 累计 Sum | 处理、过滤与失败记录 |
| `moontelemetry.routing.failed_outputs` | 累计 Sum | 无法构建的目标批次 |
| `moontelemetry.output.*` | 累计 Sum、保留字节 Gauge | 目标副本与队列字节，跨目标汇总 |
| `moontelemetry.memory.*`、`moontelemetry.process.rss` | Gauge | 逻辑及请求预算，平台支持时报告 RSS |

累计值随进程重启重置。资源属性固定为服务名、版本和管理员配置的实例 ID。不附带
请求、目标、管线或用户遥测的标签。名称属于项目自身，不承诺与 Go Collector 的
内部指标同名。模型按 [OTLP Metrics 数据模型](https://opentelemetry.io/docs/specs/otel/metrics/data-model/) 编码。

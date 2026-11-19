# 有界过滤条件

Filter 是排除处理器：条件为 true 的 LogRecord、Span 或 Metric DataPoint 被删除。
它不选择导出目标，不提供路由，也不执行脚本或正则表达式。
原有 `{"key":"drop","equals":{"boolValue":true}}` 配置仍有效。

新条件示例（放入 processors，并在 pipeline 中引用 filter）：

```json
{
  "filter": {
    "all": [
      { "resource_attribute": "service.name", "operator": "prefix", "value": "prod-" },
      { "field": "severityNumber", "operator": "gte", "value": 13 },
      { "attribute": "discard", "operator": "exists" }
    ]
  }
}
```

上述条件同时命中才删除，不满足条件的普通生产日志保留。

| 条件 | 语义 |
| --- | --- |
| all / any | 1..16 个非空子条件，分别为与／或 |
| not | 一个条件取反，不能混合其他字段 |
| attribute | 记录属性；Metrics 按数据点属性判断，不匹配 Metric 名称 |
| resource_attribute | 仅使用当前资源组属性，不继承其他资源组 |
| operator: exists | 属性键存在，不接受 value |
| operator: equals | value 为一个 OTLP AnyValue，按规范化模型比较，包括精确整数 |
| operator: prefix | value 为非空字符串，仅匹配 stringValue 属性 |
| field: severityNumber | Logs 的 equals/gte/lte，阈值为整数 0..24，缺省严重度为 0 |

属性键和前缀区分大小写。重复属性键中任一个值匹配即为命中。
缺失属性或值类型不匹配时，叶条件为 false；not 正常取反。
严重度叶条件对非 Logs 为 false，因此 not 严重度条件用于其他信号可能命中；
应将严重度过滤仅用于 Logs pipeline。未来数字严重度按实际数值比较。

表达式最多 8 层、64 个节点，每组最多 16 个子条件；键最多 256、
前缀最多 1024（均按 MoonBit 字符串长度）。这是成本边界，不是 CPU 时间承诺。
组、叶条件、旧 key/equals 格式不能混写；未知字段与运算符在配置阶段拒绝。

处理器按顺序执行。Redaction 在过滤之前时，条件看到脱敏后的属性；过滤不会恢复
被删除字段，也不会跳过后续安全处理器。HTTP 200 仍只表示进入易失输入队列。
健康状态的 filtered 记录过滤减少的记录数，与发送失败和输出队列溢出分开。

证据：processor/filter_test.mbt（资源隔离、精确整数、三信号／五种指标、复杂度），
config/filter_test.mbt（新旧配置边界）。未知 protobuf 字段仍遵循
[协议兼容说明](../COMPATIBILITY.md)，不提供透明保留保证。

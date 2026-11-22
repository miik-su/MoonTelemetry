# 0.1.4 条件路由和自身指标验证

本地 Windows x64／MSVC／Native，moon 0.1.20261104、moonc 0.10.20+65efd5b93。
被测提交为 `e1724e306074eb4ccd00d28007f25c9bd86f8761`。

| 项目 | 实际结果 |
| --- | --- |
| config、processor、service、tests/integration | 54 项通过，0 项失败 |
| 路由 | 同一批两条日志产生三个目标副本，重叠规则同目标仅一份；脱敏后匹配、兜底、空资源组清除、队列计数与预算释放通过 |
| 模型 | 五类指标和 Span 的选择、指标点拆分、空指标组清除与 Protobuf 往返通过 |
| 自身指标 | JSON 和 Protobuf 各观察两次推送。每种编码首批被拒绝、下批成功。累计值、时间戳、Gauge、关闭后预算及业务载荷隔离通过 |
| 示例配置 | CLI 校验通过，识别一条管线 |
| 打包预检 | 通过许可声明、路径与版本核对 |

[结构化结果](focused.json) · [本地打包预检](distribution.raw.json)

合成测试使用回环 HTTP。范围为关键受影响的包及示例，未运行全量测试或生产容量测试。
归档哈希仅对应本次本地打包。注册表可用性见[发布说明](../../DISTRIBUTION.md)。

```sh
moon test config processor service tests/integration --target native
moon run cmd/moontelemetry --target native -- validate --config examples/routing-self-metrics.json
moon run tools/check_distribution.mbtx --target native
```

# Mooncakes 0.1.4 独立安装验证

2026-11-28 发布 [`miik-su/moontelemetry@0.1.4`](https://mooncakes.io/docs/miik-su/moontelemetry%400.1.4)。
使用干净检出 `69fdbb66904b91ed289dafed1faa1ff2a1155b88`，对应
[GitHub Release v0.1.4](https://github.com/miik-su/MoonTelemetry/releases/tag/v0.1.4)。
Mooncakes 在源码与归档解包编译通过后返回 HTTP 200。

在独立模块中执行 `moon add miik-su/moontelemetry@0.1.4`，
工具链实际从注册表下载了该版本，`moon tree` 确认使用该版本。
下载 ZIP 的 SHA-256 与本次上传 ZIP 一致。随后在 Windows Native
运行 `moon run . --target native`，导入公开的 `core/data` 包，
成功完成一条合成日志的 OTLP Protobuf 编解码往返。

复现入口见[作为库使用](../../DISTRIBUTION.md#作为库使用)。
[结构化验证记录](consumer-install.json)保留了提交号、命令和归档摘要。
本轮验证了注册表安装及最小示例，未重复运行全量测试。

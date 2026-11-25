# 2026-11-25 恢复检查

验证源码 `a8fb17fb711d0d0fd00cb8aeb296331c1f613409`。
工具链为 moon 0.1.20261104 / moonc 0.10.20+65efd5b93，Native。

| 检查 | 实际观察 |
| --- | --- |
| OTLP 连接恢复 | Windows/MSVC 定向测试通过。接收端两次读取请求后关闭连接，导出器仅重试一次，计入一条拒绝。接收端恢复后，下一批成功且预算归零。 |
| Linux 满盘恢复 | GitHub Ubuntu Runner 的 64 KiB 独立 tmpfs 写满后，一个已接收记录在文件出口计入丢弃。释放占位文件后，下一条记录成功写出。 |
| Linux 退出与重启 | SIGINT、SIGTERM 下待处理记录均成功写出。强杀及重启用例确认易失记录不会自动恢复。 |

证据见 [Linux 工作流](https://github.com/miik-su/MoonTelemetry/actions/runs/45557780003)
和[日志原始 JSON](linux-faults.raw.json)。满盘用例实际写满小型测试挂载，
并通过 Collector 入口与真实文件出口验证。主机卷耗尽、保留策略和服务恢复
仍取决于目标部署配置。

```sh
moon test tests/integration/exporter_recovery_test.mbt --target native
```

Linux 工作流通过 `MOONTELEMETRY_TEST_TMPFS=1` 启用挂载用例，
普通本地测试无需挂载权限。只执行关键测试。

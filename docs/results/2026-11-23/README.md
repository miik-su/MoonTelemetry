# 0.1.4 混合信号与部署维护验证

## 独立进程

北京时间 11 月 22 日采集。Windows x64 / MSVC / Native，moonc 0.10.20+65efd5b93。
源码 `64e1786348c57b2a7bf334e400ac862bb04a700c`，干净工作树。
Collector 是单独启动的进程。测试进程同时发送三种合成信号，并用两个独立 HTTP
接收监听器核对输出。每个客户端请求完成后暂停 25 毫秒。

| 信号 | 接收记录 | 目标一 | 目标二 |
| --- | ---: | ---: | ---: |
| Logs | 7,608 | 7,608 | 7,608 |
| Metric points | 9,505 | 9,505 | 9,505 |
| Spans | 5,715 | 5,715 | 5,715 |

实际负载持续 60.027 秒。拒绝请求和传输／响应错误均为 0。Collector CPU 时间增量
12,203 毫秒，约每秒一次采样的 RSS 峰值 11,128,832 字节。两个目标的实际计数
与 Collector 各队列的送达统计一致。[本地原始 JSON](mixed-60.raw.json)

同源码的 [Windows/Linux 5 秒 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/45039252008)
均通过。负载和接收端与 Collector 同主机。这是有节奏的守恒与资源观测，
尚未测多小时、吞吐上限或生产容量。手动 workflow 可配置 1 至 14,400 秒。

```powershell
moon build cmd/moontelemetry --target native --release
$env:MOONTELEMETRY_MIXED_SECONDS = '60'
moon run tools/check_mixed_process.mbtx --target native
```

## 部署与启动链

| 检查 | 可核查证据 |
| --- | --- |
| Linux Compose/Nginx/TLS | [运行记录](https://github.com/miik-su/MoonTelemetry/actions/runs/45182228428)。源码 `72c6682fd03c19167fc6d03027c057255f90d081`。临时镜像和证书，验证受信 TLS、健康路径隔离、拒绝 GET 和过大请求、令牌、脱敏以及停止刷新。 |
| Windows 附加控制台 | [原始结果](windows-console.raw.json)。源码 `df6fc32fc7b82e11ed195009c57b316356867525`。实际 Ctrl+Break，收到 `STATUS_CONTROL_C_EXIT`，一条确认接收的待处理日志写出。 |
| 依赖锁 | [CycloneDX](dependencies.cdx.json)。同一 `df6fc32` 源码核对三份缓存 ZIP 的 SHA-256、已安装 manifest 和传递导入。 |
| 上游模型 | 核对 40 个描述符，6 项关键协议测试通过。在另一个检出中升级 protobuf 0.2.0，保留适配通过 6 项，删除 zigzag 适配时现有回归失败。[评估与依赖 PR 记录](../../UPSTREAM_ADAPTERS.md) |

修复 Linux 解包后的执行权限后，源码 `0c519a205c1f344dac721be4d5b97195a800b769`
通过 [Compose/TLS](https://github.com/miik-su/MoonTelemetry/actions/runs/45183294112)、
[Linux 生命周期](https://github.com/miik-su/MoonTelemetry/actions/runs/45183294129) 和
[双平台互操作](https://github.com/miik-su/MoonTelemetry/actions/runs/45183294370)。
这批 CI 在执行前核对编译器和 core 归档。首次引入锁的
[`df6fc32` 运行](https://github.com/miik-su/MoonTelemetry/actions/runs/45182925669)
保留 Linux 执行权限失败记录。

另在干净工作区 `338a294771e89c3d7ca33daa4c204378ee9a2361` 完成 0.1.4
[本地打包预检](distribution.raw.json)，核对 280 个归档条目及 CLI 版本。
随后从 `b76c344e4c2096351ec05a419dafcb3d3f85aed3` 重新生成
[候选归档](source-candidate.raw.json)。将 ZIP 解包到独立目录后，Native 编译检查通过，
CLI 输出 `MoonTelemetry 0.1.4`。Mooncakes 发行保留到最后一步。

模型测试使用固定合成样本，部署测试使用 GitHub Runner。目标环境的磁盘耗尽恢复、
Windows 服务管理器、多小时负载与生产证书轮换仍需单独核对。本轮未运行全量测试。

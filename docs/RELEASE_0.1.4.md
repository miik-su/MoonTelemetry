# 0.1.4 发布候选核对

源码标签 [v0.1.4-rc.1](https://github.com/miik-su/MoonTelemetry/tree/v0.1.4-rc.1)
对应 `b76c344e4c2096351ec05a419dafcb3d3f85aed3`。模块和 CLI 版本为 0.1.4。
GitHub Release 和 Mooncakes 正式发行均待完成。

| 原计划验收项 | 已核对的工作与证据 |
| --- | --- |
| M01 初审状态 | [维护记录](MAINTENANCE.md)记录参赛者提供的初审结果。通知原件与确切日期未提供。 |
| M02 快速开始 | 候选的 [双平台关键 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864638)验证独立 SDK 和 Collector，文件实际收到三种信号。 |
| M03、M07 未完成项和路线 | [维护记录](MAINTENANCE.md)列出后续目标环境工作和上线前验证。 |
| M04 许可和依赖 | [契约](CONTRACTS.md)、[第三方声明](../THIRD_PARTY_NOTICES.md)及[依赖清单](results/2026-11-23/dependencies.cdx.json)。 |
| M05 关键 CI | 候选 [关键检查](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864638)、[官方 Collector 互操作](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864546)、[生命周期](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864547)、[固定语料和变异回归](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864581)通过。 |
| M06 归档 | 同一候选的[打包结果](results/2026-11-23/source-candidate.raw.json)。ZIP 独立解包后检查通过，CLI 输出 0.1.4。 |
| M08 源码候选 | 已固定 Git 标签。长期负载、主机验证和注册表状态分别记录。 |

## 长期负载与部署

2026-11-25 在 Windows 完成候选的一小时合成混合负载。
运行工作区源码 `aad2836eb33c43bc9206ee786e6d172137f92341`，与标签仅有文档
和验证记录差异。两个目标各送达 1,375,961 条记录，0 拒绝请求、0 传输／响应错误。
见 [一小时验证及原始结果](results/2026-11-25/README.md)。

4 小时合成负载与 24 小时目标环境测试尚未执行。Linux Compose/TLS 和 Windows
控制台已有合成验收。生产证书、服务管理器、容量及磁盘策略须结合实际目标主机核对。
Prometheus、OTLP/gRPC 和持久化队列仍属于后续功能评估。

[2026-11-25 恢复验证](results/2026-11-25/README.md)补充真实连接断开和 Linux
限额卷写满后的恢复用例。规则集未修改，当前仍保持仓库的既有合并流程。

正式发行时使用固定源码，先核对关键测试和包内容，再记录 GitHub Release。
最后使用有 `miik-su` 命名空间权限的身份发布 Mooncakes，并在独立调用方安装验证。

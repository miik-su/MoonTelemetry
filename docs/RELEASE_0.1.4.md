# 0.1.4 发布候选核对

正式 [GitHub Release v0.1.4](https://github.com/miik-su/MoonTelemetry/releases/tag/v0.1.4)
于 2026-11-26 发布，标签指向 `69fdbb66904b91ed289dafed1faa1ff2a1155b88`。
模块和 CLI 版本均为 0.1.4。
候选 [v0.1.4-rc.1](https://github.com/miik-su/MoonTelemetry/tree/v0.1.4-rc.1)
仍指向 `b76c344e4c2096351ec05a419dafcb3d3f85aed3`。
Mooncakes 预检已通过源码与解包编译检查，注册表要求使用有 `miik-su` 命名空间
权限的登录。模块仍未发布，独立调用方的注册表安装验证待发布后执行。

| 原计划验收项 | 已核对的工作与证据 |
| --- | --- |
| M01 初审状态 | [维护记录](MAINTENANCE.md)记录参赛者提供的初审结果。通知原件与确切日期未提供。 |
| M02 快速开始 | 候选的 [双平台关键 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864638)验证独立 SDK 和 Collector，文件实际收到三种信号。 |
| M03、M07 未完成项和路线 | [维护记录](MAINTENANCE.md)列出后续目标环境工作和上线前验证。 |
| M04 许可和依赖 | [契约](CONTRACTS.md)、[第三方声明](../THIRD_PARTY_NOTICES.md)及[依赖清单](results/2026-11-23/dependencies.cdx.json)。 |
| M05 关键 CI | 候选 [关键检查](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864638)、[官方 Collector 互操作](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864546)、[生命周期](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864547)、[固定语料和变异回归](https://github.com/miik-su/MoonTelemetry/actions/runs/45183864581)通过。 |
| M06 归档 | 同一候选的[打包结果](results/2026-11-23/source-candidate.raw.json)。ZIP 独立解包后检查通过，CLI 输出 0.1.4。 |
| M08 源码候选 | 已固定 Git 标签。长期负载、主机验证和注册表状态分别记录。 |

正式源码的 [Windows/Linux 关键 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/45807575615)、
[官方 Collector 互操作](https://github.com/miik-su/MoonTelemetry/actions/runs/45807575796)
和 [Linux 生命周期](https://github.com/miik-su/MoonTelemetry/actions/runs/45807575631) 均通过。
正式源码的归档检查包含必要声明、路径排除和 CLI 版本一致性，实际归档已解包并通过 Native 检查。

## 长期负载与部署

2026-11-25 在 Windows 完成候选的一小时合成混合负载。
运行工作区源码 `aad2836eb33c43bc9206ee786e6d172137f92341`，与标签仅有文档
和验证记录差异。两个目标各送达 1,375,961 条记录，0 拒绝请求、0 传输／响应错误。
见 [一小时验证及原始结果](results/2026-11-25/README.md)。

2026-11-25 在本机 Windows 完成 4 小时合成负载，源码
`9d0433e9584c554d84a4f342458b060969a94f8a`。两个目标各送达 9,117,789 条记录，
0 拒绝请求、0 传输／响应错误，最大采样间隔 5,027 毫秒。
见 [四小时验证及原始结果](results/2026-11-25/README.md#四小时独立进程混合负载)。
同一源码在北京时间 11 月 26 日 19:04 完成 24 小时本机合成验收。两个目标各送达
32,986,849 条记录，0 拒绝请求、0 传输／响应错误，最大采样间隔 5,035 毫秒。
见 [24 小时验证及原始结果](results/2026-11-26/README.md)。
Linux Compose/TLS 和 Windows 控制台已有合成验收。生产证书、服务管理器、
容量及磁盘策略须结合实际目标主机核对。
Prometheus、OTLP/gRPC 和持久化队列仍属于后续功能评估。

[2026-11-25 恢复验证](results/2026-11-25/README.md)补充真实连接断开和 Linux
限额卷写满后的恢复用例。规则集未修改，当前仍保持仓库的既有合并流程。

正式发行时使用固定源码，先核对关键测试和包内容，再记录 GitHub Release。
最后使用有 `miik-su` 命名空间权限的身份发布 Mooncakes，并在独立调用方安装验证。

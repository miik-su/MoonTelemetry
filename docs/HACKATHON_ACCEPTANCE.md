# 八月黑客松验收证据索引

核对日期：2026-11-27。适用活动为 2026 MoonBit 国产基础软件生态开源大赛
「8 月黑客松」，依据[活动说明](https://bxup9uklfcb.feishu.cn/wiki/KNrVwEVFziPHiGkQtwhc6w3gndd)第三、六、八、九节。
本文汇总公开仓库证据，申报承诺和资格以参赛者实际提交的材料与活动方通知为准。

## 交付版本

| 项目 | 已核实事实 |
| --- | --- |
| 公开仓库 | [miik-su/MoonTelemetry](https://github.com/miik-su/MoonTelemetry)，实际默认分支 `main` |
| 正式交付 | [GitHub Release v0.1.4](https://github.com/miik-su/MoonTelemetry/releases/tag/v0.1.4)，源码 `69fdbb66904b91ed289dafed1faa1ff2a1155b88` |
| 自查基线 | `26ac7f140fa2935ea0626f5c307567e5412ec831`，2026-11-27 本地 Native 检查、四个关键包 55 项测试和编解码示例通过 |
| CI | 同一自查基线的 [Windows/Linux 关键检查](https://github.com/miik-su/MoonTelemetry/actions/runs/45811002338)、[官方 Collector 互操作](https://github.com/miik-su/MoonTelemetry/actions/runs/45811002216)、[Linux 生命周期](https://github.com/miik-su/MoonTelemetry/actions/runs/45811002310)通过 |
| 构建与分发 | [正式发布核对](RELEASE_0.1.4.md)记录源码包的解包编译及当前注册表状态。GitHub Release 与 Mooncakes 模块是两项交付。 |

截至自查基线，Git 历史有 140 个自 7 月 13 日起的非合并提交，包括实现、测试和文档工作。
核心目录下非测试、非生成的 MoonBit 源文件去除空行、独立注释后约 5,127 行，行数供参考。
提交数量和行数不用于推断报名时间或正式验收结论。

## 功能与证据

这张表描述当前仓库实现。拿到已提交的申报书后，需将承诺逐条对应到证据，并标明已实现、部分实现或未实现。
当前未取得原申报书，表中项目不作为对原承诺的复述。

| 当前可展示的能力 | 证据 | 实际边界 |
| --- | --- | --- |
| 应用 SDK 到独立 Collector，再到文件或 OTLP 出口 | [快速开始](../README.md#快速开始)、[三信号集成测试](../tests/integration/collector_test.mbt) | Native；OTLP/HTTP JSON 与 Protobuf；应用 SDK 由上游提供 |
| 脱敏、过滤、条件路由与兜底 | [运行说明](ROUTING_AND_SELF_METRICS.md)、[路由测试](../tests/integration/routing_test.mbt)、[脱敏顺序测试](../tests/integration/filter_pipeline_test.mbt) | 处理与 Batch 后匹配；同一目标去重；按目标统计副本 |
| 自身指标 | [自身指标测试](../tests/integration/self_metrics_test.mbt)、[0.1.4 验证](results/2026-11-22/README.md) | 独立 OTLP/HTTP 出口；固定汇总指标与有限标签 |
| 安全与故障处理 | [安全策略](../SECURITY.md)、[接收测试](../tests/integration/receiver_security_test.mbt)、[恢复验证](results/2026-11-25/README.md)、[部署边界](DEPLOYMENT.md) | 信任管理员配置；队列易失；入口响应成功表示入队 |
| 持续运行 | [四小时报告](results/2026-11-25/README.md#四小时独立进程混合负载)、[24 小时报告与原始 JSON](results/2026-11-26/README.md) | 同机合成负载按被测源码统计；实际生产环境需另行验收 |
| 许可、来源与独立贡献 | [LICENSE](../LICENSE)、[NOTICE](../NOTICE)、[第三方声明](../THIRD_PARTY_NOTICES.md)、[生态定位](ECOSYSTEM.md)、[样本来源](../tests/fixtures/README.md) | 生成模型、依赖和测试样本分别申明；Go Collector 为架构参考与互操作对象 |

本地关键复查可按固定工具链执行：

```sh
moon version --all
moon check --target native
moon test config processor service tests/integration --target native
moon run examples/codec-demo --target native
```

## 资格和申报材料待确认

| 待核实事项 | 目前能确认的事实 | 验收时使用的材料 |
| --- | --- | --- |
| 初审与本仓库对应关系 | 参赛者此前告知已通过初审。尚未核实通知里的仓库链接、日期或申报编号。 | 私下比对原问卷和初审通知中的项目名与仓库链接。 |
| 报名时间与换仓 | 活动说明的报名截止为 2026-08-24 24:00。GitHub 显示本仓库创建于北京时间 2026-11-07，最早可见提交日期为 2026-11-08。 | 如果初审用了旧链接或补交渠道，保留来源材料，并核对活动方是否接受本仓库及其交付版本、哪些提交可计入。 |
| 申报承诺覆盖 | 当前可核对仓库功能与测试，尚未核对已提交的一页 Markdown。 | 抽取原申报书的核心功能、测试和文档承诺，与上表或新增证据逐项比对。 |
| 参赛与贡献关系 | 仓库公开信息可追踪；参赛者此前说明未将同一作品作为 OSC2026 主赛项目提交。 | 根据实际报名记录核对申请人、仓库维护者和贡献关系；如有换仓或更换维护主体，附可核实说明。八月黑客松无需 Gitlink。 |

初审通知、联系方式和问卷回执留在私人材料。公开索引只记录经核对的非敏感结论和公开链接。

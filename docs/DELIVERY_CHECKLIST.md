# 交付核对记录 — 2026-11-14

本页记录仓库与分发准备，不替代申报书或赛事审核结论。
本次按八月黑客松核对，不沿用 OSC2026 主赛的 Gitlink 要求。
当前准备版本为 0.1.2；正式发布后应记录 `v0.1.2` 的完整源码 SHA 和注册表版本链接。

| 项目 | 当前状态 | 可复查证据或后续操作 |
| --- | --- | --- |
| GitHub | 公开仓库，默认分支 main | https://github.com/miik-su/MoonTelemetry |
| 项目定位 | 已补充与 SDK／埋点库的差异及独立贡献 | [生态定位](ECOSYSTEM.md) |
| 开源来源 | 根 Apache-2.0，依赖及 Go Collector 架构参考已说明 | [第三方声明](../THIRD_PARTY_NOTICES.md) |
| 版本一致性 | moon.mod、生成 CLI 版本与变更记录统一为 0.1.2 | [CHANGELOG](../CHANGELOG.md)、`moon run cmd/moontelemetry --target native -- version` |
| 本地必要检查 | Native check、component 3 项、CLI 1 项及 codec-demo 通过 | [发布复查命令](DISTRIBUTION.md)；不是全量测试结果 |
| 可运行示例 | 无服务依赖的库调用示例，以及 SDK→Collector 示例 | [codec-demo](../examples/codec-demo/main.mbt)、[SDK demo](../examples/sdk-demo/main.mbt) |
| 历史质量证据 | 选定包测试、24 批往返／14 项差分、模糊测试、故障和一小时负载 | [原始结果与准确被测提交](results/2026-11-13/README.md)；不改写为新版本重新测量 |
| 打包内容 | 本地打包及官方解压后 check 已通过，README 已声明 | `moon package --list`、`moon publish --dry-run` |
| Mooncakes 发布 | 按维护者要求暂缓；不是本轮执行项 | 验收前再解决发布身份与命名空间匹配，并完成发布／独立安装验证；目前不声明已发布 |
| Gitlink | 可选镜像；不属于八月黑客松报名缺项 | [可选同步步骤](GITLINK.md) |
| 全量验证 | 未执行／未取得该项证明 | 按当前约定仅做必要关键验证，不能写成全量通过 |

本轮修复了模块关键词列表格式；新的检查结果应从该提交的 CI 读取，不能用旧版本的
通过记录代替。README 的选定包计数已改为带日期与源提交的历史快照。

工程交付应保存：GitHub 公开地址、实际默认分支、完整 HEAD SHA、交付标签及其指向、
相应 CI 运行链接。将来发布时补充 Mooncakes 模块／版本链接；可选镜像另记同步来源。
不要用新文档提交覆盖旧数据中的来源 SHA，也不要重新计数或拆分提交来凑数量。

赛事成果计入时间及补交受理范围由赛事方确认。仓库中的技术核验不能替代这一确认。

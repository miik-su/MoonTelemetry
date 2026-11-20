# 2026-11-19 维护验证

本页只记录实际执行的关键检查，未运行全量测试。版本为 0.1.3 源码维护候选，
未发布 Mooncakes。初审通过是参赛者提供的状态；未公开通知原件、日期或私人材料，
不将其解释为最终获奖或后续资格保证。

## 可下载的本地结果

工具链为 moon 0.1.20261104 / moonc 0.10.20+65efd5b93，Windows x64 / MSVC / Native。

| 检查 | 对应源码 | 结果与范围 |
| --- | --- | --- |
| [快速开始原始结果](quickstart.raw.json) | ad37cf6d267aa706546aa7d091bc7709a2ecc644，干净工作区 | 独立 SDK 和 Collector 进程，文件实际收到 1 条日志、1 个指标点、1 个 Span |
| [打包预检原始结果](distribution.raw.json) | 同上，干净工作区 | 253 项归档内容，必要声明与 CLI 版本一致；ZIP 哈希只标识该次归档 |
| [依赖清单](dependencies.cdx.json) | 同上 | 核对锁定的模块版本、声明许可证、仓库、传递导入及 manifest 哈希 |
| [本地编译器反馈变异](fuzz-local.raw.json) | 1ee464be3adaf2224a1a1dd411cf38d329de3c37 | 64 次变异、891 个命中计数槽、14 个新增覆盖输入、0 崩溃 |
| [固定语料回放](fuzz-replay.raw.json) | 同上 | 26 项通过；非法输入可拒绝，成功解码必须规范化往返一致 |

原始 fuzz 文件中的 platform 为 local；此处补充实际执行环境为上述 Windows Native。
计数槽不等于源码覆盖率百分比；0 崩溃不等于无漏洞。依赖哈希仅覆盖 manifest，
不是完整包完整性证明、CVE 扫描或法律意见。数据均为合成测试内容。

复现入口（先确认上述工具链）：

```sh
moon run tools/check_quickstart.mbtx --target native
moon run tools/check_distribution.mbtx --target native
moon run tools/check_dependencies.mbtx --target native
moon test tests/integration/export_deadline_test.mbt --target native
```

快速开始核对真实文件输出，不依赖 SDK stdout 成功字样；核对完成后由助手终止测试进程，
不据此证明优雅退出。SDK demo 已删除 shutdown 前重复的累计指标 force-flush。

## CI 证据

过滤器、模型、插件边界等实现对应 1ee464be3adaf2224a1a1dd411cf38d329de3c37：
[Windows/Linux 关键检查](https://github.com/miik-su/MoonTelemetry/actions/runs/44540721901)、
[真实 Go Collector 互操作](https://github.com/miik-su/MoonTelemetry/actions/runs/44540721796)、
[编译器反馈变异](https://github.com/miik-su/MoonTelemetry/actions/runs/44540721724)、
[Linux 生命周期故障](https://github.com/miik-su/MoonTelemetry/actions/runs/44540721783)均成功。

后续 ada09c92dfb2a33c4cfbb1b7b445c288fb00b076 的
[关键检查](https://github.com/miik-su/MoonTelemetry/actions/runs/44542571469)中 Windows 成功，
Linux 发现总预算截断的单次超时偶尔被分类为重试等待超限。
修复 bf8f602 保持总预算超时分类，并在已有回归中确认没有重试、预算与活动发送计数释放。
修复后的完整验证源码为 `bf8f602312796e456e96d3756faf13b62db7b170`。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| Windows / Linux Native，11 个关键包 | Windows 85 项、Linux 86 项通过，均无失败。Linux 多执行一项实际 ENOSPC 写入故障检查 | [关键 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/44543418766) · [分包计数 JSON](tests.json) |
| 格式、生成接口、协议描述符、打包预检 | Windows / Linux 均通过 | [关键 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/44543418766) |
| 独立进程快速开始与 5 秒 HTTP 冒烟 | Windows / Linux 均通过。共享执行机上的冒烟仅用于功能回归 | [关键 CI 与产物](https://github.com/miik-su/MoonTelemetry/actions/runs/44543418766) |
| 官方 Go Collector 互操作 | Windows / Linux 均通过双编码模型回传及差异用例 | [互操作 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/44543418792) |
| Linux 生命周期故障 | 工作流通过，包含退出信号、强杀恢复和写入故障 | [故障 CI](https://github.com/miik-su/MoonTelemetry/actions/runs/44543419000) |

## 适用边界

本轮没有重新运行一小时或多小时容量测试；历史长跑仍只归属于其原始提交。
未执行 Nginx/TLS/容器实机部署验证、完整安全审计、ASan 或完整上游协议认证。
五类指标结构检查不证明业务指标计算正确。逻辑预算不是 RSS 硬上限，
内存队列不保证进程崩溃后交付。部署模板的安全属性需要目标环境验证。

许可证、用户数据和协议规范分别见 [契约说明](../../CONTRACTS.md)，
模型覆盖见 [数据模型](../../DATA_MODEL.md)，后续未完成项见 [维护路线](../../MAINTENANCE.md)。

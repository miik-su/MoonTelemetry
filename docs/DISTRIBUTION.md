# 发布与使用

当前源码版本为 0.1.2，目标为 Native。发布身份与模块名中的命名空间必须一致。
发布状态以 Mooncakes 查询为准；生成 ZIP 或发布预检通过不等于已发布。
当前按维护者要求暂缓 Mooncakes 发布，保留源码使用和发布准备说明。
下面的发布步骤供恢复发布时使用，本轮整改不执行登录、发布或更改模块命名空间。

## 从源码运行

使用 `moon 0.1.20261104` / `moonc 0.10.20+65efd5b93` 和 Native C 编译器。
Windows 使用 MSVC，Linux 使用 C 编译器及 async HTTPS 所需系统库。
先用 `moon version --all` 确认实际工具链；本机系统版本可能与 CI 不同。

```sh
moon update
moon check --target native
moon run examples/codec-demo --target native
moon run cmd/moontelemetry --target native -- validate --config examples/collector.json
moon run cmd/moontelemetry --target native -- run --config examples/collector.json
```

另开终端执行 `moon run examples/sdk-demo --target native` 可发送真实 SDK 遥测。
codec-demo 无需网络服务，直接验证公开协议 API 的 JSON→Protobuf→模型往返。

## 作为库使用

发布完成后，在调用方模块添加确定版本：

```sh
moon add miik-su/moontelemetry@0.1.2
```

调用方 `moon.pkg`：

```moonbit
import {
  "miik-su/moontelemetry/core/data",
}

pkgtype(kind: "executable")
```

将 [codec-demo/main.mbt](../examples/codec-demo/main.mbt) 复制为调用方的 `main.mbt`，
运行 `moon run . --target native`。公开接口在各包的 `pkg.generated.mbti` 中：
协议使用 `core/data`，配置使用 `config`，运行服务使用 `service`，插件契约使用
`core/component`。导入包路径，不直接导入单个 `.mbt` 文件。

## 发布前核对

```sh
moon run tools/generate_metadata.mbtx
moon fmt --check
moon info
git diff --exit-code -- '**/pkg.generated.mbti'
moon check --target native
moon test --target native -p core/component
moon test --target native -p cli
moon run examples/codec-demo --target native
moon package --list
moon publish --dry-run
```

这是版本／打包相关的关键检查，不是全量测试。独立 CI 另外覆盖主要包、互操作与故障。
历史负载文件保留原始被测提交，不能改成新版本测量。打包列表需包含 LICENSE、NOTICE、
THIRD_PARTY_NOTICES.md、源码、C shim、示例及 fixtures 来源说明；不得包含 `.env`、
凭据、真实遥测、`_build`、`target` 或 `.mooncakes`。`moon.mod` 已显式指定 README。

确认 `moon login` 登录身份与 `miik-su` 一致后，执行 `moon publish`；随后使用
`moon search miik-su/moontelemetry --limit 5` 确认实际版本，并在独立调用方执行固定版本
安装与示例。不要将登录令牌、credentials.json 或收款信息提交仓库。

## 固定交付版本

将通过检查的源码提交标记为 `v0.1.2`，记录标签解析出的完整 SHA。
GitHub 与将来发布的 Mooncakes 模块应对应同一交付基线；如使用可选 Gitlink 镜像，
也需保持一致。八月黑客松不要求 Gitlink。后续修复使用新版本，
不要移动已发布标签。原始验证数据仍引用实际测量的历史提交。
同步步骤见 [Gitlink 同步](GITLINK.md)，证据范围见 [验证记录](VALIDATION.md)。

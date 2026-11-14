# GitHub 与 Gitlink 同步

八月黑客松仅要求公开 GitHub 仓库；Gitlink 不是该活动的必备材料。
以下保留为可选镜像操作说明，不属于八月黑客松待整改项。

GitHub 项目为 https://github.com/miik-su/MoonTelemetry，已核实默认分支为 `main`。
Gitlink 地址需由拥有者提供或在自己的账号创建；不要根据 GitHub 用户名猜测地址。
本文是操作指南，不能作为“两边已经同步”的证明。

可用 Gitlink 官方[第三方 Git 项目导入](https://help.gitlink.org.cn/快速开始/导入GitHub等第三方Git项目)
创建公开镜像。导入后，确认实际默认分支及完整历史。

```sh
git remote -v
git remote add gitlink <实际的公开Gitlink仓库地址>
git ls-remote --symref gitlink HEAD
```

输出中的 `ref: refs/heads/... HEAD` 才是实际默认分支。若已配置 `gitlink`，先核对地址，
避免重复添加或覆盖其他项目。若默认分支为 main，并且目标没有独立开发历史：

```sh
git push gitlink main
git push gitlink refs/tags/v0.1.2
git ls-remote --symref origin HEAD
git ls-remote --symref gitlink HEAD
```

若默认分支不同，先在 Gitlink 设置要展示的交付分支，或使用明确的 `main:目标分支`
对应关系。不要强制推送覆盖远端历史；遇到分叉先比较和处理。
核对两个默认分支 HEAD SHA 一致，以及标签解析出的源码提交一致。

在网页确认 README、LICENSE、核心代码、测试和完整提交历史可见。
Gitlink 不需要复制 GitHub Actions 工件或本机缓存。同步记录应注明两边链接、默认分支、
完整 SHA、标签和核对日期。另一个分支地址或旧版截图不足以证明当前默认分支已同步。

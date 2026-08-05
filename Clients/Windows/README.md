# Language Corner Windows Desktop

本目录用于做 Windows 安装版。它是轻量 Electron 壳，直接加载 `Clients/Universal` 的打包产物，不改学习功能和界面。

## 快速启动

```bash
cd Clients/Windows
npm install
npm run sync
npm start
```

## 打包

```bash
cd Clients/Windows
npm install
npm run build:win
npm run build:win:portable
```

`sync` 会先构建 `Clients/Universal`，再把产物拷贝到 `Clients/Windows/dist`，保证 Windows 包和 mac 里展示的学习界面一致。

## 自动发布（推荐）

仓库配置了 GitHub Actions。

- 打一个 tag（如 `v1.0.1`）：
  `git tag v1.0.1 && git push origin v1.0.1`
- push 到该 tag 后会触发 CI，在 Windows 环境自动构建 `Language-Corner-Desktop-*.exe`
- 构建成功后会自动创建/更新该 tag 的 GitHub Release，并上传 exe 安装包
- 用户可直接从这里下载： https://github.com/Eren168-ui/russian-corner/releases/latest



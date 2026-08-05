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

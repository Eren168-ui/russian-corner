# Language Corner Universal Client

Language Corner 的手机优先学习端。当前交付可以在浏览器运行、安装到手机桌面，并在首次在线加载后离线使用核心学习内容。

## 本地运行

需要 Node.js 22+。

```bash
cd Clients/Universal
npm install
npm run dev
```

`npm run dev` 前可手动运行 `npm run sync:content`。测试和构建会自动执行内容同步。

打开 `npm run dev` 输出的地址后，电脑浏览器可以直接使用；手机在同一网络打开这个地址即可练习。首次在线打开后，页面会把核心内容留在本机，之后没有网络也可以继续练习。

## 发布到产品落地页

如果要让产品落地页和网页版在同一个地址下运行：

```bash
npm run build:landing
```

这会把生产文件发布到 `/Users/Openclawworkspace/workspace/russian-corner-landing/app/`。落地页的“打开网页版”入口指向 `app/`，不需要账号，也不会上传学习记录。

## 验证

```bash
npm test
npm run build
npm run preview
```

内容同步脚本只读取 `Sources/RussianCornerCore/Resources`，复制审核资源到 `public/content`，并生成 SHA-256 清单。脚本在写入客户端内容前后校验全部源 JSON 哈希，发现源文件变化会失败退出。

当前同步内容：

- 英语：480 条词汇/表达、240 句、24 个主题、24 课。
- 俄语：360 条基础词汇、80 条补充词汇、231 句长期内容、60 句补充内容（共 291 句）、32 个主题、24 个口语挑战。

## 当前能力边界

- 当前交付：浏览器运行、可安装到手机桌面或电脑独立窗口、离线核心学习、英语/俄语本地独立进度与同日续练、浏览器可用语音朗读。
- 首次体验固定为三张真实卡；完成后每天 5 / 10 / 15 分钟分别安排 3 / 5 / 8 张，并混合场景句、词汇/句块与开口挑战。
- 语音朗读取决于设备是否提供对应语言声音；没有声音时朗读按钮隐藏，文本学习不受影响。
- iPhone / Android 商店容器与 Windows 桌面安装包将建立在这套客户端之上；当前先交付手机浏览器版和 Windows 浏览器版，本目录尚不包含商店签名、分发或桌面容器工程。
- 客户端不包含远程账户、密钥或秘密；第一次完成三张练习前不请求登录、麦克风或通知权限。

## 结构

```text
src/content/       英语、俄语源格式适配与内容加载
src/domain/        语言中立模型、每日队列、独立进度
scripts/           只读内容同步与哈希验证
public/content/    可离线使用的审核内容及 SHA-256 清单
tests/             领域、交互、同步、安装与离线清单测试
```

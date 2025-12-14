## 目标&功能： 音频格式转换工具（MACOS with FFmpeg ）
## Goal & Function: audio format conversion tool（MACOS with FFmpeg ）
## 目標と機能: オーディオ形式変換ツール (macOS および FFmpeg を使用)


## 使用
### 如何使用：下载软件-->打开-->选择需要转换格式的音乐-->选择目标格式-->点击转换-->完毕
#### 1. 准备工作：
[下载本软件](release/convert%202025-12-14%205-29-03%E2%80%AFPM/convert.app)
#### 2. 准备软件依赖的FFmpeg环境：（mac平台上推荐使用brew方式一键安装FFmpeg 具体教程询问AI）
```text
a. 现在并直接打开软件。
b. 电脑预先安装 FFmpeg，打开终端（Terminal）输入 ffmpeg -version  然后点击回车键，显示出软件版本号则表示安装配置OK
c. 执行命令  which ffmpeg   会得到类似 /opt/homebrew/bin/ffmpeg   复制这个路径然后在软件中设置时候粘贴进去。

```

![ffmpeg-path](doc%2Fshot%2Fffmpeg-path.png)
![check-ffmpeg-ready](doc%2Fshot%2Fcheck-ffmpeg-ready.png)

### 注意：选择需要格式转换的文件（可以是文件夹，也可以是一个或者多个文件）

### 软件说明： 
1. 纯本地运行，不收集任何用户数据，不记录日志，开放源代码。
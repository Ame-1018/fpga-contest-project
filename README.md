# FPGA Contest Project

基于 **EG4S20** 的 TF 卡 HDMI 多媒体展示系统。仓库包含 FPGA 源码、Tang Dynasty 工程、IP 配置、引脚与时序约束及 Windows 上位机程序。

## 项目组成

源码包含 SD 卡控制、BMP/音频读取、SDRAM 控制、HDMI 输出、视频处理、OSD 菜单、按键与 UART 通信等模块。

| 路径 | 内容 |
| --- | --- |
| `hardware/sources/` | Verilog 源码、仿真文件、初始化数据及资源生成脚本 |
| `hardware/TD_PRJ/EG4_SD_HDMI.al` | Tang Dynasty 工程入口 |
| `hardware/TD_PRJ/al_ip/` | PLL、FIFO、存储器、DSP 等 IP 文件 |
| `hardware/TD_PRJ/constraint/` | 引脚约束与时序约束 |
| `tools/windows/` | 串口上位机与 SD 卡布局工具 |

## 打开 FPGA 工程

1. 克隆仓库或下载并解压 ZIP，保留目录结构。
2. 使用 Tang Dynasty 打开 `hardware/TD_PRJ/EG4_SD_HDMI.al`。原工程记录的工具版本为 **6.2.190657**，目标器件为 **EG4S20BG256**，顶层模块为 `EG4_SD_HDMI_SUBSYSTOP`。
3. 按实际开发板检查引脚约束。原工程的综合和布局布线配置使用 `constraint_CARD1`，同时保留另一套 `constraint_1`。
4. 根据需要重新生成 IP、综合、布局布线和生成下载文件。

## Windows 上位机

- `tools/windows/串口上位机.exe`：串口画面参数控制；原使用说明标注波特率 **256000，8N1**。
- `tools/windows/SD卡布局.exe`：BMP / WAV 扇区规划、媒体转换及 SD 卡写入。
- 运行环境：64 位 Windows 10 / 11。两款工具均为打包后的独立 EXE，首次启动解压可能稍慢。

SD 卡写入会修改所选存储设备，请核对盘符。收到的资料包未包含两款上位机的 Python 源码，目前提供的是打包后的 EXE。

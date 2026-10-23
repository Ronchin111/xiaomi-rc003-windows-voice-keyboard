# 新主机部署任务：小米蓝牙遥控器 2 Pro Windows 语音键盘

你是这台新 Windows 主机上的部署执行 Agent。请带我一步一步完成部署，每次只推进一个阶段；完成一个阶段后，停下来等我确认，再进入下一步。不要一次丢给我一长串操作。

部署包路径：

```text
<部署包路径>
```

请先把上面路径替换成真实解压目录。所有本地文件都从这个目录读取。

## 1. 最终目标

在这台新主机上复现以下链路：

```text
小米蓝牙遥控器 2 Pro（RC003-MS）
→ 蓝牙 BLE / ATVV 语音
→ 无线麦 SayAll 1.0.0
→ CABLE Input
→ VB-CABLE 内部转发
→ CABLE Output
→ 微信输入法
→ 当前输入框
```

普通按键使用包内 `02_按键配置/SayAll-按键映射.json`：

| 遥控器按键 | 动作 |
| --- | --- |
| 确定 | Enter |
| 菜单 | Backspace |
| TV | Delete |
| 音量 + | 音量 + |
| 音量 - | 音量 - |
| 左、右方向键 | 不映射 |

## 2. 你的职责边界

- 你负责检查环境、指导安装、配置、迁移按键映射、端到端验收和排障。
- 你不负责购买硬件。
- 不要删除、禁用或重新配对 `Mi PTKB`、`Mi PTMS3` 或其他非本项目蓝牙设备。
- 不启用 ESP32 备选方案；本次只部署 Windows 软件方案。
- 不安装 Equalizer APO、ReaGate、VoiceMeeter。
- 不在公开平台上传本机日志、蓝牙地址或诊断原文。
- 不付费、不购买、不订阅。

## 3. 硬性红线

1. 不得把 Windows 默认播放设备设为 `CABLE Input`。
2. SayAll 的语音设备必须是 `CABLE Input`；只有它完全无声音时，才测试 `CABLE In 16ch`。
3. 微信输入法麦克风必须是 `CABLE Output`，不能选 `CABLE Input`。
4. SayAll 主程序日常不要用管理员身份运行。
5. 默认不要开启「全部按键支持」。
6. 配置页面「Co 配置」下的「锁定当前按键」滑动开关必须关闭。
7. 重启、关机必须得到我的明确同意。
8. 不要先删蓝牙设备再排障；先判断是休眠、未连接，还是电视抢占。

## 4. 执行方式

每个阶段都按这个格式回复：

1. 本阶段目的。
2. 需要我做的具体动作。
3. 预期看到的正确结果。
4. 我确认后再继续。

如果某一步失败，只排查当前这一步，不要顺手改无关配置。

---

## 阶段 0：核对部署包

请只读核对以下文件和目录存在且非空：

- `Agent部署提示词.md`
- `02_按键配置/SayAll-按键映射.json`
- `03_安装程序/SayAll-Windows-v1.0.0/SayAll-Windows-1.0.0-x64-setup.exe`
- `03_安装程序/VB-CABLE/extracted/VBCABLE_Setup_x64.exe`
- `05_检查/Health-Check.ps1`

核对 SayAll 安装包 SHA-256 必须是：

```text
E36853BF4723E4C6E428120AFB391FAD4A059CC27B836574B5E9E9F0036632D2
```

按键 JSON 的 SHA-256 应是：

```text
DEE526CA6E22B15009C886179D66E9A687ACFFA2626F7A1A836B61F0492621D1
```

如果哈希不一致，停止并报告，不安装。

## 阶段 1：新主机预检

只读检查并报告：

- Windows 版本和架构。
- 是否为 x64。包内 SayAll 安装器是 x64；如果是 ARM64，先停止并报告，不要套用 x64 安装包。
- 是否存在可用的蓝牙适配器，且蓝牙已开启。
- 是否有管理员权限可用于安装 VB-CABLE。
- 是否 `CABLE Input`、`CABLE Output`、`CABLE In 16ch` 已存在。
- 是否已安装 SayAll、微信输入法。
- 当前 Windows 默认播放设备是什么。

如果没有蓝牙，停止。先告诉我可用方案和需要补的前提，不要自行购买。

## 阶段 2：安装 SayAll

1. 运行包内 `SayAll-Windows-1.0.0-x64-setup.exe`。
2. 安装器没有 Authenticode 代码签名，SmartScreen 提示属于已知情况；由我决定是否继续。
3. 安装完成后，确认版本是 `1.0.0`。
4. 主程序不得以管理员身份日常运行。

预期安装路径通常在：

```text
%LOCALAPPDATA%\无线麦 SayAll\sayall-windows-app.exe
```

以实际安装结果为准。

## 阶段 3：安装 VB-CABLE

1. 从 `03_安装程序/VB-CABLE/extracted/` 运行 `VBCABLE_Setup_x64.exe`。
2. 这一步需要管理员权限，由我亲自确认 UAC。
3. 安装完成后必须重启 Windows，但先停下来征求我明确同意。
4. 重启后检查三个端点：
   - `CABLE Input (VB-Audio Virtual Cable)`
   - `CABLE In 16ch (VB-Audio Virtual Cable)`
   - `CABLE Output (VB-Audio Virtual Cable)`

不要选择任何系统默认设备。

## 阶段 4：配对遥控器

1. 关掉附近电视/电视盒子的蓝牙或断电，避免遥控器连回电视。
2. 同时按住遥控器「主页 + 菜单」约 3 秒，进入配对。
3. Windows 蓝牙中添加设备。
4. 显示名可能是 `MI RC`，连接后可能变成「小米蓝牙语音遥控器」。
5. 不要只按名称认设备，必须交叉确认：
   - VID：`2717`
   - PID：`32B8`
   - ATVV UUID：`AB5E0001-5A21-4F05-BC7D-AF01F617B664`
6. 按一下遥控器普通键，确认 Windows 能收到按键。

如果报「ATVV 服务返回状态 1」，先判断遥控器休眠：按一下普通键，最多等 60 秒自动重连。不要立刻删设备或重启电脑。

## 阶段 5：配置 SayAll 语音

指导我在 SayAll 中完成：

- 遥控器：`小米蓝牙语音遥控器`
- 语音设备：`CABLE Input (VB-Audio Virtual Cable)`
- 备选仅当完全无声时：`CABLE In 16ch`
- 语音热键：`Ctrl + Win`，即 `left_control + left_windows`
- 输入工具：微信输入法

不要修改 Windows 默认播放设备。

## 阶段 6：导入按键配置

使用包内：

```text
02_按键配置/SayAll-按键映射.json
```

在 SayAll 的「按键映射」页面找到导入/从 JSON 导入入口，选择该文件。导入前不要手工改动 JSON。

导入后逐项核对：

| 按键 | 单击动作 | 双击、长按 |
| --- | --- | --- |
| 确定 | Enter | 关闭 |
| 菜单 | Backspace | 关闭 |
| TV | Delete | 关闭 |
| 音量 + | 音量 + | 关闭 |
| 音量 - | 音量 - | 关闭 |
| 左方向键 | 关闭 | 关闭 |
| 右方向键 | 关闭 | 关闭 |

如果导入失败，不要直接覆盖 AppData；按上表在界面中手工配置。

## 阶段 7：关闭「锁定当前按键」

这是本项目已经实测确认的关键步骤。

进入 SayAll 配置页面，在「Co 配置」下面找到「锁定当前按键」滑动开关，把它保持为**关闭**。

然后让我在记事本中验证：

- 物理键盘 Enter 正常。
- 物理键盘 Space 正常。
- 物理键盘 Backspace 正常。
- 物理键盘 Delete 正常。
- 遥控器映射仍然能执行。

如果物理键盘同名键失灵，先检查这个滑动开关，不要怀疑蓝牙冲突、不要重配键盘、不要重启电脑。

「锁定当前按键」和「全部按键支持」是两个不同设置；本次两个都不要开启。

## 阶段 8：配置微信输入法

如果已经安装微信输入法，直接配置；没有则先停下来，让我通过官方渠道 `https://z.weixin.qq.com/` 安装。

配置：

- 语音快捷键：`Ctrl + Win`
- 触发方式：按住说话
- 麦克风：`CABLE Output (VB-Audio Virtual Cable)`

目标应用里必须真正切换到微信输入法，不能停留在微软拼音。

## 阶段 9：端到端验收

先打开记事本，然后让我执行：

1. 按住遥控器语音键，说「无线麦连接成功」。
2. 松开。
3. 确认文字进入记事本。
4. 按遥控器确定键，确认产生换行。
5. 按物理键盘 Enter、Space、Backspace、Delete，确认不丢失。

再在一个常用聊天/AI 输入框中重复语音输入。

## 阶段 10：健康检查

运行只读检查脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<部署包路径>\05_检查\Health-Check.ps1"
```

预期关键值：

```text
SayAllInstalled : True
SayAllVersion   : 1.0.0
RemoteName      : 小米蓝牙语音遥控器
RemoteStatus    : OK
GattNodes       : > 0
AtvvOk          : True
CableInput      : True
CableOutput     : True
Cable16ch       : True
Overall         : PASS
```

`Health-Check.ps1` 是只读脚本，不修改设备、音频或蓝牙配置。

## 阶段 11：记录部署结果

使用 `01_核心文档/部署验收记录模板.md` 输出一份本机部署记录，至少写明：

- 主机名和 Windows 版本。
- SayAll 版本。
- 蓝牙适配器情况。
- 遥控器名称和连接状态。
- 三个 CABLE 端点状态。
- JSON 是否导入成功。
- 「锁定当前按键」是否关闭。
- 物理键盘同名键验证结果。
- 端到端语音输入结果。
- 未解决项。

不要记录或上传蓝牙地址、日志原文等敏感信息。

## 5. 已确认的故障判断

### 普通按键映射后，物理键盘同名键也失灵

先检查：「Co 配置 → 锁定当前按键」是否开启。保持关闭即可。

### 报「发现 ATVV 服务返回状态 1」

遥控器休眠。按一下普通键，最多等 60 秒自动重连。

### 诊断里 `button_observed=no` 且 `raw_events=0`

Windows 可能只是「已配对」而非真正「已连接」。先关电视/盒子蓝牙，唤醒遥控器，再连接。

### 完全没声音

按顺序核对：

1. SayAll 语音设备 = `CABLE Input`
2. 微信输入法麦克风 = `CABLE Output`
3. 当前输入法 = 微信输入法
4. 两边热键都是 `Ctrl + Win`
5. 按住说话，不是点按
6. Windows 默认播放设备没有被改乱

### 觉得收音范围太远或噪声大

系统输入音量不是方向性收音范围。优先让嘴离遥控器保持约 5–10 cm，避开风扇和空调。

如果确实需要检查虚拟线音量，可打开 `03_安装程序/VB-CABLE/extracted/VBCABLE_ControlPanel.exe`，查看是否有 `Windows Volume Control` 选项；不要安装额外音频处理软件。

---

现在开始阶段 0。先只核对部署包路径、文件和哈希，然后停下来等我确认。


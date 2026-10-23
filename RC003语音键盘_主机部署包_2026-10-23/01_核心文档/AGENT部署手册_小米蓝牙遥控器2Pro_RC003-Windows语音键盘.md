# AGENT 部署手册：小米蓝牙遥控器 2 Pro（RC003-MS）→ Windows 语音键盘

- 文档类型：Agent 执行手册（Runbook）
- 文档版本：v1.1
- 定稿日期：2026-10-23
- 适用对象：具备 Windows 本机操作能力的 AI Agent
- 配套文档：`小米蓝牙遥控器2Pro_RC003-Windows语音键盘-操作手册.md`（面向用户）

---

## 0. 给 Agent 的三句话

1. 用户只负责买设备、按几下实体键、点 UAC/重启确认、试说一句话；**下载、校验、安装、配置、诊断、验收由 Agent 完成**。
2. 必须安装的只有两个软件：**无线麦 SayAll 1.0.0** 和 **VB-CABLE**；微信输入法是语音识别端，已有则复用。
3. 整条链路的关键只有一句：**SayAll 写 `CABLE Input`，微信输入法读 `CABLE Output`**。方向反了就没有声音。

---

## 1. 职责边界

### 1.1 用户必须亲自做的事（不可代劳）

| 事项 | 原因 |
| --- | --- |
| 购买遥控器 | 涉及付费，Agent 不执行购买 |
| 把遥控器放在电脑旁 10–20cm | 物理位置 |
| 同时按住「主页 + 菜单」进入配对 | 物理按键 |
| 配对过程中按普通键唤醒 | 物理按键 |
| 点 UAC「是」、确认重启 | 系统级授权，必须由用户确认 |
| 在测试输入框里说一句话 | 需要真人发声 |

### 1.2 Agent 应完成的事

| 事项 | 说明 |
| --- | --- |
| 环境检查 | Windows 版本、蓝牙适配器、网络、管理员权限 |
| 下载安装包 | SayAll、VB-CABLE |
| 校验哈希 | 防止装错包 |
| 安装 SayAll | 优先静默安装，失败则 GUI 安装 |
| 安装 VB-CABLE | 需要管理员，静默参数 `/S` |
| 触发重启 | 用户确认后执行，或指导用户手动重启 |
| 配对后验证 | 用 PnP 枚举确认设备与 ATVV 服务 |
| 配置 SayAll | 设备选择、快捷键、输入工具、向导 |
| 配置微信输入法 | 快捷键、按住说话、麦克风 |
| 读取诊断 | 解析用户粘贴的 SayAll 诊断文本 |
| 故障处理 | 按第 7 节决策树执行 |
| 端到端验收 | 验证文字真的进入输入框 |

### 1.3 能力降级原则

如果 Agent 没有 GUI 自动化能力，只能读写文件和执行命令：

- Agent 负责所有下载、安装、校验、系统检测；
- Agent 给用户逐步的精确点击指令；
- 用户执行点击后，把界面文字或截图发回；
- Agent 继续验证，不把「用户说好了」当作验收通过。

---

## 2. Gate 0：环境前置检查

在动手前逐项确认，任一不满足先解决再继续。

| 检查项 | 要求 | 检查方法 |
| --- | --- | --- |
| 系统版本 | Windows 10 1809（17763）及以上，或 Windows 11 | `[Environment]::OSVersion.Version` |
| 架构 | x64 | `$env:PROCESSOR_ARCHITECTURE` |
| 蓝牙适配器 | 存在且已开启 | `Get-PnpDevice -Class Bluetooth` |
| 网络 | 可访问 GitHub 与 VB-Audio | `Test-NetConnection github.com -Port 443` |
| 管理员权限 | 可用于安装 VB-CABLE | 当前会话是否 elevated |
| 遥控器电量 | 建议 30% 以上 | 先充电 30 分钟或询问用户 |
| WebView2 | 缺失时 SayAll 安装器会在线安装 | 需要网络 |

注意事项：

- RC003 **没有 USB 接收器**，必须用电脑自带蓝牙或 USB 蓝牙适配器。
- ARM64 电脑可以使用按住说话和普通按键，但「全按键支持」不可用。
- SayAll 主程序按当前用户运行，**日常不要以管理员身份运行**。

### Gate 0 检测脚本

```powershell
[pscustomobject]@{
  OSVersion      = [Environment]::OSVersion.Version.ToString()
  Architecture   = $env:PROCESSOR_ARCHITECTURE
  IsElevated     = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  BluetoothNodes = @(Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue).Count
} | Format-List
```

判定：

- `BluetoothNodes` 为 0 → 无蓝牙适配器或驱动异常，停止。
- `IsElevated` 为 False → 安装 VB-CABLE 时需要另开管理员会话。

---

## 3. 软件清单

### 3.1 必装

| 软件 | 版本 | 来源 | 作用 |
| --- | --- | --- | --- |
| 无线麦 SayAll Windows | 1.0.0 或更新 | GitHub Releases | 连接遥控器、ATVV 语音桥接、按键映射 |
| VB-CABLE | 2024 驱动包（VBCABLE_Driver_Pack45） | vb-audio.com | 提供虚拟播放/录音端点 |

### 3.2 已有则复用

| 软件 | 说明 |
| --- | --- |
| 微信输入法 | 语音识别端；没有则从 `https://z.weixin.qq.com/` 官方渠道安装 |

### 3.3 明确不要装

| 软件 | 原因 |
| --- | --- |
| Equalizer APO | 本方案不需要；此前在 Intel SST 驱动上安装失败并已放弃 |
| ReaGate / ReaPlugs | 只是 VST 插件，不能独立做麦克风噪声门 |
| VoiceMeeter / 其他虚拟声卡 | 与 VB-CABLE 功能重叠，增加路由复杂度 |
| ESP32 工具链 | 当前软件方案已跑通，不需要 |

---

## 4. 部署流程

### 阶段 1：安装 SayAll

#### 1.1 下载

```powershell
$dst = 'D:\Codex Work\我的助理\硬件资料\Windows蓝牙语音键盘\SayAll-Windows-v1.0.0'
New-Item -ItemType Directory -Path $dst -Force | Out-Null
```

从 `https://github.com/GetSayAll/remote-mic-app-windows/releases` 选择 `SayAll-Windows-<版本>-x64-setup.exe`，不要下载 `latest.json` 或 `.sig`。

#### 1.2 校验

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $dst 'SayAll-Windows-1.0.0-x64-setup.exe')
```

1.0.0 的期望值：

```
E36853BF4723E4C6E428120AFB391FAD4A059CC27B836574B5E9E9F0036632D2
```

哈希不一致 → 删除文件重新下载，不要安装。

#### 1.3 安装

优先尝试静默安装：

```powershell
$setup = Join-Path $dst 'SayAll-Windows-1.0.0-x64-setup.exe'
Start-Process -FilePath $setup -ArgumentList '/S' -Wait -PassThru | Select-Object ExitCode
```

说明：SayAll 安装器的 `/S` 静默参数**本项目未做过正式验证**。若 60 秒内没有完成、退出码非 0，或目标目录没有出现文件，改用 GUI 安装：

```powershell
Start-Process -FilePath $setup
```

GUI 安装时按提示完成，不需要自定义安装路径。

#### 1.4 验证

```powershell
$exe = 'd:\Users\admin\AppData\Local\无线麦 SayAll\sayall-windows-app.exe'
[pscustomobject]@{
  Exists  = Test-Path -LiteralPath $exe
  Version = if (Test-Path -LiteralPath $exe) { (Get-Item -LiteralPath $exe).VersionInfo.FileVersion } else { 'N/A' }
} | Format-List
```

通过标准：`Exists=True`，`Version=1.0.0`（或更高）。

**Gate 1 通过后进入阶段 2。**

---

### 阶段 2：安装 VB-CABLE

#### 2.1 下载与解压

官方下载页：`https://vb-audio.com/Cable/`

下载 `VBCABLE_Driver_Pack45.zip`，解压到：

```
D:\Codex Work\我的助理\硬件资料\Windows蓝牙语音键盘\VB-CABLE\extracted
```

#### 2.2 安装（需要管理员）

```powershell
$setup = 'D:\Codex Work\我的助理\硬件资料\Windows蓝牙语音键盘\VB-CABLE\extracted\VBCABLE_Setup_x64.exe'
Start-Process -FilePath $setup -ArgumentList '/S' -Verb RunAs -Wait
```

参数 `/S` 已在本项目验证可用。用户会看到 UAC 提示，需要点「是」。

安装完成后可能自动打开 VB-Audio 官网网页：**忽略并关闭**，没有需要操作的内容。

#### 2.3 重启（硬性要求）

VB-CABLE 安装后必须重启，否则端点不出现或不工作。

执行前必须：

1. 提醒用户保存所有未保存的工作。
2. 得到用户明确同意。

然后可以执行：

```powershell
shutdown /r /t 60 /c "VB-CABLE 安装完成，60 秒后重启"
```

或让用户自己点「开始 → 电源 → 重启」。

#### 2.4 重启后验证

```powershell
$eps = Get-PnpDevice -Class AudioEndpoint | Where-Object { $_.FriendlyName -like '*VB-Audio Virtual Cable*' }
[pscustomobject]@{
  CableInput  = [bool]($eps | Where-Object FriendlyName -like 'CABLE Input*')
  CableOutput = [bool]($eps | Where-Object FriendlyName -like 'CABLE Output*')
  Cable16ch   = [bool]($eps | Where-Object FriendlyName -like 'CABLE In 16ch*')
} | Format-List
```

通过标准：`CableInput=True` 且 `CableOutput=True`。`Cable16ch` 为 True 或 False 都不影响。

若两个端点都不存在：确认已重启；仍不存在则卸载重装 VB-CABLE 并再次重启。

**Gate 2 通过后进入阶段 3。**

---

### 阶段 3：配对遥控器

这一步需要用户做物理动作，Agent 负责给指令和验证。

#### 3.1 给用户的话（可直接复制）

> 请先把电视或电视盒子断电（或关掉它的蓝牙），避免遥控器连回电视。
> 然后把遥控器放在电脑旁边，同时按住「主页」和「菜单」两个键约 3 秒。
> 这款遥控器配对时指示灯不会亮，这是正常的。
> 按住后告诉我，我在电脑上点「添加设备」。

#### 3.2 Windows 侧操作

1. 打开「设置 → 蓝牙和其他设备」。
2. 确认蓝牙已开启。
3. 点「添加设备 → 蓝牙」。
4. 等待列表出现「小米蓝牙语音遥控器」或 `MI RC`。
5. 选择并连接。

#### 3.3 验证

```powershell
$names = @('MI RC', '小米蓝牙语音遥控器')
$top   = Get-PnpDevice -Class Bluetooth | Where-Object { $_.FriendlyName -in $names }
$gatt  = Get-PnpDevice | Where-Object { $_.InstanceId -like '*VID&012717_PID&32B8*' }
$atvv  = Get-PnpDevice | Where-Object { $_.InstanceId -like '*AB5E0001*' }

[pscustomobject]@{
  RemoteName    = if ($top) { ($top | Select-Object -First 1).FriendlyName } else { 'NOT_FOUND' }
  RemoteStatus  = if ($top) { ($top | Select-Object -First 1).Status } else { 'N/A' }
  GattNodeCount = @($gatt).Count
  AtvvNodeCount = @($atvv).Count
  AtvvUuidOk    = [bool]$atvv
} | Format-List
```

通过标准：

- `RemoteName` 是 `MI RC` 或 `小米蓝牙语音遥控器`
- `RemoteStatus=OK`
- `AtvvUuidOk=True`
- `GattNodeCount` 大于 0

**重要：设备名会变。** 刚配对时可能叫 `MI RC`，连接成功后 Windows 可能显示为「小米蓝牙语音遥控器」。不要按名字死匹配，必须同时用 `VID&012717_PID&32B8` 和 ATVV UUID `AB5E0001` 交叉确认。

**Gate 3 通过后进入阶段 4。**

---

### 阶段 4：配置 SayAll

#### 4.1 启动

```powershell
Start-Process 'd:\Users\admin\AppData\Local\无线麦 SayAll\sayall-windows-app.exe'
```

首次启动进入 7 步向导。

#### 4.2 各步配置值

| 向导步骤 | 选择/操作 |
| --- | --- |
| 1 | 选择输入工具：微信输入法 |
| 2 | 连接遥控器：选 `MI RC` / 小米蓝牙语音遥控器，点连接；按一下普通键 |
| 3 | 语音设备：选 `CABLE Input (VB-Audio Virtual Cable)` |
| 4 | 语音热键：`Ctrl + Win`（`left_control + left_windows`） |
| 5 | 按提示按住语音键测试 |
| 6 | 按几个普通键，确认按键可识别 |
| 7 | 完成 |

#### 4.3 关键规则

- 第 3 步出现两个「推荐」时，选 `CABLE Input`，不要选 `CABLE Output`。
- `CABLE In 16ch` 是备选；只有 `CABLE Input` 完全无声音时才换它。
- 不要开启「全部按键支持」，除非用户明确要求接管返回键/音量键。
- 配置普通按键映射时，检查「Co 配置 → 锁定当前按键」保持关闭，避免映射目标键抢占物理键盘的同名键。
- 不要修改 Windows 系统默认播放设备和默认录音设备。

**Gate 4 通过标准：** 状态显示遥控器已连接、语音设备已选、可以进入语音测试。

---

### 阶段 5：配置微信输入法

如果用户已经安装微信输入法，直接配置；没有则先从 `https://z.weixin.qq.com/` 官方渠道安装。

| 设置项 | 值 |
| --- | --- |
| 语音快捷键 | `Ctrl + Win` |
| 触发方式 | 按住说话 |
| 麦克风 | `CABLE Output (VB-Audio Virtual Cable)` |

要点：

- 必须和 SayAll 的热键完全一致，否则 SayAll 发信号但输入法不响应。
- 麦克风必须选 `CABLE Output`，不是 `CABLE Input`。
- 目标软件里要确保当前输入法是微信输入法，不是微软拼音。

**Gate 5 通过标准：** 微信输入法语音页显示快捷键为 Ctrl+Win、麦克风为 CABLE Output。

---

### 阶段 6：端到端验收

请用户执行：

> 在任意输入框里点一下，按住遥控器语音键，说「无线麦连接成功」，然后松开。

通过标准（全部满足）：

1. 文字真的出现在输入框里；
2. 松开后录音立即结束；
3. 再按一次仍然可用；
4. 按一下确定键，能发送或换行（若已配置映射）。

任一不满足 → 进入第 7 节故障决策树。

---

## 5. 一键健康检查脚本

任何时候都可以运行，用于判断当前机器处于什么状态：

```powershell
$names = @('MI RC', '小米蓝牙语音遥控器')
$top   = Get-PnpDevice -Class Bluetooth | Where-Object { $_.FriendlyName -in $names }
$gatt  = Get-PnpDevice | Where-Object { $_.InstanceId -like '*VID&012717_PID&32B8*' }
$atvv  = Get-PnpDevice | Where-Object { $_.InstanceId -like '*AB5E0001*' }
$eps   = Get-PnpDevice -Class AudioEndpoint | Where-Object { $_.FriendlyName -like '*VB-Audio Virtual Cable*' }
$exe   = 'd:\Users\admin\AppData\Local\无线麦 SayAll\sayall-windows-app.exe'

[pscustomobject]@{
  SayAllInstalled = Test-Path -LiteralPath $exe
  SayAllVersion   = if (Test-Path -LiteralPath $exe) { (Get-Item -LiteralPath $exe).VersionInfo.FileVersion } else { 'N/A' }
  RemoteName      = if ($top) { ($top | Select-Object -First 1).FriendlyName } else { 'NOT_FOUND' }
  RemoteStatus    = if ($top) { ($top | Select-Object -First 1).Status } else { 'N/A' }
  GattNodes       = @($gatt).Count
  AtvvOk          = [bool]$atvv
  CableInput      = [bool]($eps | Where-Object FriendlyName -like 'CABLE Input*')
  CableOutput     = [bool]($eps | Where-Object FriendlyName -like 'CABLE Output*')
  Cable16ch       = [bool]($eps | Where-Object FriendlyName -like 'CABLE In 16ch*')
} | Format-List
```

期望结果（已跑通状态）：

```
SayAllInstalled : True
SayAllVersion   : 1.0.0
RemoteName      : 小米蓝牙语音遥控器
RemoteStatus    : OK
GattNodes       : 10
AtvvOk          : True
CableInput      : True
CableOutput     : True
Cable16ch       : True
```

---

## 6. SayAll 诊断文本解析

用户会从 SayAll 复制类似下面的文本，Agent 按下表解析：

```
Wizard step: remote (2/7)
Gate: remote.not_connected
Remote: phase=reconnecting model=unknown voice_ready=no reconnects=2 error=yes button_observed=no
Raw input: phase=ready matched=1 raw_events=0 semantic_edges=0 stale_events=0
Audio: phase=unconfigured recommended=2 selected=no
Input tool: unset hotkey=left_control+left_windows full_key_support=off
Buttons observed: 0/3
```

| 字段 | 含义 | 异常时的动作 |
| --- | --- | --- |
| `Gate: remote.not_connected` | 遥控器链路未就绪 | 按阶段 3 检查 |
| `model=unknown` | 还没识别出 RC001/RC003 | 说明 GATT 未建立，不是按键问题 |
| `voice_ready=no` | ATVV 语音未就绪 | 先解决连接 |
| `error=yes` | 本轮有错误 | 看错误原文的状态码 |
| `button_observed=no` | 一次普通按键都没收到 | Windows 侧未真正连接 |
| `matched=1` | 找到了 HID 设备 | 设备在系统里，但未连通 |
| `raw_events=0` | 没有原始按键事件 | 遥控器可能连着电视或休眠 |
| `Audio: unconfigured` | 语音设备未选 | 回阶段 4 |
| `Input tool: unset` | 未选输入工具 | 选微信输入法 |
| `hotkey=left_control+left_windows` | 当前热键 Ctrl+Win | 与微信输入法保持一致 |
| `full_key_support=off` | 未开启全按键支持 | 保持关闭，除非用户要求 |
| `Buttons observed: 0/3` | 向导还没收到 3 个按键 | 先解决连接 |

---

## 7. 故障决策树

### 7.1 连接时报「ATVV 服务返回状态 1」

```
if 错误含 "状态 1":
    → GattCommunicationStatus::Unreachable
    → 遥控器在休眠
    → 让用户按一下普通键
    → 等最多 60 秒自动重连
    → 不要重新配对、不要重启电脑
```

依据：项目 Issue #112 的日志分析，状态 1 的 6 次出现全部在系统恢复后 0.02–1.8 秒内，遥控器上线后同一路径 173ms 通过。

### 7.2 状态 2 / 状态 3

| 状态 | 含义 | 动作 |
| --- | --- | --- |
| 2 | ProtocolError | 通信协议错误，等自动重试；连续失败再重启蓝牙 |
| 3 | AccessDenied | 检查 Windows 蓝牙设置里设备是否被禁用、权限是否异常 |

### 7.3 `button_observed=no` 且 `raw_events=0`

判定：Windows 里只是「已配对」，没有真正「已连接」。

处理顺序：

1. 电视/盒子断电或关蓝牙。
2. Windows 蓝牙设置里看 `MI RC` / 小米蓝牙语音遥控器 是「已连接」还是「已配对」。
3. 尝试点击连接，同时按遥控器普通键。
4. 仍失败 → 删除设备，重新用「主页 + 菜单」配对。

### 7.4 完全没声音

按顺序核对：

1. SayAll 语音设备 = `CABLE Input`
2. 微信输入法麦克风 = `CABLE Output`
3. Windows 默认设备未被改乱（不需要改默认设备）
4. 当前输入法是微信输入法
5. 热键两边都是 `Ctrl + Win`
6. 按住语音键说话，不是点一下

### 7.5 映射后物理键盘的同名键失灵

现象：把遥控器按键映射为空格、回车等按键后，蓝牙键盘上对应的空格、回车也失灵；完全退出 SayAll 后恢复。

判定：这是 SayAll 的按键锁定行为，不是两个蓝牙设备争用同一按键。

处理：

1. 进入 SayAll 配置页面的「Co 配置」。
2. 关闭「锁定当前按键」。
3. 在记事本中分别测试物理键盘的空格、回车。
4. 再测试遥控器映射，确认两边可以同时工作。

不要先删除或重新配对蓝牙键盘，也不要为这个现象重启电脑。

### 7.6 遥控器又连回电视

处理：关闭电视/盒子蓝牙或断电；把遥控器拿到离电视远一点的位置再唤醒。

### 7.7 认错设备

本机可能同时存在：

- `MI RC` / `小米蓝牙语音遥控器` ← 正确的 RC003
- `Mi PTKB`
- `Mi PTMS3`

只认 `VID&012717_PID&32B8` 和 ATVV UUID `AB5E0001`。不要删除或改动其他 Mi 设备。

---

## 8. 红线：Agent 不得执行

1. 不得删除 `Mi PTKB`、`Mi PTMS3` 或任何非本项目的蓝牙设备。
2. 不得把 Windows 默认播放设备改成 `CABLE Input`，否则系统声音会进入虚拟线。
3. 不得在 SayAll 里选 `CABLE Output` 作为语音设备。
4. 不得在微信输入法里选 `CABLE Input` 作为麦克风。
5. 不得默认开启「全部按键支持」。
6. 不得把「重启电脑 / 重开蓝牙 / 重新配对」当成第一步；先按 Issue #112 的结论处理休眠。
7. 不得安装 Equalizer APO、ReaGate、VoiceMeeter。
8. 不得以管理员身份日常运行 SayAll 主程序。
9. 不得未经用户同意执行重启或关机。
10. 不得自行购买硬件或触发付费操作。
11. 不得删除用户原有的音频设备、驱动或配置文件。
12. 不得在公开仓库或外部平台上传本机日志、设备地址或诊断原文。

---

## 9. 什么时候才升级到 ESP32 方案

同时满足以下任一条件才考虑：

1. 需要单次连续录音明显超过 60 秒；
2. 需要完整接管返回键、音量键等系统保留键；
3. 软件方案在目标电脑上反复失败且排除环境问题；
4. 需要脱离 SayAll 常驻进程。

否则继续使用软件方案。ESP32 资料保留在：

```
D:\Codex Work\我的助理\硬件资料\Windows蓝牙语音键盘\RemoteMapper-ESP32-source
```

---

## 10. 交付汇报模板

Agent 完成后按以下格式汇报：

```markdown
## 部署结果

- 机器：<计算机名> / Windows <版本> / <架构>
- SayAll：<版本>，安装路径 <路径>
- VB-CABLE：已安装 / 未安装
- 重启：已完成 / 待用户重启
- 遥控器：<显示名>，ATVV 正常 / 异常
- SayAll 语音设备：CABLE Input / CABLE In 16ch
- 微信输入法麦克风：CABLE Output
- 热键：Ctrl + Win
- 端到端测试：通过 / 失败（附现象）
- 未完成项：<列表>
- 需要用户做的事：<列表>
```

---

## 11. 关键标识速查

| 项目 | 值 |
| --- | --- |
| 遥控器型号 | RC003-MS |
| Windows 显示名 | `MI RC` 或「小米蓝牙语音遥控器」 |
| VID | `2717` |
| PID | `32B8` |
| ATVV 服务 UUID | `AB5E0001-5A21-4F05-BC7D-AF01F617B664` |
| SayAll 语音设备 | `CABLE Input (VB-Audio Virtual Cable)` |
| 备选播放端 | `CABLE In 16ch (VB-Audio Virtual Cable)` |
| 微信输入法麦克风 | `CABLE Output (VB-Audio Virtual Cable)` |
| 语音热键 | `Ctrl + Win`（`left_control + left_windows`） |
| SayAll 1.0.0 SHA-256 | `E36853BF4723E4C6E428120AFB391FAD4A059CC27B836574B5E9E9F0036632D2` |
| SayAll build | `a4c1311d405509daf486fff3c82f7c8ec76f03fe` |

---

## 12. 参考资料

- SayAll 项目：https://github.com/GetSayAll/remote-mic-app-windows
- SayAll 安装与配置：https://github.com/GetSayAll/remote-mic-app-windows/blob/main/docs/installation-and-configuration.md
- SayAll Issue #112（GATT 状态 1 解释）：https://github.com/GetSayAll/remote-mic-app-windows/issues/112
- VB-Audio 官方：https://vb-audio.com/Cable
- 微信输入法官方下载：https://z.weixin.qq.com/
- 小米产品页：https://www.mi.com/xiaomi-bluetooth-remote-2-pro
- 小米官方 FAQ：https://www.mi.com/tw/support/faq/details/KA-05732

本地配套文档：

- 用户操作手册：`D:\Codex Work\我的助理\硬件资料\Windows蓝牙语音键盘\小米蓝牙遥控器2Pro_RC003-Windows语音键盘-操作手册.md`
- 官方资料说明：`D:\Codex Work\我的助理\硬件资料\Windows蓝牙语音键盘\官方资料\小米蓝牙遥控器2Pro_RC003_官方资料与配对说明.md`
- 购买链接与项目资料：`D:\Codex Work\我的助理\硬件资料\Windows蓝牙语音键盘\购买链接与项目资料.md`

---

## 13. 变更记录

| 日期 | 版本 | 变更 |
| --- | --- | --- |
| 2026-10-23 | v1.1 | 补充「Co 配置 → 锁定当前按键」排障门，纠正物理键盘同名键失灵的错误判断 |
| 2026-10-23 | v1.0 | 首次成文，明确用户与 Agent 分工，固化安装、配置、诊断、验收流程 |

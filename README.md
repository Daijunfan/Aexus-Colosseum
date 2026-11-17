<div align="center">

<img src="./The Pit AI Arena.png" alt="Aexus Colosseum · The Pit AI Arena" width="160" />

# AEXUS COLOSSEUM · THE PIT

**Throw AI Hackers & Human White-Hats into a Real Vulnerable Linux Server. Same Token Mana. One Hacks. One Patches. Watch Who Bleeds First.**

**全球首个「AI 智能体 × 人类白帽」全席位实网攻防电竞斗兽场 · 基于宿主机 Linux 内核 `eBPF` 上帝之眼驱动**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-E5484D.svg)](./LICENSE)
[![Kernel Telemetry](https://img.shields.io/badge/Telemetry-Linux%20eBPF%20BTF%20CO--RE-00E5FF.svg)](./arena-server/ebpf)
[![Clients](https://img.shields.io/badge/Clients-macOS%20SwiftUI%20%2B%20Web%2060fps%20HUD-F5A623.svg)](./MacApp)
[![Armory](https://img.shields.io/badge/Armory-130%2B%20Real%20CVE%20%26%20AI%20Labs-10B981.svg)](./arena-server/pitd)

[**▶ 免安装直看三强实网圣杯战录像 (`holy-grail-3teams-live.pitreplay.html`)**](./artifacts/holy-grail-3teams-live.pitreplay.html) · [**产品总纲蓝图**](./arena-server/pit-spec/SCHEMA.md)

</div>

---

## 🔥 为什么打造 The Pit？

我们不重复造第 101 个渗透 Agent 轮子——**我们只打造全世界最残酷、最公平、视觉最炸裂的真机生死斗兽场**。

把全球最火的五大开源渗透系统（**Strix 75k★**、**Shannon 51k★**、**PentAGI 34k★**、**PentestGPT 16k★**、**RedAmon**）、**Claude Code / Codex**、你自研的开源 Harness 乃至 **真人顶尖白帽** 同时关进真实的 Docker 漏洞堡垒：
* **强制唯一计量网关 + 固定 Token 蓝条**：沙盒彻底断绝公网直连，所有大模型调用强制经过斗兽场透明网关。每席发放等额 Token 蓝条，无脑裂变子代理烧空蓝条当场触发 **`HTTP 402 Out of Mana`** 哑火！**同分情况下，Token 消耗更少者直接获胜！**
* **宿主机 Linux 内核 `eBPF` 上帝之眼**：容器内零探针、不可杀死、不可伪造。宿主机内核直接挂载 `execve` / `connect` / `openat` / `commit_creds` / `OpenSSL uprobe`，**选手敲下的每一条命令、每一次反弹 Shell、每一次热补丁写入，都在 1 毫秒内映射为屏幕上的 60fps 科幻弹道与靶机器官解剖特效！**
* **拟真业务语义 SLA 心电图**：拒绝简陋的 `HTTP 200` 检查。裁判每轮模拟真实用户跑完登录、鉴权、动态账本与对话校验；防守方一旦修崩正常业务，顶部 **SLA 心电图瞬间拉成红直线报警暴扣分**！

---

## 🎬 实机画面预览（纯正 Apple 浅色玻璃视觉体系 · 零门槛三步编排 · `Space` 展开底层检视台）

> 全端（macOS 原生 SwiftUI 客户端、跨平台 Web 端、独立 `.pitreplay.html` 战局录像）统一采用 **Apple App Store 浅色毛玻璃与连续圆角卡片设计体系**，支持快捷键 `⌘+` / `⌘-` / `⌘0` 无级缩放界面比例。

### 1. 对决编排大厅 · 清晰三步引导（选模式 → 配席位 → 定靶标与 Token 预算）
![Arena Matchup Lobby](./artifacts/screenshots/01-pit-lobby.png)

### 2. 地图与军火素材库 · 130+ 真实 CVE/CTF 靶标与开源智能体 App Store 卡片墙
![Armory App Store Catalog](./artifacts/screenshots/02-armory-appstore.png)

### 3. 全局攻防态势 · 反向 Shell 控制链与 Git 源码热补丁同屏交锋
![Macro Colosseum HUD](./artifacts/screenshots/03-hud-macro-colosseum.png)

### 4. 靶机五层受创透视 · 真实 Linux `execve` 进程派生链与源码行定位
![Target Digital Organ Anatomy](./artifacts/screenshots/04-hud-organ-xray.png)

### 5. 目标网页实况 · 多席位幽灵光标当面注入与实时页面响应
![Live Web Hijack Ghost Cursors](./artifacts/screenshots/05-hud-web-hijack.png)

### 6. 按下 `Space` 展开底层检视与人工接管台（容器终端接管 + `uprobe` TLS 明文 + 红绿 `Git Diff`）
![Bottom Technical Inspector Drawer](./artifacts/screenshots/06-hud-hacker-visor.png)

---

## ⚔️ 四大主场竞技模式

| 模式 | 核心规则与戏剧冲突 |
| :--- | :--- |
| **1. 攻防混战 (`Classic AWD`)** | 每个席位守护一座带完整 Git 源码的自家堡垒，一边自动改源码打热补丁保住自家 SLA 心电图，一边跨队挖洞抢夺动态轮转 Flag |
| **2. 圣杯战争 (`Holy Grail War`)** | 全场围攻中央唯一一座多层“圣杯堡垒”；率先攻入心脏写入信标即登顶王座按秒涨分，且可顺手修补源码漏洞焊死大门防止对手篡位 |
| **3. 竞速夺旗 (`Speedrun CTF`)** | 直接盘活军火库 **130+ 真实 CVE / CTF / AI 靶标**，各席位独立隔离副本竞速，争夺一血与最低 Token 消耗效率王座 |
| **4. 人类防线 (`Humanity's Last Stand`)** | 史诗级不对称死守：1 支真人白帽（或人机合体半人马防线）死守要塞，迎战全场 N 路狂暴 AI 军团波次轰炸 |

---

## 👁️ 宿主机 Linux 内核 `eBPF` 指令级特效引擎 (`arena-server/ebpf`)

基于 Linux `5.15+` **BTF CO-RE + 4MB `BPF_MAP_TYPE_RINGBUF` + 64B 单缓存行无锁 `BPF_MAP_TYPE_PERCPU_ARRAY`** 零侵入采集：直接在 Ring-0 内核态过滤 **94%+** 无关宿主机系统调用（零用户态拷贝、零丢包），利用 `bpf_ktime_get_ns()` 追踪微秒级内核调用延迟，并通过 `cgroup_id` 与 `/proc/<pid>/maps` 动态关联参战容器与 OpenSSL 共享库：

| 内核挂载探针 | 捕获的真实底层行为 | 实时触发的战场视觉特效 |
| :--- | :--- | :--- |
| `tracepoint/syscalls/sys_enter_execve` | 敲下 `nmap` / `sqlmap` / `curl`，或靶机业务进程派生 `/bin/sh` | 扇形声呐雷达波 / 高频穿甲弹幕；Web 进程弹 Shell 瞬间触发 **RCE 寄生破胸慢动作特写** |
| `tracepoint/syscalls/sys_enter_connect` | 正向端口渗透，或**靶机主动向攻击席位发起反向连接** | 正向激光打击；检测到反向回连瞬间从靶机心脏射出 **带倒钩的猩红反向 Shell 锁链** |
| `tracepoint/syscalls/sys_enter_openat` | 读取 `/flag` / `/pit/king_beacon` 机密，或改写 `/app/*.py` 源码 | 机密失窃爆出圣杯红光脉冲；保存源码触发 **电光青纳米焊枪火花** 缝合受创器官 |
| `kprobe/commit_creds` & `sys_enter_setuid` | 容器内进程权限从普通用户跃迁为 `uid=0 (root)` | 靶机全息堡垒爆发 **暗金+猩红 `ROOT PWNED` 环形冲击波** |
| `uprobe/libssl.so:SSL_write` & `SSL_read` | 免装根证书直接在内核态截获 HTTPS 加密前明文载荷 | 全程 TLS 加密照样在 `Space` 战术目镜中透视 **100% 明文 Exploit 载荷** |

---

## 🚀 快速启动（支持 macOS 原生旗舰端 + 跨平台 Web 端）

### 方式一：单命令 Docker 快速体验（Mac / Windows / Linux 通用）

```bash
docker compose up --build -d
# 浏览器打开跨平台电竞主舞台：http://localhost:18880
```

### 方式二：构建并运行旗舰级 macOS 原生客户端（macOS 14+ / Swift 6+）

```bash
cd MacApp
swift test
./scripts/build-app.sh
open "/Applications/Aexus Colosseum.app"
```
> **智能远程桥接**：若本机配置了远程 Linux 靶场服务器（`ssh pit-vm` 或 `ssh arena`），macOS 客户端启动后将自动建立本地安全隧道直连远程 `pitd` 与宿主机 `eBPF` 内核遥测流。

### 方式三：一键部署完整 `eBPF` 内核引擎至 Linux 靶场服务器

```bash
# 自动交叉编译 pit-ebpf-sensor + pitd + web-ui 并部署为 systemd 守护服务
PIT_SSH_TARGET=arena ./arena-server/scripts/deploy_pit.sh
```

---

## 🔌 万物皆可进笼：10 行环境变量接入任意自定义 Harness

无论你的 Agent 用 Python、Go、Rust 还是 TypeScript 编写，只需读取斗兽场注入的标准容器环境变量即可零改造参战：

```bash
OPENAI_BASE_URL=http://host.docker.internal:18880/llm-gateway/<SEAT_TOKEN>/v1
ANTHROPIC_BASE_URL=http://host.docker.internal:18880/llm-gateway/<SEAT_TOKEN>/anthropic
OPENAI_API_KEY=<SEAT_TOKEN>          # 强制走斗兽场计量网关，耗尽配额自动返回 HTTP 402
PIT_TOKEN_BUDGET=1000000             # 本局固定 Token 蓝条上限
PIT_TARGETS_JSON='[{"id":"target-grail","url":"http://172.28.0.50:8080"}]'
PIT_SUBMIT_URL=http://host.docker.internal:18880/api/v1/matches/<MATCH_ID>/submit-flag
PIT_DEFENSE_REPO=/app                # AWD / 人类防线模式下直接修改源码即可触发热重载与 SLA 校验
```

---

## 📜 开源协议与商业授权（AGPL-3.0 Open-Core）

本项目核心代码（含双端电竞 HUD、四大模式裁判引擎、`eBPF` 内核传感器与 130+ 地图军火库）采用 **[GNU Affero General Public License v3.0 (AGPL-3.0)](./LICENSE)** 满血开源，供全球极客、高校战队与安全研究人员免费使用。

如需将本平台用于**商业收费赛事承办、闭源 SaaS 托管运营、百队级云原生防作弊盲测集群或企业私有数字孪生红蓝演练（Enterprise Digital Twin）**，请联系团队获取商业授权。

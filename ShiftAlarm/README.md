# 班表闹钟 · iOS 工程（v0.1）

这是原型（`../prototype/`）对应的原生实现：SwiftUI + AlarmKit，**iOS 26**。
数据层用 `Codable` + `UserDefaults` 存本机（单机一份排班够用，也避开了 SwiftData 的迁移坑），
要 iCloud 同步时只需替换 `PlanStore`。

> ⚠️ 这份代码是在 Windows 上写的，**没有在 Xcode 里编译过**。
> 语法我用 tree-sitter 全量校验过（11 个文件 0 错误），但类型层面的问题只有真机能暴露。
> 如果第一次 Run 报错，先看文末「常见报错」。

---

## 一、你需要什么

| 条件 | 说明 |
| --- | --- |
| iOS 26 的 iPhone | AlarmKit 是 iOS 26 的框架，低版本装上也用不了 |
| 一台能编译的机器 | 不一定非得是你的（见下一节） |
| Apple ID | 免费账号就能装到自己手机，签名 7 天过期 |

## 二、没有 Mac 怎么装到 iPhone

| 路线 | 花钱 | 首次耗时 | 真机响铃 | 适合谁 |
| --- | --- | --- | --- | --- |
| **A. 借一台 Mac** | 0 | ~30 分钟 | ✅ | 同事/朋友/家人有 Mac，最省事 |
| **B. GitHub 出包 + Windows 侧载** | 0 | 2~3 小时 | ✅ 7 天签一次 | 完全没有 Mac |
| **C. 云 Mac 按小时租** | ¥10~40/天 | 1~2 小时 | ⚠️ 只能看模拟器 | 想改 UI、看实际效果 |
| **D. 99 美元开发者账号 + TestFlight** | $99/年 | 半天 | ✅ 90 天 | 打算长期做 / 给别人装 |

### B 路线：GitHub Actions 出包，Windows 侧载（推荐给「没有 Mac」）

工作流我已经写好了：`.github/workflows/build-ipa.yml`。它会在 GitHub 的 macOS 机器上
装 XcodeGen → 生成工程 → 编译 → 打一个**未签名 IPA**。

1. 建一个 GitHub 仓库（Public 免费不限量；Private 每月约 200 分钟 macOS 额度，够跑 30 多次）
2. 把整个文件夹 push 上去（`.github/`、`ShiftAlarm/`、`.gitignore` 都要）
3. 仓库页 → **Actions** → 左边选 *Build unsigned IPA* → **Run workflow**
4. 等 3~5 分钟，进这次运行，页面底部 **Artifacts** 下载 `ShiftAlarm-unsigned-ipa`
5. Windows 上装 [Sideloadly](https://sideloadly.io/)（或 AltStore）
6. iPhone 连数据线 → Sideloadly 里拖入 IPA → 填你的 Apple ID → Start
7. iPhone：**设置 › 通用 › VPN与设备管理** → 信任你的 Apple ID
8. 打开 App → 允许「系统闹钟」授权 → 它会排未来 14 天的闹钟

几个必须知道的点：

- **7 天过期**：免费账号签的 App 一周后打不开，重跑一次 Sideloadly 就行。
  想自动续期：Windows 上装 AltServer + 手机装 AltStore，同一 Wi-Fi 会自动重签。
- **最多 3 个**自签 App；**必须开「开发者模式」**（设置 › 隐私与安全性）。
- **一个不确定点**：个别 Xcode 26 版本会要求 `com.apple.developer.alarmkit` entitlement，
  而开发者门户里暂时没有单独的 AlarmKit capability。如果 App 能打开、也点了授权，
  但闹钟就是排不进系统，多半是卡在这里 —— 那就只能走 D 路线。

### C 路线：云 Mac

Scaleway（Apple Silicon 按小时计费）、MacinCloud（$1/小时起）。远程桌面里跑 Xcode，
能连模拟器看界面，**但模拟器不会真的响闹钟**。要装真机仍然要导出 IPA 回本地侧载，
所以它更适合「改 UI、调样式」，不适合「验证闹钟」。

### D 路线：付费开发者账号

$99/年 + App Store Connect。GitHub Actions 可以用 App Store Connect API Key 自动上传 TestFlight，
90 天有效、能邀请 100 人测试，不用侧载、不用连电脑。打算长期做的话这是正解。

> 我的建议：**先问一圈有没有人借你 20 分钟 Mac**（A 最快）；没有就走 B。

## 三、有 Mac 的话：三步跑起来

```bash
brew install xcodegen
cd ShiftAlarm && xcodegen generate
open ShiftAlarm.xcodeproj
```

然后在 Xcode 里：选中 **ShiftAlarm** target → **Signing & Capabilities** → Team 选你的 Apple ID
（Bundle ID 被占用就改成 `com.你的名字.ShiftAlarm`）→ 顶部设备选 **你的 iPhone** → **Run**（⌘R）。

只想出包不调试？Mac 上直接跑：

```bash
cd ShiftAlarm && ./build-unsigned-ipa.sh
# 产物：ShiftAlarm/ShiftAlarm-unsigned.ipa，拿回 Windows 侧载
```

## 四、工程结构

```
ShiftAlarm/
├── project.yml                  XcodeGen 配置（Info.plist 和 scheme 也从这里生成）
├── build-unsigned-ipa.sh        Mac 上一键出未签名 IPA
└── Sources/
    ├── ShiftAlarmApp.swift      @main + TabView 根视图 + 排闹钟触发
    ├── Plan.swift               数据模型 + 排班/闹钟计算 + 日期工具（纯逻辑，无 UI）
    ├── PlanStore.swift          @Published + UserDefaults 持久化
    ├── AlarmService.swift       ★ 唯一依赖 AlarmKit 的文件（授权 / 排 / 撤）
    ├── Theme.swift              颜色、卡片、班次色块、下一个闹钟大卡
    ├── CalendarView.swift       月历 + 月度统计 + 日格子
    ├── DayDetailView.swift      点某天：改班次 / 开关当天闹钟
    ├── CrewsView.swift          5×7 班组矩阵 + 改名
    ├── RulesView.swift          预设、循环编辑、起始日、班次时间
    ├── AlarmsView.swift         闹钟列表 + 同步 + 权限
    └── SettingsView.swift       设置弹层
```

`Plan.swift` 是纯函数，不依赖 UI 和 AlarmKit，方便单独写测试：

```swift
plan.baseShift(on: date, crew: 0)   // 10 天一轮、5 个班、错开 2 天
plan.alarmDate(on: date)            // 夜班会落到前一天 23:15
plan.upcomingAlarms(days: 14)       // 要排进系统的那批
```

## 五、AlarmKit 的三个坑（代码里已经绕开）

1. **不能用 `.relative(Time)` 排未来多天。**
   相对时间只会落到「今天或明天的那个时刻」，排 14 天会全挤到最近两天。
   正确做法是 `.fixed(Date)` —— 代码里已经这么用了。

2. **用了 `countdownDuration`（稍后提醒）就必须带 Widget Extension**，
   否则系统可能直接忽略你的闹钟。v0.1 不带倒计时，只保留「停止」按钮，保证一定响。
   要加稍后提醒：新建 Widget Extension → 实现 `AlarmAttributes` 的 Live Activity →
   再把 `countdownDuration` 和 `.repeatButton` 加回去。

3. **必须在 `Info.plist` 里有 `NSAlarmKitUsageDescription`**，缺失或空字符串会导致**完全无法排闹钟**。
   这一条在 `project.yml` 的 `info.properties` 里已经写好。

## 六、常见报错

| 报错 | 原因 / 处理 |
| --- | --- |
| `Cannot find 'AlarmManager' in scope` | Xcode 低于 26，或 Deployment Target 不是 iOS 26 |
| `Provisioning Profile Missing com.apple.developer.alarmkit` | 签名时多加了这行 entitlement：从 `.entitlements` 里删掉它再签 |
| `AlarmMetadata` 遵循报错 | Xcode 26 默认把类型推断成 `@MainActor`，给 `ShiftAlarmMetadata` 加 `nonisolated` |
| 编译过但闹钟不响 | ① 没授权 ② 跑在模拟器 ③ 系统「设置 › 班表闹钟 › 闹钟」被关 |
| `AlarmPresentation.Alert` 参数对不上 | 只改 `AlarmService.swift` 那一处，按 Xcode 补全调整 |
| 签名失败 | Team 没选、Bundle ID 重复、设备没开开发者模式 |

## 七、下一步

- 跑通「授权 → 排闹钟 → 到点响」之后再谈优化
- 补 Widget Extension，加回「稍后提醒 / 锁屏倒计时」
- 换 SwiftData + CloudKit，换手机也能同步
- 加「换班」（和同事对调某一天，仅影响两人）

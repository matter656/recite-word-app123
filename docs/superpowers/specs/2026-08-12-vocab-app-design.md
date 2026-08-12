# 背单词 App — 设计文档（第一阶段）

- 日期：2026-08-12
- 状态：已确认（用户已审阅并调整：词书增加考研、雅思；环境由 AI 安装至 D 盘）

## 1. 项目定位

Android 背单词 App，卡片回忆模式（类似 Anki），内置词书与例句。
**一期**纯本地存储，通过 Repository 接口预留云同步能力，**二期**实现账号体系与云同步。
目标：正式上架应用商店（国内安卓商店为主）。

## 2. 目标用户与背景

- 用户：会一点编程，未做过 App；AI 主导实现，用户提需求与验收。
- 平台：先只做 Android；Flutter 保证未来可扩展 iOS。

## 3. 技术栈

| 层 | 选型 | 说明 |
|---|---|---|
| UI | Flutter (Dart) | 一套代码，未来可扩 iOS |
| 数据库 | SQLite（sqflite） | 存词库、学习进度、复习计划；选 sqflite 而非 drift：零代码生成、依赖少 |
| 状态管理 | Riverpod | 简单可靠 |
| 架构 | UI → Repository → 数据 分层 | Repository 接口是二期云同步的预留点 |

## 4. 功能范围

### 4.1 一期功能

1. **内置词书（4 本）**：四级、六级、考研、雅思。
   - 词条字段：`word`, `phonetic`（音标）, `meaning`（中文释义）, `example`（例句）, `source`（词书标识）
   - 词库以 JSON 打包进 `assets`，首次启动导入 SQLite
2. **学习流程**：
   - 选择词书 → 生成当日卡片队列（新词 + 到期复习词）
   - 卡片正面：单词（+音标）；翻面：释义 + 例句
   - 自评：记得 / 模糊 / 忘了
3. **间隔重复**：SM-2 算法（Anki 同款），自动调度复习时间
4. **进度统计**：已学单词数、待复习数、连续打卡天数（streak）
5. **设置**：切换词书、每日新词数量、每日提醒（本地通知）

### 4.2 二期功能（本期不实现，仅预留接口）

- 账号体系（用户名/邮箱+密码起步，避免短信费用）
- 云同步：Repository 接口 + 数据变更日志（change log）设计，二期接 LeanCloud 国内版或自建后端
- 本地优先架构：二期上线后，本地库仍是主数据源，云端负责备份与多设备合并

## 5. 数据模型（一期）

- `Word`：id, word, phonetic, meaning, example, book（词书）
- `Book`：id, name, description, word_count
- `CardState`：word_id, book_id, status（new/learning/reviewing/mastered）, ease_factor, interval_days, due_date, review_count, last_reviewed_at
- `StudyLog`：id, date, word_id, rating, reviewed_at（供统计与打卡）

## 6. 数据流

1. 首次启动：`assets/wordbooks/*.json` → 校验 → 导入 SQLite → 初始化默认设置
2. 学习时：按词书查当日队列（新词按每日新词数、复习词按 due_date）→ 展示卡片 → 用户自评 → 更新 CardState（SM-2 计算）→ 写 StudyLog
3. 所有数据访问通过 Repository 接口；二期新增云端实现替换，不动 UI 层

## 7. 错误处理

- 数据库初始化失败 / 词库导入失败：可重试的错误提示，不闪退
- 全局异常捕获（FlutterError + PlatformDispatcher），记录日志
- 无网络相关逻辑（一期纯本地）

## 8. 测试策略

- SM-2 算法：单元测试（含边界：首次评分、ease factor 上下限、interval 增长）
- Repository 层：内存/测试数据库验证增删改查与队列生成
- 核心页面：Widget 测试（词书选择、卡片翻面、自评）

## 9. 里程碑

| 阶段 | 内容 | 验收标准 |
|---|---|---|
| M1 | 安装 Flutter SDK + Android SDK（D 盘），创建项目骨架 | `flutter run` 能启动空 App |
| M2 | 词库数据（4 本词书 JSON）+ 数据库模型 + 导入逻辑 | 首次启动导入成功，单测通过 |
| M3 | 背诵主流程：卡片 + 翻面 + 自评 + SM-2 调度 | 能完整背一轮词并生成复习计划 |
| M4 | 统计、设置、UI 打磨 | 打卡/统计正确，设置生效 |
| M5 | 上架准备：图标、签名、隐私政策、打包 APK | 产出可安装的 release APK |
| M6(二期) | 账号 + 云同步 | 另行规划 |

## 10. 环境与合规

- Flutter SDK 与 Android SDK 安装至 **D 盘**（用户指定，D 盘空间大）
- 词库数据来源：开源词库（如 GitHub ECDICT，MIT 协议）整理出 4 本词表；上架前复核版权与词条质量
- 上架前需准备：隐私政策、App 备案（国内商店）、签名证书

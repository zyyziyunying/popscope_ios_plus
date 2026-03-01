# Direct Mode 重构：M1 -> M2 准入门槛（Gate）

> 生效日期：2026-03-01  
> 适用阶段：`M1 收口` -> `M2 测试矩阵`  
> 适用范围：`popscope_ios_plus` iOS 返回拦截重构链路

## 1. 目的

给出**唯一、可执行、可审计**的下一步判定标准，避免“感觉差不多”就推进阶段。

结论规则只有两种：

- **PASS**：全部硬门槛通过，允许进入 M2
- **FAIL**：任一硬门槛失败，继续停留在 M1 收口

---

## 2. 判定原则（强约束）

1. 只看证据，不看口头结论。  
2. 所有检查项都必须有“执行记录 + 时间 + 责任人”。  
3. 任一 P0 风险未闭环，直接 FAIL。  
4. 文档未更新到最新执行结果，视为未完成。  

---

## 3. 硬门槛清单（必须全绿）

### G1. 生命周期与状态一致性

- [ ] `enable/disable` 为成对语义，且幂等（重复调用无副作用）  
- [ ] Dart 侧不使用乐观写入，native 失败后可回滚  
- [ ] `missing_root` 失败路径可自动重试（最多 3 次，行为可观测）  
- [ ] 页面退出后无残留手势钩子（可通过日志或测试证明）

**证据要求**：`flutter test` 对应用例通过 + 日志片段（含 `source/state/route/action`）。

### G2. 单手势单决策（去重）

- [ ] 同一次返回意图最多触发一次业务决策  
- [ ] `IosPopInterceptor` 不出现 native 事件与 `onPopInvokedWithResult` 双触发  

**判定标准**：在“快速连续左滑 + 点击返回按钮”混合场景下，业务回调计数与预期一致（0 重复）。

### G3. 误触发防线

- [ ] 导航栈深度不足（`<=1`）时，不应触发返回拦截事件  
- [ ] 原 delegate 拒绝手势时，插件不应强行触发  
- [ ] 横滑组件（PageView/ListView.horizontal）场景误触发可控

### G4. 自动化测试门槛

- [x] `flutter test` 通过  
- [x] `example/integration_test` 覆盖核心手势链路（不能只测 `getPlatformVersion`）

`integration_test` 至少包含以下场景：

1. 有业务回调时优先回调（不误 `maybePop`）  
2. 无业务回调且启用自动导航时触发 `maybePop`  
3. 最后一个 consumer 移除后触发 disable  
4. `missing_root` 失败后自动重试路径  
5. 异常路径可观测（失败原因可定位）

### G5. 手测矩阵门槛

- [ ] WebView 页面：有历史记录时先消费 WebView 返回  
- [ ] PageView / 横向列表：滑动不应被大面积误判为返回  
- [ ] 多路由栈（A->B->C）：只由顶层页面消费返回意图  
- [ ] 快速短滑/取消手势：不应出现重复回调风暴  
- [ ] 前后台切换后：返回拦截链路仍稳定

**环境要求**：至少 1 台 iOS 真机 + 1 套模拟器环境。

---

## 4. 输出物要求（进入 M2 前必须齐全）

1. 测试结果记录（命令、结果、日期）  
2. 手测记录表（场景、设备、结果、问题单）  
3. 更新 `progress/direct_mode_rebuild_progress.md` 当前状态与阻塞项  
4. 更新 `doc/direct_mode_rebuild_decision.md` 执行进展章节  

---

## 5. Gate 记录（2026-03-01 第 1 轮评审）

| Gate | 结果(PASS/FAIL) | 证据（文件/日志/测试） | 责任人 | 日期 |
|---|---|---|---|---|
| G1 生命周期一致性 | FAIL | `flutter test` 生命周期用例通过；日志证据（`source/state/route/action`）归档未补齐 | Codex | 2026-03-01 |
| G2 单手势单决策 | FAIL | 已有同帧防重入实现与单测，但“快速左滑+返回按钮”混合手势手测未完成 | Codex | 2026-03-01 |
| G3 误触发防线 | FAIL | 栈深/原 delegate 协同逻辑已落地；横滑组件误触发矩阵手测未完成 | Codex | 2026-03-01 |
| G4 自动化测试 | PASS | `flutter test`（14/14）+ `example/integration_test/plugin_integration_test.dart`（5/5，iOS 模拟器执行） | Codex | 2026-03-01 |
| G5 手测矩阵 | FAIL | 未提交 WebView/PageView/多路由/快速手势/前后台切换记录表 | Codex | 2026-03-01 |

**总评**：`FAIL`  
**是否允许进入 M2**：`否`

---

## 6. 当前状态（2026-03-01）

- 已完成：G4 自动化门槛（单测 + integration_test 核心 5 场景）。  
- 进行中：G1 生命周期证据归档、G2 混合手势去重验证、G3 误触发场景回归。  
- 未完成：G5 全量手测矩阵（真机 + 模拟器）。  
- 当前结论：**FAIL（暂不允许进入 M2）**。

---

## 7. 执行记录（命令/结果/时间/责任人）

1. `flutter test` -> 14/14 通过（2026-03-01，Codex）。  
2. `cd example && flutter test integration_test/plugin_integration_test.dart -d 563ABB01-D10A-44EF-9C16-6A8ABD33A73C` -> 5/5 通过（2026-03-01，Codex）。  
3. `flutter analyze` -> 5 条 info、0 error/warning（2026-03-01，Codex）。

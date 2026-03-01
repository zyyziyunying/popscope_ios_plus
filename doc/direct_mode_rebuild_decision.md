# Direct Mode 实验功能问题记录与重构决策

> 日期：2026-03-01  
> 状态：执行中（M1 收口中，核心阻塞已处理，待补测试矩阵）

## 1. 文档目的

记录当前 Direct Mode（`UIScreenEdgePanGestureRecognizer` 实验方案）的关键问题，并明确后续策略：**停止修补旧代码，直接清理并从零重写**。

---

## 2. 当前结论（强制执行）

1. 现有 Direct Mode 返回链路不稳定，存在重复触发、状态污染、误触发与可观测性不足问题。  
2. 该能力当前不具备继续增量迭代价值。  
3. 后续仅接受“重构版”方案，不再对旧实验实现打补丁。

---

## 3. 问题清单（按严重级别）

### P0-1：一次手势可能触发多次回调（重复上报风险）

- 现象：同时监听 direct-edge、fallback-pan、interactive-pop，且旧 delegate 拦截路径仍可触发。
- 证据：
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:241`
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:275`
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:289`
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:307`
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:331`
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:409`
- 影响：业务层可能收到回调风暴，导致重复弹窗、重复 pop、状态错乱。

### P0-2：生命周期不完整，存在全局状态污染

- 现象：启用后缺乏完整 disable/restore，Dart 侧仅注销回调，iOS 手势钩子仍可能保留。
- 证据：
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:176`
  - `lib/popscope_ios_method_channel.dart:252`
  - `lib/popscope_ios_method_channel.dart:232`
  - `lib/widgets/ios_pop_interceptor.dart:115`
- 影响：页面退出后依然影响后续页面，问题跨路由传播，排查成本高。

### P0-3：运行时替换 rootViewController 侵入性过强

- 现象：无导航容器时，插件修改 `window.rootViewController` 以强行接管流程。
- 证据：
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:133`
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:146`
  - `doc/ios_gesture_learning_guide.md:177`
- 影响：高耦合、高风险，易引发宿主 App 生命周期与视图层级副作用。

### P1-1：失败路径偏静默，启用结果与 UI 感知可能不一致

- 现象：native 返回失败时仅 warn，不抛显式错误；示例页可能显示“已启用”。
- 证据：
  - `lib/popscope_ios_method_channel.dart:293`
  - `lib/popscope_ios_method_channel.dart:297`
  - `lib/widgets/ios_pop_interceptor.dart:75`
- 影响：误导测试结论，降低可观测性。

### P1-2：误触发防线薄弱

- 现象：fallback 主要依赖起点边缘判定；`.began` 即触发，无取消/确认语义。
- 证据：
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:401`
  - `ios/popscope_ios/Sources/popscope_ios/PopscopeIosPlugin.swift:330`
  - `doc/direct_edge_gesture_experiment.md:121`
- 影响：横滑组件、轻触/短滑场景下误判概率高。

### P1-3：验证闭环不完整

- 现象：实验验收表未填写结果；集成测试几乎不覆盖核心手势链路。
- 证据：
  - `doc/direct_edge_gesture_experiment.md:109`
  - `example/integration_test/plugin_integration_test.dart:18`
- 影响：缺乏可重复、可回归的“通过标准”。

---

## 4. 决策：完全重构（清理旧实现）

从本决策生效起：

1. **停止**对 Direct Mode 旧实现的一切功能性补丁。  
2. **允许删除**旧实验代码与示例入口（含 iOS/Dart/example 相关路径）。  
3. **新实现从零开始**，以“单一信号源 + 明确状态机 + 可回收生命周期”为基础。  
4. 重构未完成前，Direct Mode 不作为稳定能力对外承诺。

---

## 5. 重构版技术红线（必须满足）

1. 单次手势最多产生一次最终决策事件（无重复回调）。  
2. 禁止运行时替换 `rootViewController`。  
3. 必须具备成对的 enable/disable，且幂等。  
4. 触发判定基于明确阈值与状态流转（至少区分取消与完成）。  
5. 必须提供结构化日志（source/state/route/action）。  
6. 先有自动化与手测矩阵，再开放示例入口。

---

## 6. 实施里程碑（建议）

- M0：冻结旧实验入口（文档标红、示例下线、API 标记废弃/隐藏）。  
- M1：提交新架构最小实现（仅一条信号源 + 完整生命周期）。  
- M2：补齐单测/集成测试与手测矩阵，形成稳定验收标准。  
- M3：灰度开放示例，验证 WebView/横滑组件/多路由场景。

> M1 -> M2 的强制准入门槛见：`doc/direct_mode_m1_to_m2_gate.md`

---

## 7. 验收门槛（重构版）

1. 重复触发率：0（同一次手势）。  
2. 误触发率：在横滑列表/PageView 场景可复现测试中达标。  
3. 生命周期：页面离开后无残留钩子。  
4. 回归：核心测试用例全部通过。  
5. 文档：决策流程、边界条件、故障排查步骤完整。

---

## 8. 备注

本文件是 Direct Mode 旧实现的“问题归档 + 重构授权记录”。后续开发以本决策为准，不再回到“边修边补”的路径。

---

## 9. 执行进展（2026-03-01）

### 已完成（M0）

1. 已下线 Example 的 Direct Mode 入口与测试页面。  
2. 已移除 iOS 端 `enableDirectEdgeGesture` 旧实验链路。  
3. 已将 Dart 侧 Direct Mode API 标记为废弃并改为拒绝调用。  
4. 已补充文档状态说明（实验文档标记为历史归档）。  

### 已完成（M1-骨架 + 收口补强，2026-03-01）

1. iOS 端新增 interactive-pop 生命周期状态机（`disabled/enabling/enabled/disabling`），并补齐 `enable/disable` 成对通道。  
2. Dart 端新增原生生命周期同步器：基于 consumer 状态自动启停原生手势钩子，避免页面退出后残留。  
3. 新增结构化日志字段（`source/state/route/action`）并贯穿 native -> Dart 事件链路。  
4. 补充 MethodChannel 生命周期单测：验证 disable 回收与 enable 幂等行为。  
5. native `enable/disable` 改为显式返回（`success/state/reason`），Dart 侧改为 await 结果并失败回滚，修复状态分裂。  
6. 补齐 `missing_root` 失败路径自动重试（首帧后重试，最多 3 次）。  
7. `IosPopInterceptor` 增加同帧防重入，降低 native 事件与 `onPopInvokedWithResult` 双触发。  
8. native delegate 增加导航栈深度与原 delegate 协同判定，补强误触发防线。  
9. 补充生命周期回归单测：enable 失败回滚可重试、`missing_root` 自动重试。  
10. 补齐 `example/integration_test` 核心链路（回调优先、自动 maybePop、disable 回收、`missing_root` 重试、异常路径）并完成 iOS 模拟器执行。

### M1 收口剩余阻塞项（2026-03-01）

1. G5 手测矩阵（WebView/横滑组件/多路由/快速手势/前后台切换）尚未补齐，无法给出稳定性结论。  
2. `missing_root` 重试策略已实现，但复杂宿主启动时序仍需真机回归确认。

### 下一步（M1 收口 -> M2 准入）

1. 按 `doc/direct_mode_m1_to_m2_gate.md` 执行并记录 G5 手测矩阵（含设备、结果、问题单）。  
2. 完成 iOS 真机回归，确认 `missing_root` 重试在不同宿主启动时序下稳定。  
3. 回填 Gate 评审记录后，再评估是否进入 M2。  

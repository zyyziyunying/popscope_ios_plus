# Direct Mode 重构进度追踪

> 最后更新：2026-03-01  
> 负责人：Codex（执行）/ Owner（决策）

## 1. 当前状态

- 阶段：`M1 收口中`（G4 自动化门槛已通过，剩余 G5 手测矩阵）
- 总策略：停止修补旧 Direct Mode，实现重构版新链路
- 决策依据：`doc/direct_mode_rebuild_decision.md`
- 准入门槛：`doc/direct_mode_m1_to_m2_gate.md`

## 2. 里程碑看板

- [x] M0：冻结旧实验入口（文档标记、示例下线、旧链路清理）
- [ ] M1：新架构最小实现（核心能力已落地，待收口：集成测试与手测矩阵）
- [ ] M2：补齐测试矩阵（单测/集成/手测）
- [ ] M3：灰度开放新示例并验证复杂场景

## 3. 本次已完成内容（2026-03-01）

1. iOS 端已移除 Direct Mode 旧实验方法/回调链路。  
2. iOS 端已禁止运行时替换 `rootViewController`。  
3. Dart 侧 Direct Mode API 已标记废弃并改为抛出 `UnsupportedError`。  
4. Widget 旧参数 `useDirectEdgeGesture` 保留兼容但不再启用 Direct Mode。  
5. Example 已下线“直接模式测试”入口并删除页面。  
6. 相关测试已改为验证“下线后行为”。  
7. 文档已更新（`doc/` 下决策文档与实验文档归档说明）。  
8. iOS 端 interactive-pop 生命周期状态机与 `enable/disable` 通道已落地。  
9. Dart 侧已接入原生生命周期同步器与结构化日志字段。  
10. MethodChannel 生命周期单测已补充（disable 回收、enable 幂等）。  
11. native `enable/disable` 已改为显式返回 `success/state/reason`，Dart 不再乐观写入。  
12. Dart 生命周期同步已改为 `await` 结果 + 失败回滚，修复 native 失败时状态分裂。  
13. 新增 `missing_root` 失败路径首帧重试机制（最多 3 次，可控退避）。  
14. `IosPopInterceptor` 已增加同帧防重入，降低 native 事件与 `onPopInvokedWithResult` 双触发。  
15. iOS delegate 已补栈深度判断，并与原 delegate 协同判定，降低误触发概率。  
16. MethodChannel 单测新增：enable 失败回滚重试、`missing_root` 自动重试。  
17. `example/integration_test` 已补齐 5 条核心手势链路，并在 iOS 模拟器通过执行。  

## 4. 当前阻塞（M1 -> M2）

1. G5 手测矩阵（WebView/横滑组件/多路由/快速手势/前后台切换）尚未补齐。  
2. 缺少“1 台 iOS 真机 + 1 套模拟器”的手测记录表与问题单归档。  
3. `missing_root` 重试策略已落地，但复杂宿主启动时序仍需真机回归确认。

## 5. 验证结果

- `flutter test`：通过（2026-03-01，14/14）  
- `cd example && flutter test integration_test/plugin_integration_test.dart -d 563ABB01-D10A-44EF-9C16-6A8ABD33A73C`：通过（2026-03-01，5/5）  
- `flutter analyze`：存在 5 条 info（deprecated 用法），无 error/warning（命令退出码为 1）

## 6. 下一会话建议待办（M1 收口清单）

1. 按 `doc/direct_mode_m1_to_m2_gate.md` 完成 G5 手测矩阵并沉淀记录表。  
2. 增加 iOS 真机回归：`missing_root` 重试在不同宿主启动时序下的稳定性。  
3. 回填 Gate 评审表（责任人/日期/证据链接）并给出最终 M1 -> M2 判定。  

## 7. 风险与注意事项

- Direct Mode 已下线，后续不要再恢复旧 `enableDirectEdgeGesture` 路径。
- 新实现完成前，不对外承诺 Direct Mode 稳定能力。
- 任何新入口开放前，先完成测试矩阵和回归门槛。

# Direct Mode 重构进度追踪

> 最后更新：2026-03-01  
> 负责人：Codex（执行）/ Owner（决策）

## 1. 当前状态

- 阶段：`M0 完成`，准备进入 `M1`
- 总策略：停止修补旧 Direct Mode，实现重构版新链路
- 决策依据：`doc/direct_mode_rebuild_decision.md`

## 2. 里程碑看板

- [x] M0：冻结旧实验入口（文档标记、示例下线、旧链路清理）
- [ ] M1：新架构最小实现（单一信号源 + 生命周期闭环）
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

## 4. 验证结果

- `flutter test`：通过
- `flutter analyze`：通过（仅存在既有 info 级提示，非本次新增阻塞项）

## 5. 下一会话建议待办（M1 启动清单）

1. 设计并落地新状态机草图（事件、状态、转移、去重策略）。
2. 定义 enable/disable 成对 API（含幂等语义与失败返回）。
3. 先补最小单测再接入 native 实现，确保“单手势单决策”。
4. 增加结构化日志字段（source/state/route/action）。

## 6. 风险与注意事项

- Direct Mode 已下线，后续不要再恢复旧 `enableDirectEdgeGesture` 路径。
- 新实现完成前，不对外承诺 Direct Mode 稳定能力。
- 任何新入口开放前，先完成测试矩阵和回归门槛。

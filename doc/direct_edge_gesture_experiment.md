# 实验性方案：UIScreenEdgePanGestureRecognizer 直接模式

## 背景

### 原有方案的工作原理

popscope_ios 的核心功能是拦截 iOS 左滑返回手势。原有方案依赖 `UINavigationController.interactivePopGestureRecognizer`：

1. 获取（或创建）`UINavigationController`
2. 替换其 `interactivePopGestureRecognizer` 的 delegate
3. 在 `gestureRecognizerShouldBegin` 中拦截手势，返回 `false` 阻止系统 pop
4. 通过 MethodChannel 通知 Flutter 层

### 原有方案的痛点

- **必须依赖 UINavigationController**：Flutter 应用默认的 rootViewController 是 `FlutterViewController`，不一定有 `UINavigationController`
- **情况 2b 的侵入性**：当 `FlutterViewController` 没有被 `UINavigationController` 包装时，插件需要在运行时替换 `window.rootViewController`，这是一个侵入性操作，可能导致视图层次结构问题
- **复杂的 ViewController 查找逻辑**：需要处理多种 rootViewController 类型的情况

## 实验性方案

### 核心思路

使用 `UIScreenEdgePanGestureRecognizer` 直接在 `FlutterViewController.view` 上监听左边缘滑动手势，完全绕过对 `UINavigationController` 的依赖。

### 工作原理

```
用户从屏幕左边缘滑动
       ↓
UIScreenEdgePanGestureRecognizer 识别手势
       ↓
handleEdgeSwipe(_:) 在 .began 状态触发
       ↓
通过 MethodChannel 调用 "onSystemBackGesture"
       ↓
Flutter 层 _handleSystemBackGesture() 处理
       ↓
查找回调栈中有效的回调并执行
```

### 与原有方案的对比

| 维度 | 原有方案 (interactivePopGestureRecognizer) | 实验方案 (UIScreenEdgePanGestureRecognizer) |
|------|-------------------------------------------|---------------------------------------------|
| 依赖 | 需要 UINavigationController | 只需要 FlutterViewController |
| 侵入性 | 可能替换 rootViewController | 仅添加手势识别器，不修改视图层次 |
| 实现复杂度 | 需要处理多种 VC 类型 | 查找 FlutterViewController 即可 |
| 手势来源 | 系统原生的返回手势识别器 | 自定义的边缘手势识别器 |
| 跟手动画 | 无（直接阻止） | 理论上可扩展（通过 .changed 状态） |
| 成熟度 | 已验证 | 实验中，待验证 |

## 代码变更清单

### iOS 原生层

**`PopscopeIosPlugin.swift`**

- 新增属性：`edgeGestureRecognizer`（边缘手势识别器）、`flutterViewController`（弱引用）
- 新增方法：`setupDirectEdgeGesture()` — 在 FlutterViewController.view 上添加边缘手势
- 新增方法：`handleEdgeSwipe(_:)` — 处理边缘滑动，在 `.began` 时通知 Flutter
- 新增 MethodChannel 处理：`enableDirectEdgeGesture` 方法调用

### Dart 层

**`popscope_ios_method_channel.dart`**

- 新增方法：`enableDirectEdgeGesture()` — 调用原生端启用直接模式

**`popscope_ios.dart`**

- 新增方法：`enableDirectEdgeGestureForTesting()` — 实验性 API 入口

### Example 应用

**`example/lib/pages/direct_mode_test_page.dart`**（新增）

测试页面，包含 4 个验证场景：
1. 基本手势触发 — 从左边缘滑动
2. 水平列表冲突测试 — 在 `ListView.horizontal` 中滑动
3. 垂直列表边缘滑动测试
4. 灵敏度测试 — 快/慢滑动

页面包含实时日志和触发计数器，方便观察手势行为。

**`example/lib/main.dart`**

- 首页新增"直接模式测试"入口卡片

## MVP 验证要点

### 必须验证

| # | 验证项 | 预期结果 | 实际结果 |
|---|--------|----------|----------|
| 1 | 从左边缘向右滑动能否触发回调 | 触发计数 +1，日志记录 | |
| 2 | 水平列表中左右滑动是否误触发 | 不触发边缘手势 | |
| 3 | 垂直列表左边缘滑动是否能触发 | 正常触发 | |
| 4 | 快速滑动 vs 慢速滑动的一致性 | 两者都能触发 | |
| 5 | 从屏幕中间区域向右滑动 | 不触发（非边缘区域） | |

### 已知风险

1. **Flutter 内部手势竞争**：`FlutterViewController` 内部有自己的手势处理系统，`UIScreenEdgePanGestureRecognizer` 可能与 Flutter 的 `UIPanGestureRecognizer` 产生竞争。当前通过 `shouldRecognizeSimultaneouslyWith` 返回 `true` 允许同时识别，但可能导致 `PageView`、`TabBarView` 等水平滑动组件同时响应。

2. **`.began` 触发时机**：当前在手势 `.began` 状态就触发回调，即使用户随后取消手势（手指没有继续滑动）也会触发。后续可考虑在 `.ended` 且滑动距离超过阈值时才触发，或在 `.cancelled` 时通知 Flutter 取消。

3. **两种模式互斥**：直接模式和原有模式共用 `_iosGestureEnabled` 标志，不应同时启用。

4. **`UIApplication.shared.windows` 已废弃**：iOS 15+ 标记为 deprecated，后续正式化时需改用 `UIApplication.shared.connectedScenes`。

## 后续方向

如果 MVP 验证通过：

1. 将直接模式作为默认方案，替代原有的 `interactivePopGestureRecognizer` 方案
2. 评估是否需要保留原有方案作为 fallback
3. 处理 `.cancelled` 状态，支持手势取消通知
4. 考虑利用 `.changed` 状态实现跟手动画
5. 替换 deprecated 的 `UIApplication.shared.windows` API

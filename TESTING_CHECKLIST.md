# UINavigationController 包裹的测试清单

> ⚠️ 状态说明（2026-03-01）：本文件为历史检查项沉淀。  
> Direct Mode 重构当前阶段（M1 -> M2）请以 `doc/direct_mode_m1_to_m2_gate.md` 为唯一准入标准。

## ⚠️ 重要说明
当前实现会在必要时动态创建 UINavigationController 包裹 FlutterViewController。
虽然代码会优先使用已有的 NavigationController，但在某些情况下会运行时替换 rootViewController。

## 必须测试的场景

### 1. 基础功能
- [ ] 热重载（Hot Reload）正常工作

### 2. 系统 UI
- [ ] 状态栏样式正确（亮色/暗色）
- [ ] SafeArea 计算正确（尤其是刘海屏）
- [ ] 动态岛区域不被遮挡
- [ ] 横屏/竖屏切换正常

### 3. 与其他插件的兼容性
- [ ] 图片选择器（image_picker）
- [ ] 相机插件（camera）
- [ ] 分享插件（share_plus）
- [ ] WebView 插件（webview_flutter）
- [ ] 推送通知显示正常
- [ ] 第三方登录（微信、QQ 等）

### 4. 键盘处理
- [ ] 键盘弹出时视图正确上移
- [ ] TextField 焦点管理正常
- [ ] 键盘安全区域计算正确

### 5. 生命周期
- [ ] App 进入后台/前台切换正常
- [ ] didChangeAppLifecycleState 事件正确
- [ ] 内存警告处理

## 推荐的集成方式

### ✅ 最佳实践：在 AppDelegate 中预先配置

**ios/Runner/AppDelegate.swift**:
```swift
import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 创建 FlutterViewController
    let flutterViewController = FlutterViewController()

    // ✅ 预先包裹在 NavigationController 中
    let navigationController = UINavigationController(rootViewController: flutterViewController)
    navigationController.isNavigationBarHidden = true

    // 设置为 rootViewController
    self.window = UIWindow(frame: UIScreen.main.bounds)
    self.window?.rootViewController = navigationController
    self.window?.makeKeyAndVisible()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

这样做的好处：
1. ✅ 避免运行时替换 rootViewController
2. ✅ 视图层次在启动时就确定
3. ✅ 不会与其他插件的初始化冲突
4. ✅ 生命周期事件按预期触发

### ⚠️ 当前实现的风险场景

如果用户**没有**在 AppDelegate 中预先配置，插件会：
```swift
// 这会在运行时替换 rootViewController
window.rootViewController = nil
let newNavController = UINavigationController(rootViewController: flutterVC)
window.rootViewController = newNavController
```

可能的问题：
- 如果其他插件已经修改了视图层次，会被覆盖
- 如果在 Flutter 页面已经显示后才调用，可能导致闪烁
- 状态栏、键盘等系统 UI 可能需要重新计算

## 改进建议

1. **在文档中强烈建议预先配置**
2. **检测到动态创建时输出警告日志**
3. **考虑提供不依赖 NavigationController 的替代方案**（如果可能）

# popscope_ios_plus

一个用于拦截和处理 iOS 系统左滑返回手势的 Flutter 插件。

[![pub package](https://img.shields.io/pub/v/popscope_ios_plus.svg)](https://pub.dev/packages/popscope_ios_plus)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 功能特性

- ✅ 拦截 iOS 系统的左滑返回手势（interactivePopGesture）
- ✅ 使用 `BuildContext` 作为标识的页面级回调系统
- ✅ 自动清理已销毁页面的回调，防止内存泄漏
- ✅ 提供开箱即用的 Widget 组件（`PlatformPopScope`、`IosPopInterceptor`）
- ✅ 自动处理生命周期和资源清理
- ✅ 运行时验证和开发模式断言
- ✅ 详细的最佳实践文档和错误示例
- ✅ 仅在 iOS 平台生效，对其他平台无影响

## 为什么需要这个插件？

在 Flutter 中，当使用 `PopScope`（或旧版的 `WillPopScope`）并设置 `canPop: false` 时，iOS 的边缘滑动返回手势会被完全禁用。这意味着：

1. 用户无法通过滑动手势触发任何回调
2. 无法在用户滑动时显示确认对话框
3. 无法执行自定义的返回逻辑

`popscope_ios_plus` 通过拦截 iOS 原生的 `interactivePopGestureRecognizer`，让你能够：

- 在用户执行滑动返回手势时收到回调
- 执行自定义逻辑（如显示确认对话框、保存数据等）
- 决定是否允许页面返回

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  popscope_ios_plus: ^0.1.3
```

然后运行：

```bash
flutter pub get
```

## 使用方法

### 方式一：使用 PlatformPopScope（推荐）

`PlatformPopScope` 是一个跨平台的封装组件，会自动根据平台选择最佳实现：

```dart
import 'package:popscope_ios_plus/popscope_ios_plus.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlatformPopScope(
      canPop: false,
      onPop: () {
        // 显示确认对话框
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认退出？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // 关闭对话框
                  Navigator.pop(context); // 返回上一页
                },
                child: const Text('确认'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('我的页面')),
        body: const Center(child: Text('尝试左滑返回')),
      ),
    );
  }
}
```

### 方式二：使用 IosPopInterceptor

如果只需要在 iOS 上拦截手势，可以直接使用 `IosPopInterceptor`：

```dart
import 'package:popscope_ios_plus/popscope_ios_plus.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IosPopInterceptor(
      onPopGesture: () {
        // 处理返回手势
        Navigator.maybePop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('我的页面')),
        body: const Center(child: Text('尝试左滑返回')),
      ),
    );
  }
}
```

### 方式三：手动注册回调

如果需要更细粒度的控制，可以手动注册和注销回调：

```dart
import 'package:popscope_ios_plus/popscope_ios_plus.dart';

class MyPage extends StatefulWidget {
  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _isRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 注册回调，传入 context 作为唯一标识，确保只有当前页面在顶层时才触发
    if (!_isRegistered) {
      PopscopeIos.registerPopGestureCallback(() {
        // 处理返回手势
        Navigator.maybePop(context);
      }, context);
      _isRegistered = true;
    }
  }

  @override
  void dispose() {
    // 使用 context 注销回调，避免内存泄漏
    if (_isRegistered) {
      PopscopeIos.unregisterPopGestureCallback(context);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的页面')),
      body: const Center(child: Text('尝试左滑返回')),
    );
  }
}
```

## 完整示例

```dart
import 'package:flutter/material.dart';
import 'package:popscope_ios_plus/popscope_ios_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('首页')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DetailPage()),
            );
          },
          child: const Text('进入详情页'),
        ),
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PlatformPopScope(
      canPop: false,
      onPop: () async {
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认退出？'),
            content: const Text('你确定要离开这个页面吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('确认'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('详情页')),
        body: const Center(
          child: Text('尝试左滑返回或点击返回按钮'),
        ),
      ),
    );
  }
}
```

## API 文档

### PlatformPopScope

跨平台的 PopScope 封装组件，自动处理 iOS 和其他平台的差异。

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `child` | `Widget` | 是 | 子组件 |
| `canPop` | `bool` | 是 | 是否允许直接返回 |
| `onPop` | `VoidCallback` | 是 | 当 `canPop` 为 `false` 时，用户尝试返回时的回调 |

### IosPopInterceptor

iOS 专用的边缘滑动手势拦截器。

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `child` | `Widget` | 是 | 子组件 |
| `onPopGesture` | `VoidCallback` | 是 | 左滑返回手势触发时的回调 |

### PopscopeIos

静态 API 类，提供底层的回调注册和注销方法。

| 方法 | 说明 |
|------|------|
| `registerPopGestureCallback(callback, context)` | 注册左滑返回手势回调，使用 context 作为唯一标识 |
| `unregisterPopGestureCallback(context)` | 使用 context 注销回调 |

## 常见问题

### Q: 插件会影响 Android 平台吗？

A: 不会。这个插件仅在 iOS 平台生效，Android 平台会忽略这些调用。`PlatformPopScope` 在 Android 上会自动使用标准的 `PopScope`。

### Q: 如何在多个页面使用？

A: 插件使用回调栈机制，支持多个页面同时注册回调。只有栈顶（最后注册且页面仍在顶层）的回调会被调用。组件销毁时会自动清理回调。

### Q: 为什么推荐使用 Widget 方式？

A: Widget 方式（`PlatformPopScope` 或 `IosPopInterceptor`）会自动处理：
- 回调的注册和注销
- 生命周期管理
- 资源清理

手动调用 API 需要自己管理这些，容易遗漏导致内存泄漏。

### Q: 插件如何工作的？

A: 插件通过以下步骤拦截 iOS 左滑返回手势：

1. 在 iOS 原生层，获取 `UINavigationController` 的 `interactivePopGestureRecognizer`
2. 设置自己为手势识别器的代理（delegate）
3. 在 `gestureRecognizerShouldBegin` 方法中拦截手势
4. 通过 Method Channel 通知 Flutter 层
5. Flutter 层调用注册的回调函数
6. 返回 `false` 阻止系统默认的返回行为

## 技术实现

### iOS 端

- 拦截 `UINavigationController.interactivePopGestureRecognizer`
- 实现 `UIGestureRecognizerDelegate` 协议
- 在手势触发时通过 Method Channel 发送 `onSystemBackGesture` 事件

### Flutter 端

- 维护回调栈，支持多页面注册
- 回调条目包含 `BuildContext`，用于检查页面是否还在顶层
- 只有有效的栈顶回调会被调用
- 组件销毁时自动清理对应的回调

## 兼容性

- Flutter: >=3.3.0
- iOS: >=12.0
- Dart: >=3.0.0

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！

GitHub: [https://github.com/zyyziyunying/popscope_ios_plus](https://github.com/zyyziyunying/popscope_ios_plus)

## 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 了解版本更新信息。

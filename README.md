# popscope_ios_plus

A Flutter plugin for intercepting and handling iOS left-edge swipe back gestures.

[![pub package](https://img.shields.io/pub/v/popscope_ios_plus.svg)](https://pub.dev/packages/popscope_ios_plus)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[中文文档](README-ZH.md) | English

## Features

- ✅ Intercepts iOS system left-edge swipe back gesture (interactivePopGesture)
- ✅ Per-page callback system using `BuildContext` as identifier
- ✅ Auto cleanup for destroyed pages to prevent memory leaks
- ✅ Ready-to-use Widget components (`PlatformPopScope`, `IosPopInterceptor`)
- ✅ Automatic lifecycle and resource cleanup
- ✅ Runtime validation and development mode assertions
- ✅ Detailed best practices documentation with anti-patterns
- ✅ iOS-only, no impact on other platforms

## Why This Plugin?

In Flutter, when using `PopScope` (or legacy `WillPopScope`) with `canPop: false`, iOS's edge swipe back gesture gets completely disabled. This means:

1. Users cannot trigger any callbacks via swipe gestures
2. You cannot show confirmation dialogs when users swipe
3. You cannot execute custom back logic

`popscope_ios_plus` solves this by intercepting iOS native `interactivePopGestureRecognizer`, allowing you to:

- Receive callbacks when users perform swipe back gestures
- Execute custom logic (show dialogs, save data, etc.)
- Decide whether to allow page navigation

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  popscope_ios_plus: ^0.1.3
```

Then run:

```bash
flutter pub get
```

## Usage

### Option 1: PlatformPopScope (Recommended)

`PlatformPopScope` is a cross-platform wrapper that automatically selects the best implementation:

```dart
import 'package:popscope_ios_plus/popscope_ios_plus.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PlatformPopScope(
      canPop: false,
      onPop: () {
        // Show confirmation dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Exit?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('My Page')),
        body: const Center(child: Text('Try swiping left to go back')),
      ),
    );
  }
}
```

### Option 2: IosPopInterceptor

For iOS-only gesture interception, use `IosPopInterceptor` directly:

```dart
import 'package:popscope_ios_plus/popscope_ios_plus.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IosPopInterceptor(
      onPopGesture: () {
        // Handle back gesture
        Navigator.maybePop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('My Page')),
        body: const Center(child: Text('Try swiping left to go back')),
      ),
    );
  }
}
```

### Option 3: Manual Callback Registration

For fine-grained control, manually register and unregister callbacks:

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
    // Register callback with context as unique identifier
    if (!_isRegistered) {
      PopscopeIos.registerPopGestureCallback(() {
        // Handle back gesture
        Navigator.maybePop(context);
      }, context);
      _isRegistered = true;
    }
  }

  @override
  void dispose() {
    // Unregister using context to prevent memory leaks
    if (_isRegistered) {
      PopscopeIos.unregisterPopGestureCallback(context);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Page')),
      body: const Center(child: Text('Try swiping left to go back')),
    );
  }
}
```

## Complete Example

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
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DetailPage()),
            );
          },
          child: const Text('Go to Detail Page'),
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
            title: const Text('Confirm Exit?'),
            content: const Text('Are you sure you want to leave?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
        if (shouldPop == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Detail Page')),
        body: const Center(
          child: Text('Try swiping left or tapping back button'),
        ),
      ),
    );
  }
}
```

## API Documentation

### PlatformPopScope

Cross-platform PopScope wrapper that automatically handles iOS and other platform differences.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `child` | `Widget` | Yes | Child widget |
| `canPop` | `bool` | Yes | Whether direct navigation is allowed |
| `onPop` | `VoidCallback` | Yes | Callback when user attempts to navigate back with `canPop` set to `false` |

### IosPopInterceptor

iOS-specific edge swipe gesture interceptor.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `child` | `Widget` | Yes | Child widget |
| `onPopGesture` | `VoidCallback` | Yes | Callback when left-edge swipe gesture is triggered |

### PopscopeIos

Static API class providing low-level callback registration and unregistration methods.

| Method | Description |
|--------|-------------|
| `registerPopGestureCallback(callback, context)` | Register swipe back gesture callback using context as unique identifier |
| `unregisterPopGestureCallback(context)` | Unregister callback using context |

## FAQ

### Q: Does this plugin affect Android?

A: No. This plugin only works on iOS. Android ignores these calls. `PlatformPopScope` automatically uses standard `PopScope` on Android.

### Q: How to use on multiple pages?

A: The plugin uses a callback stack mechanism, supporting multiple pages registering callbacks simultaneously. Only the top-most valid callback (last registered and page still at top) gets invoked. Callbacks auto-cleanup when component is destroyed.

### Q: Why use Widget approach?

A: Widget approach (`PlatformPopScope` or `IosPopInterceptor`) automatically handles:
- Callback registration and unregistration
- Lifecycle management
- Resource cleanup

Manual API calls require managing these yourself, making it easy to miss cleanup and cause memory leaks.

### Q: How does the plugin work?

A: The plugin intercepts iOS left-edge swipe gestures through these steps:

1. On iOS native side, get `UINavigationController`'s `interactivePopGestureRecognizer`
2. Set itself as gesture recognizer's delegate
3. Intercept gesture in `gestureRecognizerShouldBegin` method
4. Notify Flutter side via Method Channel
5. Flutter side invokes registered callback
6. Return `false` to prevent system's default back behavior

## Technical Implementation

### iOS Side

- Intercepts `UINavigationController.interactivePopGestureRecognizer`
- Implements `UIGestureRecognizerDelegate` protocol
- Sends `onSystemBackGesture` event via Method Channel when gesture triggers

### Flutter Side

- Maintains callback stack supporting multi-page registration
- Callback entries contain `BuildContext` to check if page is still at top
- Only valid top-most callback gets invoked
- Auto cleanup on component destruction

## Compatibility

- Flutter: >=3.3.0
- iOS: >=12.0
- Dart: >=3.0.0

## License

MIT License

## Contributing

Issues and Pull Requests are welcome!

GitHub: [https://github.com/zyyziyunying/popscope_ios_plus](https://github.com/zyyziyunying/popscope_ios_plus)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

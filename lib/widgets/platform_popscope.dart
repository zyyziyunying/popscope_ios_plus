import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:popscope_ios_plus/widgets/ios_pop_interceptor.dart';

/// 自适应的 PopScope 封装
///
/// 根据平台和 canPop 状态自动选择实现方式：
/// - iOS 平台且 canPop 为 false 时，使用 IosPopGestureInterceptor 拦截手势
/// - 其他情况使用标准的 PopScope
class PlatformPopScope extends StatelessWidget {
  const PlatformPopScope({
    super.key,
    required this.child,
    required this.canPop,
    required this.onPop,
    this.useDirectEdgeGesture = false,
    this.enableEdgeGuard,
    this.edgeGuardWidth = 44,
  });

  final Widget child;
  final bool canPop;
  final VoidCallback onPop;
  final bool useDirectEdgeGesture;
  final bool? enableEdgeGuard;
  final double edgeGuardWidth;

  @override
  Widget build(BuildContext context) {
    /// iOS 平台且 canPop 为 false 时，使用手势拦截器
    if (Platform.isIOS && !canPop) {
      return IosPopInterceptor(
        onPopGesture: onPop,
        useDirectEdgeGesture: useDirectEdgeGesture,
        enableEdgeGuard: enableEdgeGuard,
        edgeGuardWidth: edgeGuardWidth,
        child: child,
      );
    }

    /// 其他情况使用标准 PopScope
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          onPop();
        }
      },
      child: child,
    );
  }
}

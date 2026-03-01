import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:popscope_ios_plus/popscope_ios.dart';
import 'package:popscope_ios_plus/utils/logger.dart';

/// iOS 边缘滑动手势拦截器
///
/// 仅在 iOS 平台上拦截边缘滑动手势，并在手势触发时执行回调
/// 组件销毁时自动清理拦截器资源
///
/// 使用场景：当 PopScope.canPop 为 false 时，
/// iOS 会完全禁用边缘滑动手势，此时可以使用此组件手动拦截手势并执行自定义逻辑
class IosPopInterceptor extends StatefulWidget {
  const IosPopInterceptor({
    super.key,
    required this.child,
    required this.onPopGesture,
    @Deprecated('Direct Mode 已下线，此参数仅保留兼容，不再启用原生 direct 链路。')
    this.useDirectEdgeGesture = false,
    this.enableEdgeGuard,
    this.edgeGuardWidth = 44,
  });

  /// 子组件
  final Widget child;

  /// 边缘滑动手势触发时的回调
  /// 当用户从左边缘向右滑动时调用
  final VoidCallback onPopGesture;

  /// [已下线] Direct Mode 开关，仅保留兼容。
  ///
  /// 该参数不再触发原生 direct 模式，仅作为 edge guard 默认值的兼容别名。
  @Deprecated('Direct Mode 已下线，此参数仅保留兼容。')
  final bool useDirectEdgeGesture;

  /// 是否启用左边缘手势防护层
  ///
  /// 当 canPop 为 false 时，Flutter 自带的 iOS 侧滑返回仍可能触发，
  /// 该防护层用于在组件层屏蔽左边缘的 Flutter 侧滑手势。
  /// 默认在 useDirectEdgeGesture = true 时开启。
  final bool? enableEdgeGuard;

  /// 左边缘防护层宽度（逻辑像素）
  final double edgeGuardWidth;

  @override
  State<IosPopInterceptor> createState() => _IosPopInterceptorState();
}

class _IosPopInterceptorState extends State<IosPopInterceptor> {
  /// 是否已经注册回调
  bool _isRegistered = false;
  bool _directModeWarned = false;

  bool get _shouldUseEdgeGuard {
    if (widget.enableEdgeGuard != null) {
      return widget.enableEdgeGuard!;
    }
    // 兼容旧参数：在未显式传入 enableEdgeGuard 时，沿用旧行为。
    return widget.useDirectEdgeGesture;
  }

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS && widget.useDirectEdgeGesture && !_directModeWarned) {
      _directModeWarned = true;
      PopscopeLogger.warn(
        'useDirectEdgeGesture 已下线，将自动回退到默认 interactivePopGesture 链路。',
      );
    }
  }

  void _handlePopGesture() {
    widget.onPopGesture();
  }

  void _registerCallbackIfNeeded() {
    if (!Platform.isIOS || _isRegistered) {
      return;
    }

    /// 使用注册机制，支持多个页面同时使用，避免回调覆盖
    /// 传递 context 作为唯一标识，确保只有顶层页面的回调会被调用
    /// 在 didChangeDependencies 中注册，确保 context 已准备好
    PopscopeIos.registerPopGestureCallback(_handlePopGesture, context);
    _isRegistered = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerCallbackIfNeeded();
  }

  @override
  void dispose() {
    if (Platform.isIOS && _isRegistered) {
      /// 注销回调，避免内存泄漏
      /// 使用 context 精确注销，不影响其他页面的回调
      PopscopeIos.unregisterPopGestureCallback(context);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = PopScope(
      canPop: false,
      child: widget.child,
      onPopInvokedWithResult: (didPop, result) {
        /// 处理 Flutter 组件的返回操作（如 AppBar 返回按钮）
        /// iOS 边缘滑动手势通过 registerPopGestureCallback 处理
        /// 但 AppBar 返回按钮等 Flutter 组件的返回操作不会触发原生手势回调
        /// 需要通过 onPopInvokedWithResult 来统一处理
        if (!didPop) {
          widget.onPopGesture();
        }
      },
    );

    if (Platform.isIOS && _shouldUseEdgeGuard && widget.edgeGuardWidth > 0) {
      content = Stack(
        children: [
          content,
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: widget.edgeGuardWidth,
            child: const AbsorbPointer(
              absorbing: true,
              child: SizedBox.expand(),
            ),
          ),
        ],
      );
    }

    return content;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'popscope_ios_platform_interface.dart';
import 'utils/logger.dart';

/// 回调条目，包含回调函数
class _CallbackEntry {
  final VoidCallback callback;

  /// 注册回调时的 BuildContext，用于检查页面是否还在顶层
  final BuildContext context;

  _CallbackEntry(this.callback, this.context);

  /// 检查该回调是否应该被调用
  /// 只有当注册该回调的页面还在顶层时才返回 true
  bool shouldInvoke() {
    // 检查 context 是否还 mounted
    if (!context.mounted) return false;

    // 检查该页面的 Route 是否还在顶层
    // ModalRoute.of() 不会抛异常，只会返回 null
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? false;
  }

  /// 检查该回调是否应该被清理
  /// 只有当注册该回调的页面已经被销毁（context unmounted）时才返回 true
  /// 如果页面只是被覆盖但还在路由栈中，不应该清理
  bool shouldRemove() {
    final result = !context.mounted;
    if (result) {
      PopscopeLogger.debug('CallbackEntry shouldRemove, context: $context');
    }
    return result;
  }
}

enum _NativeGestureLifecycleState { disabled, enabling, enabled, disabling }

/// 使用 Method Channel 实现的 [PopscopeIosPlatform]
///
/// 该类负责与 iOS 原生端通信，接收左滑返回手势事件并处理。
class MethodChannelPopscopeIos extends PopscopeIosPlatform {
  /// 用于与原生平台交互的 Method Channel
  @visibleForTesting
  final methodChannel = const MethodChannel('popscope_ios_plus');

  /// 系统返回手势的回调函数（旧版 API，保持兼容）
  VoidCallback? _onSystemBackGesture;

  /// 回调存储，使用 Map 提升查找性能
  /// key 是 BuildContext，value 是回调条目
  final Map<BuildContext, _CallbackEntry> _callbackMap = {};

  /// 回调顺序列表，用于维护栈的顺序（从栈底到栈顶）
  /// 遍历时需要从后往前（从栈顶开始）
  final List<BuildContext> _callbackOrder = [];

  /// 用于自动导航处理的 Navigator Key
  GlobalKey<NavigatorState>? _navigatorKey;

  /// 是否自动处理导航
  bool _autoHandleNavigation = false;

  /// Method Call Handler 是否已初始化
  bool _handlerInitialized = false;

  /// 原生手势生命周期状态机
  _NativeGestureLifecycleState _nativeGestureLifecycleState =
      _NativeGestureLifecycleState.disabled;

  MethodChannelPopscopeIos() {
    // 延迟设置 method call handler，避免在 binding 初始化前调用
    _ensureHandlerInitialized();
  }

  /// 确保 method call handler 已设置
  void _ensureHandlerInitialized() {
    if (!_handlerInitialized) {
      try {
        methodChannel.setMethodCallHandler(_handleMethodCall);
        _handlerInitialized = true;
      } catch (e) {
        // 如果 binding 还没初始化，稍后再试
        PopscopeLogger.warn('Method call handler will be initialized later');
      }
    }
  }

  /// 处理来自原生端的方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSystemBackGesture':
        String source = 'interactive-pop';
        if (call.arguments is Map) {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          source = args['source']?.toString() ?? source;
          final state = args['state']?.toString();
          final route = args['route']?.toString();
          final action = args['action']?.toString();
          _logBackIntent(
            source: source,
            state: state,
            route: route,
            action: action ?? 'native_event',
          );
        }
        await _handleSystemBackGesture(source: source);
        break;
      default:
        throw MissingPluginException('未实现的方法: ${call.method}');
    }
  }

  /// 处理系统返回手势事件
  Future<void> _handleSystemBackGesture({required String source}) async {
    // 1. 优先交给页面/业务层回调处理（WebView 等场景可先消费事件）
    final callback = _findAndCleanValidCallback() ?? _onSystemBackGesture;
    if (callback != null) {
      _logBackIntent(source: source, action: 'dispatch_callback');
      callback();
      return;
    }

    // 2. 没有可用回调时，再走自动导航
    if (_autoHandleNavigation) {
      final navigator = _navigatorKey?.currentState;
      if (navigator != null) {
        _logBackIntent(source: source, action: 'dispatch_maybePop');
        await navigator.maybePop();
      } else {
        _logBackIntent(source: source, action: 'navigator_null');
        PopscopeLogger.warn('NavigatorState is null, cannot pop');
      }
      return;
    }

    _logBackIntent(source: source, action: 'event_dropped_no_handler');
  }

  /// 查找并清理有效的回调
  ///
  /// 从栈顶开始遍历回调栈，在查找过程中：
  /// 1. 如果发现需要清理的条目（context unmounted），立即移除
  /// 2. 如果找到有效的回调（页面还在顶层），返回该回调
  ///
  /// 返回：
  /// - [VoidCallback?]: 找到的有效回调，如果没有找到则返回 null
  VoidCallback? _findAndCleanValidCallback() {
    var removedAny = false;

    // 从栈顶开始遍历，一边查找有效回调，一边清理已销毁的回调
    for (var i = _callbackOrder.length - 1; i >= 0; i--) {
      final context = _callbackOrder[i];
      final entry = _callbackMap[context];

      // 如果 entry 不存在（理论上不应该发生），清理顺序列表
      if (entry == null) {
        _callbackOrder.removeAt(i);
        removedAny = true;
        continue;
      }

      // 如果该条目需要清理，立即移除
      if (entry.shouldRemove()) {
        _callbackMap.remove(context);
        _callbackOrder.removeAt(i);
        removedAny = true;
        PopscopeLogger.debug('Removed callback entry at index $i');
        continue;
      }

      // 如果找到了有效的回调，返回它
      if (entry.shouldInvoke()) {
        PopscopeLogger.debug(
          'Callback invoked: context=${context.hashCode}, index=$i',
        );
        return entry.callback;
      }
    }

    if (removedAny) {
      _scheduleNativeLifecycleSync(reason: 'callback_gc');
    }

    // 没有找到有效的回调
    return null;
  }

  @override
  void setNavigatorKey(
    GlobalKey<NavigatorState>? navigatorKey, {
    bool autoHandle = true,
  }) {
    _ensureHandlerInitialized();
    _navigatorKey = navigatorKey;
    _autoHandleNavigation = autoHandle;
    _scheduleNativeLifecycleSync(reason: 'setNavigatorKey');
  }

  @override
  void setOnSystemBackGesture(VoidCallback? callback) {
    _ensureHandlerInitialized();
    _onSystemBackGesture = callback;
    _scheduleNativeLifecycleSync(reason: 'setOnSystemBackGesture');
  }

  @override
  void registerPopGestureCallback(VoidCallback callback, BuildContext context) {
    _ensureHandlerInitialized();

    // 添加断言检查
    assert(
      context.mounted,
      'Cannot register callback with unmounted context. '
      'Make sure to call registerPopGestureCallback in didChangeDependencies() '
      'or after the widget is mounted.',
    );

    // 验证 context 有效性（生产环境也会检查）
    if (!context.mounted) {
      PopscopeLogger.warn(
        'Attempted to register callback with unmounted context: ${context.hashCode}. '
        'Registration ignored.',
      );
      return;
    }

    // 如果已经注册过，先移除旧的
    if (_callbackMap.containsKey(context)) {
      _callbackOrder.remove(context);
      PopscopeLogger.debug(
        'Re-registering callback for context: ${context.hashCode}',
      );
    }

    // 添加到 Map 和顺序列表
    _callbackMap[context] = _CallbackEntry(callback, context);
    _callbackOrder.add(context);

    PopscopeLogger.debug(
      'Callback registered: context=${context.hashCode}, total=${_callbackOrder.length}',
    );

    _scheduleNativeLifecycleSync(reason: 'registerPopGestureCallback');
  }

  @override
  void unregisterPopGestureCallback(BuildContext context) {
    // O(1) 从 Map 删除
    _callbackMap.remove(context);
    // O(n) 从顺序列表删除，并顺便清理已失效的 context
    _callbackOrder.removeWhere((ctx) => ctx == context);
    _cleanupStaleCallbacks();
    _scheduleNativeLifecycleSync(reason: 'unregisterPopGestureCallback');
  }

  /// 清理已失效的回调条目，避免生命周期状态被脏数据影响
  void _cleanupStaleCallbacks() {
    for (var i = _callbackOrder.length - 1; i >= 0; i--) {
      final context = _callbackOrder[i];
      final entry = _callbackMap[context];
      if (entry == null || entry.shouldRemove()) {
        _callbackMap.remove(context);
        _callbackOrder.removeAt(i);
      }
    }
  }

  bool get _hasActiveBackIntentConsumer {
    _cleanupStaleCallbacks();
    final hasRegisteredCallbacks = _callbackOrder.isNotEmpty;
    final hasLegacyCallback = _onSystemBackGesture != null;
    final hasAutoNavigationHandler =
        _autoHandleNavigation && _navigatorKey != null;
    return hasRegisteredCallbacks ||
        hasLegacyCallback ||
        hasAutoNavigationHandler;
  }

  /// 生命周期调度入口：根据当前 consumer 状态自动 enable/disable 原生钩子
  void _scheduleNativeLifecycleSync({required String reason}) {
    final shouldEnable = _hasActiveBackIntentConsumer;
    _logBackIntent(action: 'lifecycle_schedule_$reason');
    _reconcileNativeLifecycle(shouldEnable: shouldEnable);
  }

  void _reconcileNativeLifecycle({required bool shouldEnable}) {
    final isEnabled =
        _nativeGestureLifecycleState == _NativeGestureLifecycleState.enabled ||
        _nativeGestureLifecycleState == _NativeGestureLifecycleState.enabling;
    if (shouldEnable == isEnabled) {
      return;
    }

    if (shouldEnable) {
      _transitionLifecycle(
        _NativeGestureLifecycleState.enabling,
        action: 'native_enable_requested',
      );
      unawaited(
        methodChannel
            .invokeMethod<void>('enableInteractivePopGesture')
            .catchError((Object e, StackTrace stackTrace) {
              PopscopeLogger.error(
                'enableInteractivePopGesture failed: $e\n$stackTrace',
              );
            }),
      );
      _transitionLifecycle(
        _NativeGestureLifecycleState.enabled,
        action: 'native_enable_completed',
      );
      return;
    }

    _transitionLifecycle(
      _NativeGestureLifecycleState.disabling,
      action: 'native_disable_requested',
    );
    unawaited(
      methodChannel
          .invokeMethod<void>('disableInteractivePopGesture')
          .catchError((Object e, StackTrace stackTrace) {
            PopscopeLogger.error(
              'disableInteractivePopGesture failed: $e\n$stackTrace',
            );
          }),
    );
    _transitionLifecycle(
      _NativeGestureLifecycleState.disabled,
      action: 'native_disable_completed',
    );
  }

  void _transitionLifecycle(
    _NativeGestureLifecycleState nextState, {
    required String action,
  }) {
    _nativeGestureLifecycleState = nextState;
    _logBackIntent(action: action, state: nextState.name);
  }

  void _logBackIntent({
    String source = 'interactive-pop',
    String? state,
    String? route,
    required String action,
  }) {
    PopscopeLogger.debug(
      'back-intent source=$source '
      'state=${state ?? _nativeGestureLifecycleState.name} '
      'route=${route ?? _currentRouteLabel()} '
      'action=$action',
    );
  }

  String _currentRouteLabel() {
    final navigator = _navigatorKey?.currentState;
    final context = navigator?.context ?? _navigatorKey?.currentContext;
    if (context == null) {
      return 'unknown';
    }
    final route = ModalRoute.of(context);
    return route?.settings.name ?? route?.runtimeType.toString() ?? 'unknown';
  }

  @Deprecated('Direct Mode 已下线。请使用默认的 interactivePopGesture 拦截链路。')
  Future<void> enableDirectEdgeGesture() async {
    PopscopeLogger.warn(
      'Direct Mode 已下线（direct_mode_rebuild_decision）。当前调用将被拒绝。',
    );
    throw UnsupportedError('Direct Mode 已下线，待重构版完成后再开放。');
  }

  @override
  Future<String?> getPlatformVersion() async {
    _ensureHandlerInitialized();
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}

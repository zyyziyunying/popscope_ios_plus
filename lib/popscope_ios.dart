import 'package:flutter/material.dart';
import 'popscope_ios_platform_interface.dart';
import 'popscope_ios_method_channel.dart';
import 'utils/logger.dart';

// 导出 widgets，方便用户使用
export 'widgets/platform_popscope.dart';
export 'widgets/ios_pop_interceptor.dart';

/// iOS 左滑返回手势拦截插件
///
/// 该插件用于拦截 iOS 系统的左滑返回手势（interactivePopGesture），
/// 支持三种使用方式：
/// 1. **推荐**：使用 [PlatformPopScope] widget，自动处理初始化和销毁
/// 2. **推荐**：使用 [IosNavigatorKeyInterceptor] widget，在组件级别管理 setNavigatorKey
/// 3. 自动处理：通过 [setNavigatorKey] 设置 Navigator，插件自动调用 maybePop()（不推荐全局设置）
/// 4. 业务自定义：通过 [setOnLeftBackGesture] 设置回调，由业务层自行处理（不推荐全局设置）
///
/// **强烈推荐使用组件方式（[PlatformPopScope] 或 [IosNavigatorKeyInterceptor]）**，
/// 它们会自动处理资源管理和生命周期，避免全局配置导致的问题（如多次 pop）。
///
/// ⚠️ **警告**：直接在 main() 中全局设置 [setNavigatorKey] 或 [setOnLeftBackGesture]
/// 可能导致多个页面同时响应返回手势，造成多次 pop 的问题。
/// 建议使用组件方式，在需要处理的页面中包裹相应的 widget。
class PopscopeIos {
  Future<String?> getPlatformVersion() {
    return PopscopeIosPlatform.instance.getPlatformVersion();
  }

  /// 设置 Navigator Key，用于自动处理页面返回
  ///
  /// 当 iOS 系统检测到左滑返回手势时，插件会自动调用 `navigator.maybePop()` 来处理页面返回。
  ///
  /// 参数：
  /// - [navigatorKey]: 全局 Navigator Key，通常在 MaterialApp 中设置
  /// - [autoHandle]: 是否自动处理导航，默认为 true
  ///
  /// 使用场景：
  /// - 希望插件自动处理页面返回，无需业务层介入
  /// - 需要与 Flutter 的导航系统集成
  ///
  /// 示例：
  /// ```dart
  /// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  ///
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   PopscopeIos.setNavigatorKey(navigatorKey);
  ///   runApp(MyApp());
  /// }
  ///
  /// class MyApp extends StatelessWidget {
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return MaterialApp(
  ///       navigatorKey: navigatorKey, // 关联到 MaterialApp
  ///       home: HomePage(),
  ///     );
  ///   }
  /// }
  /// ```
  @Deprecated(
    '直接调用这个方法，会直接影响全局，并且不是很有必要'
    '请使用 registerPopGestureCallback 和 unregisterPopGestureCallback 来管理回调',
  )
  static void setNavigatorKey(
    GlobalKey<NavigatorState>? navigatorKey, {
    bool autoHandle = true,
  }) {
    PopscopeIosPlatform.instance.setNavigatorKey(
      navigatorKey,
      autoHandle: autoHandle,
    );
  }

  /// 设置左滑返回手势的回调函数
  ///
  /// 当 iOS 系统检测到左滑返回手势时，会调用此回调函数，由业务层自行处理。
  ///
  /// 参数：
  /// - [callback]: 手势触发时的回调函数，传入 null 可清除回调
  ///
  /// 使用场景：
  /// - 需要在返回前执行自定义逻辑（如保存数据、显示确认对话框等）
  /// - 需要根据业务状态决定是否允许返回
  /// - 需要统计或记录用户的返回行为
  ///
  /// 注意：
  /// - ⚠️ 此方法会直接替换回调，多个页面使用时会有覆盖问题
  /// - 推荐使用 [registerPopGestureCallback] 和 [unregisterPopGestureCallback] 来管理回调
  /// - 如果同时设置了 [setNavigatorKey]，会优先执行此回调；仅当没有可用回调时才会自动 maybePop()
  /// - 如果只设置此回调而不设置 [setNavigatorKey]，则需要在回调中自行处理页面返回
  ///
  /// 示例：
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///
  ///   // 只设置回调，业务自行处理
  ///   PopscopeIos.setOnLeftBackGesture(() {
  ///     print('检测到左滑返回手势');
  ///     // 这里可以执行自定义逻辑
  ///     // 例如：显示确认对话框、保存数据等
  ///   });
  ///
  ///   runApp(MyApp());
  /// }
  /// ```
  @Deprecated(
    '直接调用这个方法，会直接影响全局，多个页面使用时会有覆盖问题'
    '请使用 registerPopGestureCallback 和 unregisterPopGestureCallback 来管理回调',
  )
  static void setOnLeftBackGesture(VoidCallback? callback) {
    PopscopeIosPlatform.instance.setOnSystemBackGesture(callback);
  }

  /// 注册左滑返回手势的回调函数
  ///
  /// 当 iOS 系统检测到左滑返回手势时，会调用栈顶的回调函数。
  /// 多个页面可以同时注册回调，只有栈顶（最后注册）的回调会被调用。
  ///
  /// 参数：
  /// - [callback]: 手势触发时的回调函数
  /// - [context]: 注册回调时的 BuildContext，作为回调的唯一标识，
  ///              同时用于检查页面是否还在顶层
  ///
  /// 使用场景：
  /// - 多个页面都需要拦截返回手势时，使用此方法可以避免回调覆盖
  /// - 组件销毁时需要清理回调，避免内存泄漏
  /// - 当路由是 A->B->C，B 页面注册了回调，C 页面没有注册回调时，
  ///   只有 B 页面还在顶层时才会调用 B 页面的回调
  ///
  /// **重要提示**：
  /// 1. **必须在 didChangeDependencies() 中调用**，不要在 initState() 中调用
  /// 2. **使用 `_isRegistered` 标志防止重复注册**，避免 InheritedWidget 更新时重复注册导致顺序混乱
  /// 3. **必须在 dispose() 中注销回调**，避免内存泄漏
  /// 4. BuildContext 在 State 生命周期中是稳定的，不会因为 setState() 或 didChangeDependencies() 而改变
  ///
  /// 示例：
  /// ```dart
  /// class MyPage extends StatefulWidget {
  ///   @override
  ///   State<MyPage> createState() => _MyPageState();
  /// }
  ///
  /// class _MyPageState extends State<MyPage> {
  ///   bool _isRegistered = false;  // ✅ 重要：使用标志位防止重复注册
  ///
  ///   @override
  ///   void didChangeDependencies() {
  ///     super.didChangeDependencies();
  ///     // ✅ 只在第一次调用时注册，避免 InheritedWidget 更新时重复注册
  ///     if (!_isRegistered) {
  ///       PopscopeIos.registerPopGestureCallback(() {
  ///         print('检测到左滑返回手势');
  ///         // 处理返回逻辑
  ///         Navigator.maybePop(context);
  ///       }, context);
  ///       _isRegistered = true;
  ///     }
  ///   }
  ///
  ///   @override
  ///   void dispose() {
  ///     // ✅ 必须注销回调
  ///     if (_isRegistered) {
  ///       PopscopeIos.unregisterPopGestureCallback(context);
  ///     }
  ///     super.dispose();
  ///   }
  /// }
  /// ```
  ///
  /// **错误示例（不要这样做）**：
  /// ```dart
  /// // ❌ 错误：在 initState 中注册（context 可能未准备好）
  /// @override
  /// void initState() {
  ///   super.initState();
  ///   PopscopeIos.registerPopGestureCallback(() { ... }, context);
  /// }
  ///
  /// // ❌ 错误：没有使用 _isRegistered 标志（可能重复注册）
  /// @override
  /// void didChangeDependencies() {
  ///   super.didChangeDependencies();
  ///   PopscopeIos.registerPopGestureCallback(() { ... }, context);  // 每次都会注册！
  /// }
  ///
  /// // ❌ 错误：忘记在 dispose 中注销（内存泄漏）
  /// @override
  /// void dispose() {
  ///   super.dispose();  // 忘记注销回调
  /// }
  /// ```
  static void registerPopGestureCallback(
    VoidCallback callback,
    BuildContext context,
  ) {
    assert(
      context.mounted,
      'Cannot register callback with unmounted context. '
      'Make sure to call this method in didChangeDependencies() with a valid BuildContext.',
    );

    PopscopeIosPlatform.instance.registerPopGestureCallback(callback, context);
    PopscopeLogger.info(
      'registerPopGestureCallback context: ${context.hashCode}',
    );
  }

  /// 注销左滑返回手势的回调函数
  ///
  /// 参数：
  /// - [context]: 注册回调时使用的 BuildContext
  ///
  /// 示例：
  /// ```dart
  /// PopscopeIos.registerPopGestureCallback(() {
  ///   print('手势触发');
  /// }, context);
  ///
  /// // 组件销毁时注销
  /// PopscopeIos.unregisterPopGestureCallback(context);
  /// ```
  static void unregisterPopGestureCallback(BuildContext context) {
    PopscopeIosPlatform.instance.unregisterPopGestureCallback(context);
    PopscopeLogger.info(
      'unregisterPopGestureCallback context: ${context.hashCode}',
    );
  }

  // MARK: - 实验性 API

  /// [实验性] 启用直接边缘手势模式进行测试
  ///
  /// 该模式使用 UIScreenEdgePanGestureRecognizer 直接监听左边缘滑动，
  /// 不依赖 UINavigationController。
  ///
  /// **注意**：此方法仅用于 MVP 验证，生产环境不建议使用。
  ///
  /// 验证点：
  /// - 手势是否能正常触发
  /// - 是否与 Flutter 手势冲突
  /// - 在滑动列表时是否会误触发
  /// - 手势灵敏度是否可接受
  static Future<void> enableDirectEdgeGestureForTesting() async {
    final platform = PopscopeIosPlatform.instance;
    if (platform is MethodChannelPopscopeIos) {
      await platform.enableDirectEdgeGesture();
      PopscopeLogger.info('Direct edge gesture mode enabled for testing');
    }
  }
}

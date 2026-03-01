import Flutter
import UIKit

/// iOS 左滑返回手势拦截插件
///
/// 该插件通过拦截 UINavigationController 的 interactivePopGestureRecognizer，
/// 在检测到左滑返回手势时通知 Flutter 层进行处理。
public class PopscopeIosPlugin: NSObject, FlutterPlugin, UIGestureRecognizerDelegate {
  /// 弱引用的 Navigation Controller
  ///
  /// 用于访问 interactivePopGestureRecognizer 来拦截左滑返回手势
  /// 使用 weak 引用避免循环引用
  private weak var navigationController: UINavigationController?

  /// 原始的手势识别器代理，用于保留系统默认行为
  ///
  /// 当拦截左滑手势时，其他手势（如右滑、点击等）仍交由原始代理处理，
  /// 确保不影响其他手势识别器的正常工作
  private var originalDelegate: UIGestureRecognizerDelegate?

  /// 与 Flutter 通信的 Method Channel
  ///
  /// 用于向 Flutter 层发送手势事件通知（onSystemBackGesture）
  private var channel: FlutterMethodChannel?

  // MARK: - Direct Mode (实验性)

  /// [实验性] 直接模式的边缘手势识别器
  ///
  /// 使用 UIScreenEdgePanGestureRecognizer 直接监听左边缘滑动，
  /// 不依赖 UINavigationController。
  private var edgeGestureRecognizer: UIScreenEdgePanGestureRecognizer?

  /// [实验性] 直接模式的备用全屏 Pan 手势识别器（仅左边缘生效）
  ///
  /// 当 UIScreenEdgePanGestureRecognizer 未触发时作为兜底验证。
  private var edgeFallbackPanRecognizer: UIPanGestureRecognizer?

  /// [实验性] 直接模式下监听系统 interactivePopGestureRecognizer
  ///
  /// 当存在 UINavigationController 时，追加 target 以确保能收到回调。
  private weak var directModeInteractivePopGesture: UIGestureRecognizer?

  /// [实验性] 备用 pan 手势的左边缘判定宽度（pt）
  private let directEdgeFallbackWidth: CGFloat = 44

  /// [实验性] 手势调试日志节流时间（秒）
  private let gestureDebugInterval: TimeInterval = 0.3
  private var lastGestureDebugTime: TimeInterval = 0

  /// [实验性] 弱引用的 FlutterViewController
  ///
  /// 直接模式下用于添加边缘手势识别器
  private weak var flutterViewController: FlutterViewController?

  /// 获取当前的 keyWindow
  ///
  /// iOS 13+ 使用 connectedScenes 获取，避免 UIApplication.shared.windows 为空。
  private func keyWindow() -> UIWindow? {
    if #available(iOS 13.0, *) {
      let scenes = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .filter { $0.activationState == .foregroundActive }

      let windows = scenes.flatMap { $0.windows }
      if let key = windows.first(where: { $0.isKeyWindow }) {
        return key
      }

      if let visible = windows.first(where: { !$0.isHidden }) {
        return visible
      }

      return windows.first
    }

    return UIApplication.shared.keyWindow
  }
  
  /// 插件注册入口
  ///
  /// Flutter 插件系统会在应用启动时自动调用此方法
  ///
  /// - Parameter registrar: Flutter 插件注册器，用于注册 Method Channel
  ///
  /// 注意：此方法只创建 Method Channel，不会自动启用手势拦截。
  /// 需要 Flutter 层主动调用 enableInteractivePopGesture 才会启用。
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "popscope_ios_plus", binaryMessenger: registrar.messenger())
    let instance = PopscopeIosPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
    // ! 不再自动设置手势拦截，需要 Flutter 层主动调用 enableInteractivePopGesture 才会启用
  }
  
  /// 如果需要，设置左滑返回手势拦截
  ///
  /// 该方法会检查 rootViewController 的类型，并获取或创建 UINavigationController：
  ///
  /// **情况1：rootViewController 是 UINavigationController**
  /// - 直接使用现有的 NavigationController（最安全，不修改视图层次结构）
  ///
  /// **情况2：rootViewController 是 FlutterViewController**
  /// - 2a：如果 FlutterViewController 已经被包装在 NavigationController 中，直接使用
  /// - 2b：如果没有 NavigationController，创建新的并包装 FlutterViewController
  ///
  /// 注意：情况2b 会在运行时替换 rootViewController，可能导致视图层次结构问题。
  /// 建议在 AppDelegate 中预先配置 UINavigationController。
  private func setupInteractivePopGestureIfNeeded() {
    // 获取应用的窗口和根视图控制器
    guard let window = keyWindow(),
          let rootViewController = window.rootViewController else {
      // 无法获取 rootViewController，无法设置手势拦截
      NSLog("[PopscopeIos] Failed to get keyWindow or rootViewController for interactive mode")
      return
    }

    if let navController = rootViewController as? UINavigationController {
      // 情况1：rootViewController 本身就是 UINavigationController
      // 直接使用，不需要修改视图层次结构（最安全的方式）
      self.navigationController = navController
    } else if let flutterVC = rootViewController as? FlutterViewController {
      // 情况2：rootViewController 是 FlutterViewController
      if let existingNavController = flutterVC.navigationController {
        // 2a：FlutterViewController 已经被包装在 NavigationController 中
        // 直接使用现有的 NavigationController（安全）
        self.navigationController = existingNavController
      } else {
        // 2b：FlutterViewController 没有 NavigationController
        // 需要创建新的 NavigationController 来包装 FlutterViewController
        // 这样才能访问 interactivePopGestureRecognizer
        
        // 先将 window.rootViewController 设置为 nil，避免视图层次冲突
        window.rootViewController = nil
        
        // 创建新的 NavigationController，以 FlutterViewController 作为根视图控制器
        let newNavController = UINavigationController(rootViewController: flutterVC)
        
        // 隐藏导航栏，避免占据上方空间（Flutter 有自己的导航栏）
        newNavController.isNavigationBarHidden = true
        
        // 保存引用，用于后续拦截手势
        self.navigationController = newNavController
        
        // 将新创建的 NavigationController 设置为 rootViewController
        window.rootViewController = newNavController
      }
    }
    
    // 获取到 NavigationController 后，设置手势拦截
    setupInteractivePopGesture()
  }
  
  /// 设置左滑返回手势的拦截
  ///
  /// 通过实现 UIGestureRecognizerDelegate 协议并设置为代理，
  /// 可以在手势识别器开始识别手势时进行拦截。
  ///
  /// 工作流程：
  /// 1. 保存原始的手势识别器代理（用于处理其他手势）
  /// 2. 将自己设置为新的代理（用于拦截左滑返回手势）
  /// 3. 当手势触发时，gestureRecognizerShouldBegin 会被调用
  private func setupInteractivePopGesture() {
    // 保存原始的代理，用于处理非左滑返回的其他手势
    // 这样可以保持与其他手势识别器的兼容性
    self.originalDelegate = self.navigationController?.interactivePopGestureRecognizer?.delegate

    // 进入交互模式时移除 direct 模式添加的 target，避免重复触发
    if let popGesture = self.navigationController?.interactivePopGestureRecognizer {
      popGesture.removeTarget(self, action: #selector(handleInteractivePopGesture(_:)))
      self.directModeInteractivePopGesture = nil
    }

    // 将自己设置为新的代理，这样当左滑手势触发时，
    // gestureRecognizerShouldBegin 方法会被调用，可以进行拦截
    self.navigationController?.interactivePopGestureRecognizer?.delegate = self
  }

  // MARK: - Direct Mode Methods (实验性)

  /// [实验性] 设置直接模式的边缘滑动手势识别
  ///
  /// 该方法直接在 window 上添加 UIScreenEdgePanGestureRecognizer，
  /// 尽量减少对 UINavigationController 的依赖。
  ///
  /// **优点**：
  /// - 不需要修改视图层次结构（不需要包装 NavigationController）
  /// - 更简单直接的实现方式
  ///
  /// **待验证**：
  /// - 是否与 Flutter 内部手势冲突
  /// - 在滑动列表时是否误触发
  /// - 手势灵敏度是否可接受
  private func setupDirectEdgeGesture() -> [String: Any] {
    var info: [String: Any] = [
      "success": false,
      "reason": "unknown"
    ]

    guard let window = keyWindow() else {
      info["reason"] = "no_key_window"
      NSLog("[PopscopeIos] Failed to get keyWindow for direct mode")
      return info
    }

    guard let rootVC = window.rootViewController else {
      info["reason"] = "no_root_view_controller"
      NSLog("[PopscopeIos] Failed to get rootViewController for direct mode")
      return info
    }

    // 获取 FlutterViewController
    info["rootViewController"] = String(describing: type(of: rootVC))

    let flutterVC: FlutterViewController?
    var navController: UINavigationController?
    if let fvc = rootVC as? FlutterViewController {
      flutterVC = fvc
      navController = fvc.navigationController
    } else if let navVC = rootVC as? UINavigationController,
              let fvc = navVC.viewControllers.first as? FlutterViewController {
      flutterVC = fvc
      navController = navVC
    } else {
      flutterVC = nil
    }

    guard let targetVC = flutterVC else {
      info["reason"] = "no_flutter_view_controller"
      NSLog("[PopscopeIos] Failed to find FlutterViewController")
      return info
    }

    // 保存引用
    self.flutterViewController = targetVC
    if let navController = navController {
      self.navigationController = navController
      if let popGesture = navController.interactivePopGestureRecognizer {
        // 直接模式下追加 target，确保系统返回手势也能通知到 Flutter
        popGesture.removeTarget(self, action: #selector(handleInteractivePopGesture(_:)))
        popGesture.addTarget(self, action: #selector(handleInteractivePopGesture(_:)))
        self.directModeInteractivePopGesture = popGesture
        info["interactivePopObserver"] = true
        info["interactivePopEnabled"] = popGesture.isEnabled
      } else {
        info["interactivePopObserver"] = false
      }
    }

    // 确保 view 已加载，避免无法添加手势
    targetVC.loadViewIfNeeded()

    // 移除已有的边缘手势（如果有）
    if let existingGesture = self.edgeGestureRecognizer {
      existingGesture.view?.removeGestureRecognizer(existingGesture)
    }
    // 移除已有的备用 pan 手势（如果有）
    if let existingFallback = self.edgeFallbackPanRecognizer {
      existingFallback.view?.removeGestureRecognizer(existingFallback)
    }

    // 创建新的边缘手势识别器
    let edgeGesture = UIScreenEdgePanGestureRecognizer(
      target: self,
      action: #selector(handleEdgeSwipe(_:))
    )
    edgeGesture.edges = .left
    edgeGesture.delegate = self
    edgeGesture.cancelsTouchesInView = false
    edgeGesture.delaysTouchesBegan = false
    edgeGesture.delaysTouchesEnded = false
    edgeGesture.requiresExclusiveTouchType = false

    // 添加到 window 上，避免被 Flutter 视图层吞掉触摸
    window.addGestureRecognizer(edgeGesture)
    self.edgeGestureRecognizer = edgeGesture

    // 备用 Pan 手势：只在左边缘触发，用于验证触摸是否能到达
    let fallbackPan = UIPanGestureRecognizer(
      target: self,
      action: #selector(handleFallbackPan(_:))
    )
    fallbackPan.maximumNumberOfTouches = 1
    fallbackPan.minimumNumberOfTouches = 1
    fallbackPan.delegate = self
    fallbackPan.cancelsTouchesInView = false
    fallbackPan.delaysTouchesBegan = false
    fallbackPan.delaysTouchesEnded = false
    window.addGestureRecognizer(fallbackPan)
    self.edgeFallbackPanRecognizer = fallbackPan
    info["fallbackPanHost"] = "window"

    info["success"] = true
    info["reason"] = "ok"
    info["gestureHost"] = "window"
    NSLog("[PopscopeIos] Direct edge gesture setup completed")
    return info
  }

  /// [实验性] 处理边缘滑动手势
  ///
  /// 当手势状态为 .began 时（手势刚开始），触发回调通知 Flutter 层
  @objc private func handleEdgeSwipe(_ recognizer: UIScreenEdgePanGestureRecognizer) {
    switch recognizer.state {
    case .began:
      // 手势开始时触发回调
      emitSystemBackGesture(source: "direct-edge")
    case .changed:
      // 可选：手势进行中，可用于实现跟手动画（MVP 不实现）
      break
    case .ended, .cancelled, .failed:
      // 手势结束/取消/失败
      break
    default:
      break
    }
  }

  /// [实验性] 处理系统 interactivePopGestureRecognizer 的回调
  ///
  /// 直接模式下为系统手势追加 target，确保也能触发 Flutter 回调
  @objc private func handleInteractivePopGesture(_ recognizer: UIGestureRecognizer) {
    if recognizer.state == .began {
      emitSystemBackGesture(source: "interactive-pop")
    }
  }

  /// [实验性] 处理备用 Pan 手势（仅左边缘判定通过后触发）
  @objc private func handleFallbackPan(_ recognizer: UIPanGestureRecognizer) {
    if recognizer.state == .began {
      emitSystemBackGesture(source: "fallback-pan")
    }
  }

  /// 统一触发 Flutter 侧的返回手势回调
  private func emitSystemBackGesture(source: String) {
    channel?.invokeMethod("onSystemBackGesture", arguments: ["source": source])
    NSLog("[PopscopeIos] System back gesture detected (source: \(source))")
  }

  /// 处理来自 Flutter 层的方法调用
  ///
  /// 这是 FlutterPlugin 协议要求实现的方法，用于处理 Method Channel 的方法调用
  ///
  /// - Parameters:
  ///   - call: Flutter 层调用的方法信息（包含方法名和参数）
  ///   - result: 返回结果给 Flutter 层的回调
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "enableInteractivePopGesture":
      // Flutter 层主动调用此方法来启用手势拦截
      // 必须在主线程执行，因为涉及 UI 操作（修改 rootViewController）
      NSLog("[PopscopeIos] enableInteractivePopGesture called")
      DispatchQueue.main.async {
        self.setupInteractivePopGestureIfNeeded()
      }
      result(nil)
    case "enableDirectEdgeGesture":
      // [实验性] Flutter 层调用此方法来启用直接边缘手势模式
      // 必须在主线程执行，因为涉及 UI 操作
      NSLog("[PopscopeIos] enableDirectEdgeGesture called")
      DispatchQueue.main.async {
        let info = self.setupDirectEdgeGesture()
        result(info)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  // MARK: - UIGestureRecognizerDelegate
  
  /// 控制手势识别器是否应该开始识别手势
  ///
  /// 这是 UIGestureRecognizerDelegate 协议的核心方法，在手势识别器准备开始识别手势时调用。
  ///
  /// **拦截左滑返回手势的流程：**
  /// 1. 用户执行左滑手势
  /// 2. UINavigationController 的 interactivePopGestureRecognizer 检测到手势
  /// 3. 调用此方法（因为我们设置了代理）
  /// 4. 判断是否是左滑返回手势
  /// 5. 如果是，通知 Flutter 层并返回 false（阻止系统默认返回）
  /// 6. 如果不是，交由原始代理处理（保持其他手势的正常行为）
  ///
  /// - Parameter gestureRecognizer: 准备开始识别的手势识别器
  /// - Returns: true 表示允许手势识别，false 表示阻止手势识别
  public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    // 直接模式的边缘手势应始终允许开始识别
    if gestureRecognizer == self.edgeGestureRecognizer {
      return true
    }

    // 直接模式的备用 pan 手势：仅允许左边缘向右滑动
    if gestureRecognizer == self.edgeFallbackPanRecognizer {
      guard let window = keyWindow() else {
        return false
      }
      let location = gestureRecognizer.location(in: window)
      if location.x > directEdgeFallbackWidth {
        return false
      }
      return true
    }

    // 检测到系统左滑手势，发送事件给 Flutter
    if gestureRecognizer == self.navigationController?.interactivePopGestureRecognizer {
      emitSystemBackGesture(source: "interactive-pop")
      // 返回 false 阻止系统默认的返回行为，由 Flutter 层处理
      return false
    }
    
    // 其他手势交由原来的代理处理
    if let originalDelegate = self.originalDelegate {
      return originalDelegate.gestureRecognizerShouldBegin?(gestureRecognizer) ?? true
    }
    
    return true
  }
  
  /// 允许同时识别多个手势
  ///
  /// 这样可以确保插件不会影响其他手势识别器的正常工作
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
    return true
  }

  /// 手势触摸回调（调试用）
  public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    let isDirectEdge = gestureRecognizer == self.edgeGestureRecognizer
    let isFallback = gestureRecognizer == self.edgeFallbackPanRecognizer
    let isInteractivePop = gestureRecognizer == self.directModeInteractivePopGesture
    guard isDirectEdge || isFallback || isInteractivePop else {
      return true
    }

    let now = CACurrentMediaTime()
    if now - lastGestureDebugTime >= gestureDebugInterval {
      lastGestureDebugTime = now
      let window = keyWindow()
      let location = touch.location(in: window)
      let source = isDirectEdge ? "direct-edge" : (isFallback ? "fallback-pan" : "interactive-pop")
      NSLog("[PopscopeIos] Gesture touch received (source: \(source), location: \(location))")
    }
    return true
  }
}

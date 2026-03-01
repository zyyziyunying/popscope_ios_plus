import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popscope_ios_plus/popscope_ios_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelPopscopeIos platform;
  const MethodChannel channel = MethodChannel('popscope_ios_plus');

  setUp(() {
    platform = MethodChannelPopscopeIos();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          // 默认返回 iOS 版本号
          if (methodCall.method == 'getPlatformVersion') {
            return 'iOS 15.0';
          }
          // enableInteractivePopGesture 不返回值
          if (methodCall.method == 'enableInteractivePopGesture') {
            return null;
          }
          if (methodCall.method == 'disableInteractivePopGesture') {
            return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('getPlatformVersion', () {
    test('应该返回 iOS 版本号', () async {
      expect(await platform.getPlatformVersion(), 'iOS 15.0');
    });
  });

  group('setOnSystemBackGesture', () {
    test('设置回调后，收到 onSystemBackGesture 事件应该调用回调', () async {
      bool callbackCalled = false;

      platform.setOnSystemBackGesture(() {
        callbackCalled = true;
      });

      // 模拟原生端发送 onSystemBackGesture 事件
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'popscope_ios_plus',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onSystemBackGesture'),
            ),
            (ByteData? data) {},
          );

      // 等待事件处理完成
      await Future.delayed(const Duration(milliseconds: 10));

      expect(callbackCalled, true);
    });

    test('清除回调后，收到事件不应该调用回调', () async {
      bool callbackCalled = false;

      platform.setOnSystemBackGesture(() {
        callbackCalled = true;
      });

      // 清除回调
      platform.setOnSystemBackGesture(null);

      // 模拟原生端发送事件
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'popscope_ios_plus',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onSystemBackGesture'),
            ),
            (ByteData? data) {},
          );

      await Future.delayed(const Duration(milliseconds: 10));

      expect(callbackCalled, false);
    });
  });

  group('setNavigatorKey', () {
    testWidgets('设置 NavigatorKey 后，收到事件应该自动调用 maybePop', (
      WidgetTester tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      // 创建测试用的 MaterialApp
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const Scaffold()),
                    );
                  },
                  child: const Text('Push'),
                ),
              );
            },
          ),
        ),
      );

      platform.setNavigatorKey(navigatorKey, autoHandle: true);

      // 先推入一个页面
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();

      // 模拟原生端发送事件
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'popscope_ios_plus',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onSystemBackGesture'),
            ),
            (ByteData? data) {},
          );

      await tester.pumpAndSettle();

      // 应该已经返回到第一个页面
      expect(find.text('Push'), findsOneWidget);
    });

    test('autoHandle 为 false 时，不应该自动调用 maybePop', () async {
      final navigatorKey = GlobalKey<NavigatorState>();
      bool callbackCalled = false;

      platform.setNavigatorKey(navigatorKey, autoHandle: false);
      platform.setOnSystemBackGesture(() {
        callbackCalled = true;
      });

      // 模拟原生端发送事件
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'popscope_ios_plus',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onSystemBackGesture'),
            ),
            (ByteData? data) {},
          );

      await Future.delayed(const Duration(milliseconds: 10));

      // 回调应该被调用，但不会自动 pop
      expect(callbackCalled, true);
    });

    testWidgets('存在回调时应优先回调，避免自动 maybePop（WebView-safe）', (
      WidgetTester tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      bool callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const Scaffold(
                          body: Center(child: Text('Second Page')),
                        ),
                      ),
                    );
                  },
                  child: const Text('Push'),
                ),
              );
            },
          ),
        ),
      );

      platform.setNavigatorKey(navigatorKey, autoHandle: true);
      platform.setOnSystemBackGesture(() {
        callbackCalled = true;
      });

      // 进入第二页，如果自动 maybePop 被触发会被返回
      await tester.tap(find.text('Push'));
      await tester.pumpAndSettle();
      expect(find.text('Second Page'), findsOneWidget);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            'popscope_ios_plus',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('onSystemBackGesture'),
            ),
            (ByteData? data) {},
          );

      await tester.pumpAndSettle();

      expect(callbackCalled, true);
      expect(find.text('Second Page'), findsOneWidget);
    });
  });

  group('enableInteractivePopGesture', () {
    test('调用 setNavigatorKey 应该触发 enableInteractivePopGesture', () async {
      final navigatorKey = GlobalKey<NavigatorState>();
      bool enableCalled = false;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'enableInteractivePopGesture') {
              enableCalled = true;
            }
            return null;
          });

      platform.setNavigatorKey(navigatorKey);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(enableCalled, true);
    });

    test(
      '调用 setOnSystemBackGesture 应该触发 enableInteractivePopGesture',
      () async {
        bool enableCalled = false;

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              if (methodCall.method == 'enableInteractivePopGesture') {
                enableCalled = true;
              }
              return null;
            });

        platform.setOnSystemBackGesture(() {});

        await Future.delayed(const Duration(milliseconds: 10));

        expect(enableCalled, true);
      },
    );
  });

  group('gesture lifecycle', () {
    test('清除最后一个业务回调时应触发 disableInteractivePopGesture', () async {
      int enableCount = 0;
      int disableCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'enableInteractivePopGesture') {
              enableCount++;
            }
            if (methodCall.method == 'disableInteractivePopGesture') {
              disableCount++;
            }
            return null;
          });

      platform.setOnSystemBackGesture(() {});
      await Future.delayed(const Duration(milliseconds: 10));

      platform.setOnSystemBackGesture(null);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(enableCount, 1);
      expect(disableCount, 1);
    });

    test('重复启用同一能力时应保持幂等（只触发一次 enable）', () async {
      int enableCount = 0;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'enableInteractivePopGesture') {
              enableCount++;
            }
            return null;
          });

      platform.setOnSystemBackGesture(() {});
      platform.setOnSystemBackGesture(() {});
      await Future.delayed(const Duration(milliseconds: 10));

      expect(enableCount, 1);
    });

    testWidgets('注销最后一个页面回调后应触发 disableInteractivePopGesture', (
      WidgetTester tester,
    ) async {
      int enableCount = 0;
      int disableCount = 0;
      late BuildContext pageContext;

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            if (methodCall.method == 'enableInteractivePopGesture') {
              enableCount++;
            }
            if (methodCall.method == 'disableInteractivePopGesture') {
              disableCount++;
            }
            return null;
          });

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      platform.registerPopGestureCallback(() {}, pageContext);
      await tester.pump(const Duration(milliseconds: 10));

      platform.unregisterPopGestureCallback(pageContext);
      await tester.pump(const Duration(milliseconds: 10));

      expect(enableCount, 1);
      expect(disableCount, 1);
    });
  });

  group('direct mode decommissioned', () {
    test('调用 enableDirectEdgeGesture 应抛出 UnsupportedError', () async {
      expect(
        platform.enableDirectEdgeGesture(),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:popscope_ios_plus/popscope_ios_method_channel.dart';

const MethodChannel _channel = MethodChannel('popscope_ios_plus');
const StandardMethodCodec _codec = StandardMethodCodec();

Future<void> _emitNativeBackGesture() async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _channel.name,
        _codec.encodeMethodCall(
          const MethodCall('onSystemBackGesture', {
            'source': 'interactive-pop',
            'state': 'began',
            'route': 'integration_test_route',
            'action': 'native_event',
          }),
        ),
        (_) {},
      );
}

Widget _buildTwoPageApp({required GlobalKey<NavigatorState> navigatorKey}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    home: Builder(
      builder: (context) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: Center(child: Text('second-page')),
                    ),
                  ),
                );
              },
              child: const Text('push-second-page'),
            ),
          ),
        );
      },
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late MethodChannelPopscopeIos platform;
  late List<MethodCall> nativeCalls;
  late Future<Object?> Function(MethodCall methodCall) nativeResponse;

  setUp(() {
    nativeCalls = <MethodCall>[];
    nativeResponse = (methodCall) async {
      switch (methodCall.method) {
        case 'getPlatformVersion':
          return 'iOS 18.0';
        case 'enableInteractivePopGesture':
          return <String, Object?>{
            'success': true,
            'state': 'enabled',
            'reason': 'delegate_hooked',
          };
        case 'disableInteractivePopGesture':
          return <String, Object?>{
            'success': true,
            'state': 'disabled',
            'reason': 'delegate_restored',
          };
        default:
          return null;
      }
    };

    platform = MethodChannelPopscopeIos();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (methodCall) async {
          nativeCalls.add(methodCall);
          return nativeResponse(methodCall);
        });
  });

  tearDown(() async {
    platform.setOnSystemBackGesture(null);
    platform.setNavigatorKey(null, autoHandle: false);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets('有业务回调时优先回调，不会误触发 maybePop', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var callbackCount = 0;

    await tester.pumpWidget(_buildTwoPageApp(navigatorKey: navigatorKey));

    platform.setNavigatorKey(navigatorKey, autoHandle: true);
    platform.setOnSystemBackGesture(() {
      callbackCount += 1;
    });

    await tester.tap(find.text('push-second-page'));
    await tester.pumpAndSettle();
    expect(find.text('second-page'), findsOneWidget);

    await _emitNativeBackGesture();
    await tester.pumpAndSettle();

    expect(callbackCount, 1);
    expect(find.text('second-page'), findsOneWidget);
  });

  testWidgets('无业务回调且启用自动导航时触发 maybePop', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(_buildTwoPageApp(navigatorKey: navigatorKey));

    platform.setNavigatorKey(navigatorKey, autoHandle: true);

    await tester.tap(find.text('push-second-page'));
    await tester.pumpAndSettle();
    expect(find.text('second-page'), findsOneWidget);

    await _emitNativeBackGesture();
    await tester.pumpAndSettle();

    expect(find.text('push-second-page'), findsOneWidget);
    expect(find.text('second-page'), findsNothing);
  });

  testWidgets('最后一个 consumer 移除后触发 disable', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    final registerContext = tester.element(find.byType(SizedBox));
    platform.registerPopGestureCallback(() {}, registerContext);
    await tester.pump(const Duration(milliseconds: 10));

    final unregisterContext = tester.element(find.byType(SizedBox));
    platform.unregisterPopGestureCallback(unregisterContext);
    await tester.pump(const Duration(milliseconds: 10));

    final enableCount = nativeCalls
        .where((call) => call.method == 'enableInteractivePopGesture')
        .length;
    final disableCount = nativeCalls
        .where((call) => call.method == 'disableInteractivePopGesture')
        .length;

    expect(enableCount, 1);
    expect(disableCount, 1);
  });

  testWidgets('missing_root 失败后会自动重试 enable（最多重试链路可达）', (tester) async {
    var enableCount = 0;

    nativeResponse = (methodCall) async {
      if (methodCall.method == 'enableInteractivePopGesture') {
        enableCount += 1;
        if (enableCount == 1) {
          return <String, Object?>{
            'success': false,
            'state': 'disabled',
            'reason': 'missing_root',
          };
        }
        return <String, Object?>{
          'success': true,
          'state': 'enabled',
          'reason': 'delegate_hooked',
        };
      }
      if (methodCall.method == 'disableInteractivePopGesture') {
        return <String, Object?>{
          'success': true,
          'state': 'disabled',
          'reason': 'delegate_restored',
        };
      }
      return null;
    };

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    platform.setOnSystemBackGesture(() {});
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(enableCount, 2);
  });

  testWidgets('异常失败原因为非 missing_root 时不会自动重试，可手动触发下一次同步', (tester) async {
    var enableCount = 0;

    nativeResponse = (methodCall) async {
      if (methodCall.method == 'enableInteractivePopGesture') {
        enableCount += 1;
        if (enableCount == 1) {
          return <String, Object?>{
            'success': false,
            'state': 'disabled',
            'reason': 'delegate_rejected',
          };
        }
        return <String, Object?>{
          'success': true,
          'state': 'enabled',
          'reason': 'delegate_hooked',
        };
      }
      return null;
    };

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

    platform.setOnSystemBackGesture(() {});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(enableCount, 1);

    platform.setOnSystemBackGesture(() {});
    await tester.pump();
    expect(enableCount, 2);
  });
}

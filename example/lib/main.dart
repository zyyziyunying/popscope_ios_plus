import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popscope_ios_plus/popscope_ios.dart';
import 'package:cupertino_will_pop_scope/cupertino_will_pop_scope.dart';
import 'package:popscope_ios_plus_example/widgets/build_example_card.dart';
import 'package:popscope_ios_plus_example/pages/basic_example_page.dart';
import 'package:popscope_ios_plus_example/pages/custom_example_page.dart';
import 'package:popscope_ios_plus_example/pages/popscope_example_page.dart';
import 'package:popscope_ios_plus_example/pages/nested_example_page.dart';
import 'package:popscope_ios_plus_example/pages/bad_example_page.dart';
import 'package:popscope_ios_plus_example/pages/comparison_example_page.dart';

/// 创建全局 Navigator Key
///
/// 用于 MaterialApp 的 navigatorKey 参数，管理全局导航状态
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  // 确保 Flutter 绑定已初始化
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Popscope iOS 示例',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        // ! 为了对比示例，配置 cupertino_will_pop_scope 的 pageTransitionsTheme
        // 注意：popscope_ios 不需要此配置
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.iOS: CupertinoWillPopScopePageTransionsBuilder(),
          },
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// 主页面：作为所有测试页面的导航中心
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _platformVersion = 'Unknown';
  final _popscopeIosPlugin = PopscopeIos();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    String platformVersion;
    try {
      platformVersion =
          await _popscopeIosPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Popscope iOS 示例'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题区域
            const Icon(Icons.apps, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              '测试页面导航',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Running on: $_platformVersion',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // 示例卡片列表
            ExampleCard(
              title: '基础示例',
              description: '展示自动处理返回手势的基本用法',
              icon: Icons.auto_awesome,
              color: Colors.blue,
              badge: '推荐',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BasicExamplePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ExampleCard(
              title: '自定义处理示例',
              description: '展示如何使用自定义回调处理返回手势',
              icon: Icons.settings,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomExamplePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ExampleCard(
              title: 'PopScope 集成示例',
              description: '展示如何与 PopScope widget 集成',
              icon: Icons.integration_instructions,
              color: Colors.purple,
              badge: 'Flutter 3.12+',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PopscopeExamplePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ExampleCard(
              title: '多页面嵌套示例',
              description: '展示多页面嵌套时回调栈的管理',
              icon: Icons.layers,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NestedExamplePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ExampleCard(
              title: '负面示例：全局回调覆盖问题',
              description: '展示使用已废弃的 setOnLeftBackGesture 方法会导致的问题',
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
              badge: '⚠️ 负面示例',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BadExamplePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ExampleCard(
              title: '库对比示例',
              description: '对比 popscope_ios 与 cupertino_will_pop_scope',
              icon: Icons.compare_arrows,
              color: Colors.purple,
              badge: '⭐ 推荐',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ComparisonExamplePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // 说明卡片
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          '使用说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '点击上方任意示例卡片进入对应的测试页面，'
                      '体验不同的返回手势处理方式。\n\n'
                      '• 基础示例：最简单的自动处理方式\n'
                      '• 自定义处理：显示确认对话框\n'
                      '• PopScope 集成：与 Flutter 3.12+ 的 PopScope 集成\n'
                      '• 多页面嵌套：验证回调栈管理机制\n'
                      '• 负面示例：展示全局回调覆盖的问题\n'
                      '• 库对比：对比 popscope_ios 与其他库的优势',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

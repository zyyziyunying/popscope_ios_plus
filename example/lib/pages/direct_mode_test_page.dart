import 'dart:io';

import 'package:flutter/material.dart';
import 'package:popscope_ios_plus/widgets/platform_popscope.dart';

/// 直接模式测试页面
///
/// 用于验证 UIScreenEdgePanGestureRecognizer 方案的可行性
///
/// 测试场景：
/// 1. 基本手势触发 - 从左边缘滑动
/// 2. 水平列表冲突测试 - 在 ListView.horizontal 中滑动
/// 3. 垂直列表边缘滑动测试
/// 4. 灵敏度测试 - 快/慢滑动
class DirectModeTestPage extends StatefulWidget {
  const DirectModeTestPage({super.key});

  @override
  State<DirectModeTestPage> createState() => _DirectModeTestPageState();
}

class _DirectModeTestPageState extends State<DirectModeTestPage> {
  int _gestureCount = 0;
  bool _directModeEnabled = false;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _directModeEnabled = Platform.isIOS;
        });
        if (Platform.isIOS) {
          _addLog('直接模式由组件启用（PlatformPopScope）');
        } else {
          _addLog('非 iOS 平台，直接模式不可用');
        }
      }
    });
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 20) {
        _logs.removeLast();
      }
    });
  }

  void _handlePopGesture() {
    setState(() {
      _gestureCount++;
    });
    _addLog('手势触发 #$_gestureCount');
  }

  @override
  Widget build(BuildContext context) {
    return PlatformPopScope(
      canPop: false,
      useDirectEdgeGesture: true,
      onPop: _handlePopGesture,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('直接模式测试'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 状态卡片
              _buildStatusCard(),
              const SizedBox(height: 16),

              // 测试场景 1：基本手势触发
              _buildTestSection(
                '测试 1：基本手势触发',
                '从屏幕左边缘向右滑动，观察手势触发次数是否增加。',
                Icons.swipe_right,
                Colors.green,
              ),

              // 测试场景 2：与水平列表的冲突
              _buildTestSection(
                '测试 2：水平列表冲突测试',
                '在下方水平列表中左右滑动，观察是否误触发边缘手势。',
                Icons.view_list,
                Colors.blue,
              ),

              // 水平滑动列表
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 20,
                  itemBuilder: (context, index) => Container(
                    width: 100,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Center(
                      child: Text(
                        'Item $index',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 测试场景 3：垂直列表边缘滑动
              _buildTestSection(
                '测试 3：垂直列表边缘滑动',
                '从下方列表左边缘开始向右滑动，测试是否能正确触发手势。',
                Icons.list,
                Colors.purple,
              ),

              // 垂直列表（紧贴左边缘）
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.purple.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: 10,
                  itemBuilder: (context, index) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child: Text('$index'),
                    ),
                    title: Text('列表项 $index'),
                    subtitle: const Text('从左边缘向右滑动测试'),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 测试场景 4：灵敏度测试
              _buildTestSection(
                '测试 4：灵敏度测试',
                '分别进行快速滑动和慢速滑动，观察触发的一致性。',
                Icons.speed,
                Colors.amber,
              ),

              // 日志区域
              const SizedBox(height: 16),
              _buildLogSection(),

              // 返回按钮
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('返回首页'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _directModeEnabled ? Icons.check_circle : Icons.pending,
                  color: _directModeEnabled ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  '模式: ${_directModeEnabled ? "直接边缘手势" : "等待启用..."}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app, size: 32, color: Colors.orange),
                  const SizedBox(width: 12),
                  Text(
                    '$_gestureCount',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '次触发',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestSection(
    String title,
    String description,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(51),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(description),
          ),
        ),
      ),
    );
  }

  Widget _buildLogSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '日志',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _logs.clear();
                    });
                  },
                  child: const Text('清除'),
                ),
              ],
            ),
            const Divider(),
            SizedBox(
              height: 150,
              child: _logs.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无日志',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          _logs[index],
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

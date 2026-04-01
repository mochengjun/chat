import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sec_chat/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('图片加载认证测试', () {
    testWidgets('自动登录并验证图片加载', (WidgetTester tester) async {
      // 启动应用
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // 等待登录页面加载
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 查找用户名输入框并输入
      final usernameField = find.byType(TextField).first;
      await tester.ensureVisible(usernameField);
      await tester.tap(usernameField);
      await tester.pumpAndSettle();
      await tester.enterText(usernameField, 'imgtest');
      await tester.pumpAndSettle();

      // 查找密码输入框并输入
      final passwordField = find.byType(TextField).last;
      await tester.ensureVisible(passwordField);
      await tester.tap(passwordField);
      await tester.pumpAndSettle();
      await tester.enterText(passwordField, 'Test123456!');
      await tester.pumpAndSettle();

      // 点击登录按钮
      final loginButton = find.widgetWithText(ElevatedButton, '登录');
      await tester.ensureVisible(loginButton);
      await tester.tap(loginButton);

      // 等待登录完成并跳转到主页
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 验证是否成功登录（检查是否有聊天列表或主页元素）
      expect(find.byType(ListView), findsOneWidget,
          reason: '登录后应显示聊天列表');

      print('✓ 登录成功，已加载聊天列表');

      // 查找并点击"图片测试房间"
      final roomFinder = find.text('图片测试房间');
      expect(roomFinder, findsOneWidget, reason: '应找到图片测试房间');
      await tester.tap(roomFinder);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      print('✓ 已进入图片测试房间');

      // 等待图片加载
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 查找图片消息（CachedNetworkImage）
      final imageFinder = find.byType(Image);
      final imageCount = imageFinder.evaluate().length;
      print('找到 $imageCount 个图片组件');

      // 验证图片加载成功（至少应该有一些图片组件）
      expect(imageCount > 0, true,
          reason: '聊天房间中应该加载图片');

      print('✓ 图片加载测试通过 - 成功加载 $imageCount 个图片');

      // 等待一段时间观察
      await tester.pumpAndSettle(const Duration(seconds: 3));
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/server_config_service.dart';
import '../../../../main.dart';
import '../bloc/auth_bloc.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      // 先检查网络连接
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无网络连接，请检查 WiFi 或移动数据'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      context.read<AuthBloc>().add(LoginRequested(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        deviceType: 'mobile',
      ));
    }
  }

  Future<void> _showServerConfigDialog() async {
    final config = await ServerConfigService.loadConfig();
    final hostController = TextEditingController(text: config.host);
    final portController = TextEditingController(text: config.port.toString());

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('服务器配置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: '服务器地址',
                  hintText: '例如: 172.25.194.201',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: portController,
                decoration: const InputDecoration(
                  labelText: '端口',
                  hintText: '例如: 8081',
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final host = hostController.text.trim();
                final port = int.tryParse(portController.text.trim());
                if (host.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('请输入服务器地址')),
                  );
                  return;
                }
                if (port == null || port <= 0 || port > 65535) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('请输入有效的端口号 (1-65535)')),
                  );
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      final host = hostController.text.trim();
      final port = int.parse(portController.text.trim());
      final configService = getIt<ServerConfigService>();
      await configService.saveConfig(host, port);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('服务器地址已更新为 $host:$port')),
        );
        await RestartWidget.restart(context);
      }
    }

    hostController.dispose();
    portController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            _passwordController.clear();
            context.go('/');
          } else if (state is AuthMFARequired) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('需要进行两步验证')),
            );
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              // 设置按钮 - 右上角
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  tooltip: '服务器配置',
                  onPressed: _showServerConfigDialog,
                ),
              ),
              // 主内容
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Icon(
                          Icons.chat_bubble_rounded,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        
                        // 标题
                        Text(
                          'SecChat',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '企业安全通讯平台',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        
                        // 用户名输入框
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入用户名';
                            }
                            if (value.length < 3) {
                              return '用户名至少3个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // 密码输入框
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: '密码',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _onLogin(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入密码';
                            }
                            if (value.length < 8) {
                              return '密码至少8个字符';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // 登录按钮
                        BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                            final isLoading = state is AuthLoading;
                            return ElevatedButton(
                              onPressed: isLoading ? null : _onLogin,
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('登录'),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // 注册链接
                        TextButton(
                          onPressed: () => context.go('/register'),
                          child: const Text('没有账号？立即注册'),
                        ),
                        const SizedBox(height: 24),
                        
                        // 分隔线
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[300])),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                '或',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[300])),
                          ],
                        ),
                        const SizedBox(height: 24),
                        
                        // Google 登录按钮
                        OutlinedButton.icon(
                          onPressed: () {
                            context.read<AuthBloc>().add(const GoogleLoginRequested());
                          },
                          icon: const Icon(Icons.login, size: 24),
                          label: const Text('使用 Google 登录'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

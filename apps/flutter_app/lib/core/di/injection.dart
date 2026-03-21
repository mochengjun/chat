import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';
import '../network/websocket_client.dart';
import '../network/server_config_service.dart';
import '../security/secure_storage.dart';
import '../services/push_notification_service.dart';
import '../services/media_service.dart';
import '../services/webrtc_service.dart';
import '../services/e2ee_service.dart';

// Auth imports
import '../../features/authentication/data/datasources/auth_remote_datasource.dart';
import '../../features/authentication/data/datasources/auth_local_datasource.dart';
import '../../features/authentication/data/datasources/oauth_datasource.dart';
import '../../features/authentication/data/repositories/auth_repository_impl.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/usecases/login_usecase.dart';
import '../../features/authentication/domain/usecases/register_usecase.dart';
import '../../features/authentication/domain/usecases/logout_usecase.dart';
import '../../features/authentication/domain/usecases/oauth_login_usecase.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';

// Chat imports
import '../../features/chat/data/datasources/chat_remote_datasource.dart';
import '../../features/chat/data/datasources/chat_local_datasource.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/get_rooms_usecase.dart';
import '../../features/chat/domain/usecases/get_messages_usecase.dart';
import '../../features/chat/domain/usecases/send_message_usecase.dart';
import '../../features/chat/domain/usecases/create_room_usecase.dart';
import '../../features/chat/domain/usecases/mark_as_read_usecase.dart';
import '../../features/chat/presentation/bloc/room_list_bloc.dart';
import '../../features/chat/presentation/bloc/chat_room_bloc.dart';

// Call imports
import '../../features/call/services/audio_session_manager.dart';
import '../../features/call/presentation/bloc/call_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // 从持久化存储读取服务器配置（若无存储则使用 NetworkConfig 默认值）
  final config = await ServerConfigService.loadConfig();
  final apiBaseUrl = ServerConfigService.buildApiBaseUrl(config.host, config.port);
  
  // Core
  getIt.registerLazySingleton<SecureStorageService>(() => SecureStorageService());
  getIt.registerLazySingleton<ServerConfigService>(() => ServerConfigService());
  getIt.registerLazySingleton<Dio>(() => createDio(apiBaseUrl));
  getIt.registerLazySingleton<DioClient>(() => DioClient(getIt<Dio>()));
  
  // WebSocket Client
  getIt.registerLazySingleton<WebSocketClient>(() => WebSocketClient(
    baseUrl: apiBaseUrl,
    tokenProvider: () {
      final storage = getIt<SecureStorageService>();
      return storage.getAccessTokenSync() ?? '';
    },
  ));

  // ==================== Auth Module ====================
  
  // Auth Data Sources
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<DioClient>()),
  );
  getIt.registerLazySingleton<AuthLocalDataSource>(
    () => AuthLocalDataSourceImpl(getIt<SecureStorageService>()),
  );

  // Auth Repositories
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: getIt<AuthRemoteDataSource>(),
      localDataSource: getIt<AuthLocalDataSource>(),
    ),
  );

  // Auth Use Cases
  getIt.registerLazySingleton(() => LoginUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => RegisterUseCase(getIt<AuthRepository>()));
  getIt.registerLazySingleton(() => LogoutUseCase(getIt<AuthRepository>()));

  // OAuth Data Source
  getIt.registerLazySingleton<OAuthDataSource>(
    () => OAuthDataSourceImpl(getIt<DioClient>()),
  );

  // OAuth Use Case
  getIt.registerLazySingleton(() => OAuthLoginUseCase(
    oauthDataSource: getIt<OAuthDataSource>(),
    authRepository: getIt<AuthRepository>(),
  ));

  // Auth Blocs
  getIt.registerFactory(() => AuthBloc(
    loginUseCase: getIt<LoginUseCase>(),
    registerUseCase: getIt<RegisterUseCase>(),
    logoutUseCase: getIt<LogoutUseCase>(),
    oauthLoginUseCase: getIt<OAuthLoginUseCase>(),
  ));

  // ==================== Chat Module ====================
  
  // Chat Local Data Source (延迟初始化，首次使用时自动初始化)
  getIt.registerLazySingleton<ChatLocalDataSource>(() {
    final ds = ChatLocalDataSourceImpl();
    // 延迟初始化，避免启动时数据库创建导致崩溃
    Future.delayed(const Duration(seconds: 3), () {
      ds.init().catchError((e) {
        print('[DI] Chat local data source init failed: $e');
        // 数据库初始化失败不影响应用启动，可以继续使用内存缓存
      });
    });
    return ds;
  });
  
  // Chat Remote Data Source
  getIt.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(getIt<DioClient>()),
  );

  // Chat Repository
  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(
      remoteDataSource: getIt<ChatRemoteDataSource>(),
      localDataSource: getIt<ChatLocalDataSource>(),
      webSocketClient: getIt<WebSocketClient>(),
    ),
  );

  // Chat Use Cases
  getIt.registerLazySingleton(() => GetRoomsUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => GetMessagesUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => SendMessageUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => CreateRoomUseCase(getIt<ChatRepository>()));
  getIt.registerLazySingleton(() => MarkAsReadUseCase(getIt<ChatRepository>()));

  // Chat Blocs
  getIt.registerFactory(() => RoomListBloc(
    getRoomsUseCase: getIt<GetRoomsUseCase>(),
    createRoomUseCase: getIt<CreateRoomUseCase>(),
    repository: getIt<ChatRepository>(),
  ));
  
  getIt.registerFactory(() => ChatRoomBloc(
    getMessagesUseCase: getIt<GetMessagesUseCase>(),
    sendMessageUseCase: getIt<SendMessageUseCase>(),
    markAsReadUseCase: getIt<MarkAsReadUseCase>(),
    repository: getIt<ChatRepository>(),
  ));

  // ==================== Push Notification Module ====================
  
  getIt.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(
      dio: getIt<Dio>(),
      baseUrl: apiBaseUrl,
    ),
  );

  // ==================== Media Module ====================
  
  // MediaService 延迟初始化
  getIt.registerLazySingleton<MediaService>(() {
    final service = MediaService(
      dio: getIt<Dio>(),
      baseUrl: apiBaseUrl,
    );
    // 异步初始化，不阻塞
    service.initialize().catchError((e) => print('[DI] Media service init failed: $e'));
    return service;
  });

  // ==================== WebRTC Module ====================
  
  // WebRTC 服务延迟初始化（用户登录后再初始化，避免未登录时请求 API）
  getIt.registerLazySingleton<WebRTCService>(() => WebRTCService(
    dio: getIt<Dio>(),
    baseUrl: apiBaseUrl,
    tokenProvider: () {
      final storage = getIt<SecureStorageService>();
      return storage.getAccessTokenSync() ?? '';
    },
  ));

  // ==================== Call Module ====================
  
  // Audio Session Manager 延迟初始化
  getIt.registerLazySingleton<AudioSessionManager>(() {
    final manager = AudioSessionManager();
    // 异步初始化，不阻塞
    manager.initialize().catchError((e) => print('[DI] Audio session init failed: $e'));
    return manager;
  });

  // Call BLoC
  getIt.registerFactory(() => CallBloc(
    webrtcService: getIt<WebRTCService>(),
    audioSessionManager: getIt<AudioSessionManager>(),
  ));

  // ==================== E2EE Module ====================
  
  // E2EEService 延迟初始化
  getIt.registerLazySingleton<E2EEService>(() {
    final service = E2EEService(
      dio: getIt<Dio>(),
      baseUrl: apiBaseUrl,
    );
    // 异步初始化，不阻塞
    service.initialize().catchError((e) => print('[DI] E2EE service init failed: $e'));
    return service;
  });
}

Dio createDio(String baseUrl) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),  // 缩短连接超时，便于快速失败重试
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 15),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  // 添加重试拦截器 - 对连接超时自动重试
  dio.interceptors.add(InterceptorsWrapper(
    onError: (error, handler) async {
      // 只对连接错误进行重试，且不重试 refresh token 请求
      final isRetryable = error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.sendTimeout;
      final isRefreshRequest = error.requestOptions.path.contains('/auth/refresh');
      
      // 获取当前重试次数
      final retryCount = (error.requestOptions.extra['retryCount'] ?? 0) as int;
      const maxRetries = 2;
      
      if (isRetryable && !isRefreshRequest && retryCount < maxRetries) {
        print('[Dio] 连接失败，正在重试 (${retryCount + 1}/$maxRetries)...');
        
        // 等待一小段时间后重试
        await Future.delayed(Duration(seconds: 1 + retryCount));
        
        // 增加重试计数
        error.requestOptions.extra['retryCount'] = retryCount + 1;
        
        try {
          final response = await dio.fetch(error.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          // 重试失败，继续传递错误
        }
      }
      handler.next(error);
    },
  ));

  // 添加Auth拦截器，自动为请求添加Authorization header
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final storage = getIt<SecureStorageService>();
      final token = storage.getAccessTokenSync();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) async {
      // 如果是 401 错误，尝试刷新 token 并重试
      // 但是如果是 refresh token 请求本身失败，不要再重试（防止无限循环）
      final isRefreshRequest = error.requestOptions.path.contains('/auth/refresh');
      
      // 只有当有 token 且不是刷新请求时才尝试刷新
      if (error.response?.statusCode == 401 && !isRefreshRequest) {
        try {
          final storage = getIt<SecureStorageService>();
          final refreshToken = await storage.getRefreshToken();

          // 如果没有 refresh token，说明用户从未登录或已登出，直接传递错误
          if (refreshToken == null || refreshToken.isEmpty) {
            handler.next(error);
            return;
          }

          // 尝试刷新 token
          final authRemoteDataSource = getIt<AuthRemoteDataSource>();
          final result = await authRemoteDataSource.refreshToken(refreshToken);

          // 保存新 token
          await storage.saveTokens(
            accessToken: result.accessToken!,
            refreshToken: result.refreshToken!,
          );

          // 重试原请求
          error.requestOptions.headers['Authorization'] = 'Bearer ${result.accessToken}';
          final response = await dio.fetch(error.requestOptions);
          return handler.resolve(response);
        } catch (e) {
          // 刷新 token 失败，清除本地认证状态
          try {
            final storage = getIt<SecureStorageService>();
            await storage.clearAuth();
          } catch (_) {}
          // 继续传递原来的 401 错误，让 UI 处理登录过期
        }
      }
      handler.next(error);
    },
  ));

  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  return dio;
}

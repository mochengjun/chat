import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/secure_storage.dart';
import '../../../../core/services/app_badge_service.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_rooms_usecase.dart';
import '../../domain/usecases/create_room_usecase.dart';
import 'room_list_event.dart';
import 'room_list_state.dart';

class RoomListBloc extends Bloc<RoomListEvent, RoomListState> {
  final GetRoomsUseCase _getRoomsUseCase;
  final CreateRoomUseCase _createRoomUseCase;
  final ChatRepository _repository;
  
  StreamSubscription<Room>? _roomUpdateSubscription;
  StreamSubscription<Message>? _messageSubscription;
  
  // 缓存当前用户ID
  String? _cachedCurrentUserId;
  // 当前打开的房间ID（用于判断是否增加未读数）
  String? _currentOpenRoomId;
  // 竞态保护标志
  bool _isRefreshing = false;

  RoomListBloc({
    required GetRoomsUseCase getRoomsUseCase,
    required CreateRoomUseCase createRoomUseCase,
    required ChatRepository repository,
  })  : _getRoomsUseCase = getRoomsUseCase,
        _createRoomUseCase = createRoomUseCase,
        _repository = repository,
        super(const RoomListInitial()) {
    on<LoadRooms>(_onLoadRooms);
    on<RefreshRooms>(_onRefreshRooms);
    on<CreateRoom>(_onCreateRoom);
    on<RoomUpdated>(_onRoomUpdated);
    on<NewMessageArrived>(_onNewMessageArrived);
    on<MarkRoomAsRead>(_onMarkRoomAsRead);
    on<MuteRoom>(_onMuteRoom);
    on<PinRoom>(_onPinRoom);
    on<LeaveRoom>(_onLeaveRoom);

    _roomUpdateSubscription = _repository.roomUpdateStream.listen((room) {
      add(RoomUpdated(room));
    });
    
    // 监听新消息，更新房间未读数和最后一条消息
    _messageSubscription = _repository.messageStream.listen((message) {
      // 跳过已删除的消息
      if (!message.isDeleted) {
        add(NewMessageArrived(message));
      }
    });
    
    // 初始化时获取当前用户ID
    _initCurrentUserId();
  }
  
  Future<void> _initCurrentUserId() async {
    try {
      final storage = getIt<SecureStorageService>();
      final userInfo = await storage.getUserInfo();
      _cachedCurrentUserId = userInfo['userId'];
    } catch (e) {
      // 初始化失败时保持 _cachedCurrentUserId 为 null
    }
  }

  Future<void> _onLoadRooms(
    LoadRooms event,
    Emitter<RoomListState> emit,
  ) async {
    emit(const RoomListLoading());

    try {
      await _repository.connect();
      final rooms = await _getRoomsUseCase();

      // 更新桌面图标角标
      await _updateBadgeFromRooms(rooms);

      emit(RoomListLoaded(rooms: _sortRooms(rooms)));
    } catch (e) {
      emit(RoomListError(message: e.toString()));
    }
  }

  Future<void> _onRefreshRooms(
    RefreshRooms event,
    Emitter<RoomListState> emit,
  ) async {
    // 竞态保护：如果已经在刷新中，直接返回
    if (_isRefreshing) return;
    _isRefreshing = true;
    
    try {
      final rooms = await _getRoomsUseCase();

      // 更新桌面图标角标
      await _updateBadgeFromRooms(rooms);

      emit(RoomListLoaded(rooms: _sortRooms(rooms)));
    } catch (e) {
      final currentState = state;
      if (currentState is RoomListLoaded) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      } else {
        emit(RoomListError(message: e.toString()));
      }
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _onCreateRoom(
    CreateRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      emit(currentState.copyWith(isCreatingRoom: true));
      
      try {
        final room = await _createRoomUseCase(
          name: event.name,
          description: event.description,
          type: event.type,
          memberIds: event.memberIds,
          retentionHours: event.retentionHours,
        );
        
        final updatedRooms = [room, ...currentState.rooms];
        emit(RoomListLoaded(rooms: _sortRooms(updatedRooms)));
      } catch (e) {
        emit(currentState.copyWith(isCreatingRoom: false));
        emit(RoomListError(
          message: '创建房间失败: ${e.toString()}',
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  void _onRoomUpdated(
    RoomUpdated event,
    Emitter<RoomListState> emit,
  ) {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      final updatedRooms = currentState.rooms.map((room) {
        return room.id == event.room.id ? event.room : room;
      }).toList();
      
      emit(RoomListLoaded(rooms: _sortRooms(updatedRooms)));
    }
  }

  /// 处理新消息到达：更新房间的未读数和最后一条消息
  void _onNewMessageArrived(
    NewMessageArrived event,
    Emitter<RoomListState> emit,
  ) {
    final currentState = state;
    if (currentState is! RoomListLoaded) return;

    final message = event.message;
    final isOwnMessage = _cachedCurrentUserId != null &&
                          message.senderId == _cachedCurrentUserId;
    // 当前打开的房间不增加未读数
    final isCurrentRoom = _currentOpenRoomId == message.roomId;

    final updatedRooms = currentState.rooms.map((room) {
      if (room.id != message.roomId) return room;

      // 更新最后一条消息和未读数
      return room.copyWith(
        lastMessage: message,
        // 如果不是自己发的消息，且不是当前打开的房间，增加未读数
        unreadCount: (!isOwnMessage && !isCurrentRoom)
            ? room.unreadCount + 1
            : room.unreadCount,
        updatedAt: message.createdAt,
      );
    }).toList();

    // 更新桌面图标角标
    if (!isOwnMessage && !isCurrentRoom) {
      appBadgeService.incrementRoomUnread(message.roomId);
    }

    emit(RoomListLoaded(rooms: _sortRooms(updatedRooms)));
  }

  /// 标记房间已读：清零未读数
  void _onMarkRoomAsRead(
    MarkRoomAsRead event,
    Emitter<RoomListState> emit,
  ) {
    // 更新当前打开的房间ID
    _currentOpenRoomId = event.roomId;

    final currentState = state;
    if (currentState is! RoomListLoaded) return;

    final updatedRooms = currentState.rooms.map((room) {
      if (room.id != event.roomId) return room;
      return room.copyWith(unreadCount: 0);
    }).toList();

    // 清除该房间的桌面图标角标
    appBadgeService.clearRoomUnread(event.roomId);

    emit(RoomListLoaded(rooms: updatedRooms));
  }

  Future<void> _onMuteRoom(
    MuteRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      try {
        await _repository.muteRoom(event.roomId, event.muted);
        
        final updatedRooms = currentState.rooms.map((room) {
          return room.id == event.roomId
              ? room.copyWith(isMuted: event.muted)
              : room;
        }).toList();
        
        emit(RoomListLoaded(rooms: updatedRooms));
      } catch (e) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  Future<void> _onPinRoom(
    PinRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      try {
        await _repository.pinRoom(event.roomId, event.pinned);
        
        final updatedRooms = currentState.rooms.map((room) {
          return room.id == event.roomId
              ? room.copyWith(isPinned: event.pinned)
              : room;
        }).toList();
        
        emit(RoomListLoaded(rooms: _sortRooms(updatedRooms)));
      } catch (e) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  Future<void> _onLeaveRoom(
    LeaveRoom event,
    Emitter<RoomListState> emit,
  ) async {
    final currentState = state;
    if (currentState is RoomListLoaded) {
      try {
        await _repository.leaveRoom(event.roomId);
        
        final updatedRooms = currentState.rooms
            .where((room) => room.id != event.roomId)
            .toList();
        
        emit(RoomListLoaded(rooms: updatedRooms));
      } catch (e) {
        emit(RoomListError(
          message: e.toString(),
          cachedRooms: currentState.rooms,
        ));
      }
    }
  }

  List<Room> _sortRooms(List<Room> rooms) {
    final pinned = rooms.where((r) => r.isPinned).toList();
    final unpinned = rooms.where((r) => !r.isPinned).toList();

    pinned.sort((a, b) => (b.updatedAt ?? b.createdAt)
        .compareTo(a.updatedAt ?? a.createdAt));
    unpinned.sort((a, b) => (b.updatedAt ?? b.createdAt)
        .compareTo(a.updatedAt ?? a.createdAt));

    return [...pinned, ...unpinned];
  }

  /// 从房间列表更新桌面图标角标
  Future<void> _updateBadgeFromRooms(List<Room> rooms) async {
    final roomCounts = <String, int>{};
    for (final room in rooms) {
      if (room.unreadCount > 0) {
        roomCounts[room.id] = room.unreadCount;
      }
    }
    await appBadgeService.updateRoomCounts(roomCounts);
  }

  @override
  Future<void> close() {
    _roomUpdateSubscription?.cancel();
    _messageSubscription?.cancel();
    return super.close();
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../bloc/room_list_bloc.dart';
import '../bloc/room_list_event.dart';
import '../bloc/room_list_state.dart';
import '../widgets/room_list_item.dart';

class RoomListPage extends StatelessWidget {
  const RoomListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用全局的 RoomListBloc，不再创建新实例
    return const _RoomListView();
  }
}

class _RoomListView extends StatefulWidget {
  const _RoomListView();

  @override
  State<_RoomListView> createState() => _RoomListViewState();
}

class _RoomListViewState extends State<_RoomListView> {
  @override
  void initState() {
    super.initState();
    // 页面初始化时加载房间列表
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoomListBloc>().add(const LoadRooms());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showMoreMenu(context),
          ),
        ],
      ),
      body: BlocBuilder<RoomListBloc, RoomListState>(
        builder: (context, state) {
          if (state is RoomListLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (state is RoomListError) {
            return _buildErrorView(context, state);
          }
          
          if (state is RoomListLoaded) {
            return _buildRoomList(context, state);
          }
          
          // RoomListInitial 或其他未处理状态
          return const Center(child: CircularProgressIndicator());
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRoomDialog(context),
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildRoomList(BuildContext context, RoomListLoaded state) {
    if (state.rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无会话',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showCreateRoomDialog(context),
              child: const Text('开始新聊天'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<RoomListBloc>().add(const RefreshRooms());
      },
      child: ListView.builder(
        itemCount: state.rooms.length,
        itemBuilder: (context, index) {
          final room = state.rooms[index];
          return RoomListItem(
            room: room,
            onTap: () => context.push('/room/${room.id}'),
            onLongPress: () => _showRoomOptions(context, room),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, RoomListError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            '加载失败',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            state.message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<RoomListBloc>().add(const LoadRooms());
            },
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showSearch(
      context: context,
      delegate: _RoomSearchDelegate(),
    );
  }

  void _showMoreMenu(BuildContext context) {
    final bloc = context.read<RoomListBloc>();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('创建群聊'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showCreateRoomDialogWithBloc(context, bloc, isGroup: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('添加好友'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddFriendDialog(context, bloc);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('扫一扫'),
              onTap: () {
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomDialog(BuildContext context, {bool isGroup = false}) {
    final bloc = context.read<RoomListBloc>();
    _showCreateRoomDialogWithBloc(context, bloc, isGroup: isGroup);
  }

  void _showCreateRoomDialogWithBloc(BuildContext context, RoomListBloc bloc, {bool isGroup = false}) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isGroup ? '创建群聊' : '新建会话'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '输入会话名称',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: '描述 (可选)',
                hintText: '输入会话描述',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                bloc.add(CreateRoom(
                  name: nameController.text.trim(),
                  description: descController.text.trim().isNotEmpty 
                      ? descController.text.trim() 
                      : null,
                  type: isGroup ? RoomType.group : RoomType.direct,
                ));
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showRoomOptions(BuildContext context, Room room) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(room.isPinned ? Icons.push_pin_outlined : Icons.push_pin),
              title: Text(room.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                context.read<RoomListBloc>().add(PinRoom(
                  roomId: room.id,
                  pinned: !room.isPinned,
                ));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: Icon(room.isMuted ? Icons.notifications : Icons.notifications_off),
              title: Text(room.isMuted ? '取消静音' : '静音'),
              onTap: () {
                context.read<RoomListBloc>().add(MuteRoom(
                  roomId: room.id,
                  muted: !room.isMuted,
                ));
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app),
              title: const Text('退出会话'),
              onTap: () {
                Navigator.pop(sheetContext);
                _confirmLeaveRoom(context, room);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLeaveRoom(BuildContext context, Room room) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出会话'),
        content: Text('确定要退出 "${room.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<RoomListBloc>().add(LeaveRoom(room.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context, RoomListBloc bloc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => _AddFriendSheet(
          scrollController: scrollController,
          bloc: bloc,
        ),
      ),
    );
  }
}

/// 添加好友的底部弹窗组件
class _AddFriendSheet extends StatefulWidget {
  final ScrollController scrollController;
  final RoomListBloc bloc;

  const _AddFriendSheet({
    required this.scrollController,
    required this.bloc,
  });

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _isCreating = false;
  Timer? _debounce;
  late ChatRepository _chatRepository;

  @override
  void initState() {
    super.initState();
    _chatRepository = getIt<ChatRepository>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _chatRepository.searchUsers(query.trim());
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('搜索失败: ${e.toString()}')),
          );
        }
      }
    });
  }

  Future<void> _createDirectChat(User user) async {
    if (_isCreating) return;
    
    setState(() => _isCreating = true);
    
    try {
      // 创建私聊房间
      widget.bloc.add(CreateRoom(
        name: user.displayName,
        type: RoomType.direct,
        memberIds: [user.id],
      ));
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已向 ${user.displayName} 发起私聊')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // 顶部拖拽指示器和标题
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '添加好友',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
        // 搜索框
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '搜索用户名...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 16),
        // 搜索结果
        Expanded(
          child: _buildSearchResults(theme),
        ),
      ],
    );
  }

  Widget _buildSearchResults(ThemeData theme) {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '输入用户名搜索好友',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的用户',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? NetworkImage(user.avatarUrl!)
                : null,
            child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                  )
                : null,
          ),
          title: Text(user.displayName),
          subtitle: Text('@${user.username}'),
          trailing: _isCreating
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chat_bubble_outline),
          onTap: () => _createDirectChat(user),
        );
      },
    );
  }
}

class _RoomSearchDelegate extends SearchDelegate<Room?> {
  @override
  String get searchFieldLabel => '搜索会话';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('输入关键词搜索'));
    }
    
    return Center(
      child: Text('搜索 "$query" 的结果'),
    );
  }
}

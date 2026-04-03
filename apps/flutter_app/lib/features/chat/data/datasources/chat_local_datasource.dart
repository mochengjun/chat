import 'dart:convert';
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/message.dart';
import '../models/room_model.dart';
import '../models/message_model.dart';

abstract class ChatLocalDataSource {
  Future<void> init();
  Future<List<Room>> getCachedRooms();
  Future<void> cacheRooms(List<Room> rooms);
  Future<List<Message>> getCachedMessages(String roomId, {int limit = 50});
  Future<void> cacheMessages(List<Message> messages);
  Future<void> cacheMessage(Message message);
  Future<void> updateMessageStatus(String messageId, String status);
  Future<void> deleteMessage(String messageId);
  Future<void> clearRoomMessages(String roomId);
  Future<void> clearAll();
}

class ChatLocalDataSourceImpl implements ChatLocalDataSource {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    await init();
    if (_database == null) {
      throw StateError('Failed to initialize database');
    }
    return _database!;
  }

  @override
  Future<void> init() async {
    try {
      // Windows/Linux/macOS 需要初始化 FFI
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      
      // 获取数据库路径
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'chat_cache.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE rooms (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            avatar_url TEXT,
            type TEXT NOT NULL,
            unread_count INTEGER DEFAULT 0,
            creator_id TEXT,
            is_muted INTEGER DEFAULT 0,
            is_pinned INTEGER DEFAULT 0,
            retention_hours INTEGER,
            created_at TEXT NOT NULL,
              updated_at TEXT,
              last_message_json TEXT,
              cached_at TEXT NOT NULL
            )
          ''');

          await db.execute('''
            CREATE TABLE messages (
              id TEXT PRIMARY KEY,
              room_id TEXT NOT NULL,
              sender_id TEXT NOT NULL,
              sender_name TEXT NOT NULL,
              sender_avatar TEXT,
              content TEXT NOT NULL,
              type TEXT NOT NULL,
              status TEXT NOT NULL,
              media_url TEXT,
              thumbnail_url TEXT,
              media_size INTEGER,
              mime_type TEXT,
              metadata_json TEXT,
              created_at TEXT NOT NULL,
              edited_at TEXT,
              is_deleted INTEGER DEFAULT 0,
              cached_at TEXT NOT NULL
            )
          ''');

          await db.execute(
            'CREATE INDEX idx_messages_room_id ON messages(room_id)'
          );
          await db.execute(
            'CREATE INDEX idx_messages_created_at ON messages(created_at)'
          );
        },
      );
    } catch (e) {
      _database = null;
      rethrow;
    }
  }

  @override
  Future<List<Room>> getCachedRooms() async {
    final db = await database;
    final result = await db.query('rooms', orderBy: 'updated_at DESC');
    
    return result.map((row) {
      final lastMessageJson = row['last_message_json'] as String?;
      Map<String, dynamic>? lastMessage;
      if (lastMessageJson != null && lastMessageJson.isNotEmpty) {
        try {
          lastMessage = jsonDecode(lastMessageJson) as Map<String, dynamic>;
        } catch (_) {
          lastMessage = null;
        }
      }
      
      return RoomModel.fromJson({
        'id': row['id'],
        'name': row['name'],
        'description': row['description'],
        'avatar_url': row['avatar_url'],
        'type': row['type'],
        'unread_count': row['unread_count'],
        'creator_id': row['creator_id'],
        'is_muted': row['is_muted'] == 1,
        'is_pinned': row['is_pinned'] == 1,
        'retention_hours': row['retention_hours'],
        'created_at': row['created_at'],
        'updated_at': row['updated_at'],
        'last_message': lastMessage,
      }).toEntity();
    }).toList();
  }

  @override
  Future<void> cacheRooms(List<Room> rooms) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final room in rooms) {
        final lastMessageJson = room.lastMessage != null 
            ? jsonEncode(MessageModel.fromJson({
                'id': room.lastMessage!.id,
                'room_id': room.lastMessage!.roomId,
                'sender_id': room.lastMessage!.senderId,
                'sender_name': room.lastMessage!.senderName,
                'content': room.lastMessage!.content,
                'type': room.lastMessage!.type.name,
                'status': room.lastMessage!.status.name,
                'created_at': room.lastMessage!.createdAt.toIso8601String(),
              }).toJson())
            : null;
        
        batch.insert(
          'rooms',
          {
            'id': room.id,
            'name': room.name,
            'description': room.description,
            'avatar_url': room.avatarUrl,
            'type': room.type.name,
            'unread_count': room.unreadCount,
            'creator_id': room.creatorId,
            'is_muted': room.isMuted ? 1 : 0,
            'is_pinned': room.isPinned ? 1 : 0,
            'retention_hours': room.retentionHours,
            'created_at': room.createdAt.toIso8601String(),
            'updated_at': room.updatedAt?.toIso8601String(),
            'last_message_json': lastMessageJson,
            'cached_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<Message>> getCachedMessages(String roomId, {int limit = 50}) async {
    final db = await database;
    final result = await db.query(
      'messages',
      where: 'room_id = ? AND is_deleted = 0',
      whereArgs: [roomId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    
    return result.map((row) {
      final metadataJson = row['metadata_json'] as String?;
      Map<String, dynamic>? metadata;
      if (metadataJson != null && metadataJson.isNotEmpty) {
        try {
          metadata = jsonDecode(metadataJson) as Map<String, dynamic>;
        } catch (_) {
          metadata = null;
        }
      }
      
      return MessageModel.fromJson({
        'id': row['id'],
        'room_id': row['room_id'],
        'sender_id': row['sender_id'],
        'sender_name': row['sender_name'],
        'sender_avatar': row['sender_avatar'],
        'content': row['content'],
        'type': row['type'],
        'status': row['status'],
        'media_url': row['media_url'],
        'thumbnail_url': row['thumbnail_url'],
        'media_size': row['media_size'],
        'mime_type': row['mime_type'],
        'metadata': metadata,
        'created_at': row['created_at'],
        'edited_at': row['edited_at'],
        'is_deleted': row['is_deleted'] == 1,
      }).toEntity();
    }).toList().reversed.toList();
  }

  @override
  Future<void> cacheMessages(List<Message> messages) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      
      for (final message in messages) {
        batch.insert(
          'messages',
          _messageToRow(message),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> cacheMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      _messageToRow(message),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': status},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.update(
      'messages',
      {'is_deleted': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  @override
  Future<void> clearRoomMessages(String roomId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
    );
  }

  @override
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('messages');
    await db.delete('rooms');
  }

  Map<String, dynamic> _messageToRow(Message message) {
    return {
      'id': message.id,
      'room_id': message.roomId,
      'sender_id': message.senderId,
      'sender_name': message.senderName,
      'sender_avatar': message.senderAvatar,
      'content': message.content,
      'type': message.type.name,
      'status': message.status.name,
      'media_url': message.mediaUrl,
      'thumbnail_url': message.thumbnailUrl,
      'media_size': message.mediaSize,
      'mime_type': message.mimeType,
      'metadata_json': message.metadata != null ? jsonEncode(message.metadata!) : null,
      'created_at': message.createdAt.toIso8601String(),
      'edited_at': message.editedAt?.toIso8601String(),
      'is_deleted': message.isDeleted ? 1 : 0,
      'cached_at': DateTime.now().toIso8601String(),
    };
  }
}

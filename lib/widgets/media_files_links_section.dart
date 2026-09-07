import 'package:flutter/material.dart';
import '../models/message.dart';
import '../services/direct/direct_service.dart';
import '../services/group/group_service.dart';
import '../screens/chat/image_viewer_screen.dart';

const _fontFamily = 'PlusJakartaSans';

class MediaFilesLinksSection extends StatefulWidget {
  final String? chatId;
  final String? groupId;

  const MediaFilesLinksSection({
    super.key,
    this.chatId,
    this.groupId,
  }) : assert(chatId != null || groupId != null);

  @override
  State<MediaFilesLinksSection> createState() => _MediaFilesLinksSectionState();
}

class _MediaFilesLinksSectionState extends State<MediaFilesLinksSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    List<ChatMessage> messages;
    if (widget.chatId != null) {
      messages = await DirectService().getMessagesOnce(widget.chatId!);
    } else {
      messages = await GroupService().getMessagesOnce(widget.groupId!);
    }
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    }
  }

  List<String> get _imageUrls => _messages
      .where((m) => m.type == MessageType.image && m.imageUrl != null)
      .map((m) => m.imageUrl!)
      .toList();

  List<_FileItem> get _files {
    final items = <_FileItem>[];
    for (final m in _messages) {
      if (m.type == MessageType.audio && m.audioUrl != null) {
        items.add(_FileItem(
          name: 'Voice message',
          url: m.audioUrl!,
          icon: Icons.mic,
          subtitle: m.durationSeconds != null
              ? '${(m.durationSeconds! ~/ 60).toString().padLeft(2, '0')}:${(m.durationSeconds! % 60).toString().padLeft(2, '0')}'
              : '',
        ));
      }
      if (m.type == MessageType.image && m.imageUrl != null) {
        items.add(_FileItem(
          name: 'Photo',
          url: m.imageUrl!,
          icon: Icons.photo,
          subtitle: 'Image',
        ));
      }
    }
    return items;
  }

  List<_LinkItem> get _links {
    final urlRegex = RegExp(r'https?://[^\s]+');
    final items = <_LinkItem>[];
    final seen = <String>{};
    for (final m in _messages) {
      if (m.type == MessageType.text) {
        final matches = urlRegex.allMatches(m.content);
        for (final match in matches) {
          final url = match.group(0)!;
          if (seen.add(url)) {
            items.add(_LinkItem(url: url, senderName: m.senderName));
          }
        }
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFFFE4EF0), strokeWidth: 2),
        ),
      );
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFE4EF0).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: const Color(0xFFFE4EF0),
            unselectedLabelColor: Colors.white.withValues(alpha: 0.5),
            labelStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Media'),
              Tab(text: 'Files'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMediaTab(),
              _buildFilesTab(),
              _buildLinksTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaTab() {
    if (_imageUrls.isEmpty) {
      return _buildEmptyState(Icons.image_outlined, 'No media shared yet');
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _imageUrls.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(imageUrl: _imageUrls[index]),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              _imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilesTab() {
    final files = _files;
    if (files.isEmpty) {
      return _buildEmptyState(Icons.insert_drive_file_outlined, 'No files shared yet');
    }
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFE4EF0).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(file.icon, color: const Color(0xFFFE4EF0), size: 20),
          ),
          title: Text(
            file.name,
            style: const TextStyle(
              fontFamily: _fontFamily,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          subtitle: Text(
            file.subtitle,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLinksTab() {
    final links = _links;
    if (links.isEmpty) {
      return _buildEmptyState(Icons.link, 'No links shared yet');
    }
    return ListView.builder(
      itemCount: links.length,
      itemBuilder: (context, index) {
        final link = links[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF800DD8).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.link, color: Color(0xFF800DD8), size: 20),
          ),
          title: Text(
            link.url,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: _fontFamily,
              color: Color(0xFF4ECDC4),
              fontSize: 13,
            ),
          ),
          subtitle: Text(
            link.senderName,
            style: TextStyle(
              fontFamily: _fontFamily,
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontFamily: _fontFamily,
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileItem {
  final String name;
  final String url;
  final IconData icon;
  final String subtitle;

  const _FileItem({
    required this.name,
    required this.url,
    required this.icon,
    required this.subtitle,
  });
}

class _LinkItem {
  final String url;
  final String senderName;

  const _LinkItem({required this.url, required this.senderName});
}

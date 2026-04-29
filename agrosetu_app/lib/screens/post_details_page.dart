import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import 'package:intl/intl.dart';

class PostDetailsPage extends StatefulWidget {
  final String postId;

  const PostDetailsPage({super.key, required this.postId});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  Map<String, dynamic>? _post;
  bool _isLoading = true;
  String? _currentUserId;
  Map<String, dynamic>? _currentUser;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  /// Safe base64 decode for post images. Returns null when the value is
  /// missing, empty, or not valid base64 — keeps a corrupt image from
  /// crashing the entire post page.
  Uint8List? _safeDecodeBase64(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString();
    if (str.isEmpty) return null;
    try {
      final cleaned = str.startsWith('data:')
          ? str.substring(str.indexOf(',') + 1)
          : str;
      return base64Decode(cleaned);
    } catch (e) {
      debugPrint('[PostDetails] base64 decode failed: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCurrentUser(),
      _fetchPostDetails(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadCurrentUser() async {
    final user = await UserService.getUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentUser = user;
          _currentUserId = user['id'];
        });
      }
    }
  }

  Future<void> _fetchPostDetails() async {
    try {
      final response = await ApiService.getPostById(widget.postId);
      if (response['status'] == 'ok') {
        if (mounted) {
          setState(() {
            _post = response['post'];
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Failed to load post')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error fetching post: $e');
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return 'Recently';
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('MMM d, h:mm a').format(dt);
    } catch (e) {
      return timestamp;
    }
  }

  Future<void> _handleLike() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to like posts')),
      );
      return;
    }

    try {
      final response = await ApiService.likePost(
        postId: widget.postId,
        userId: _currentUserId!,
        userName: _currentUser?['name'] ?? 'Someone',
      );
      if (response['status'] == 'ok') {
        _fetchPostDetails(); // Refresh to update like count
      }
    } catch (e) {
      debugPrint('Like error: $e');
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to comment')),
      );
      return;
    }

    setState(() => _isSubmittingComment = true);
    try {
      final response = await ApiService.addComment(
        postId: widget.postId,
        userId: _currentUser!['id'],
        userName: _currentUser!['name'],
        userEmail: _currentUser!['email'],
        text: _commentController.text.trim(),
      );

      if (response['status'] == 'ok') {
        _commentController.clear();
        if (mounted) FocusScope.of(context).unfocus();
        await _fetchPostDetails(); // Refresh comments
      }
    } catch (e) {
      debugPrint('Comment error: $e');
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Color(0xFF2E7D32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Post Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _post == null
              ? _buildErrorState()
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAuthorSection(),
                            const SizedBox(height: 20),
                            _buildContentSection(),
                            const SizedBox(height: 24),
                            const Divider(height: 1),
                            const SizedBox(height: 20),
                            _buildCommentsHeader(),
                            const SizedBox(height: 16),
                            _buildCommentsList(),
                          ],
                        ),
                      ),
                    ),
                    _buildCommentInput(),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.info_circle, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Post not found',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
            child: const Text('Go Back', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorSection() {
    final authorName = _post!['author']?['name'] ?? 'Anonymous';
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              authorName[0].toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E7D32),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                authorName,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                _formatTime(_post!['createdAt']),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _post!['category'] ?? 'General',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _post!['title'] ?? 'No Title',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1B5E20),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _post!['description'] ?? '',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.black87,
            height: 1.6,
          ),
        ),
        if (_safeDecodeBase64(_post!['imageUrl']) != null) ...[
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _safeDecodeBase64(_post!['imageUrl'])!,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            _buildStatItem(
              icon: Iconsax.heart,
              count: _post!['likes'] ?? 0,
              color: Colors.red.shade400,
              onTap: _handleLike,
            ),
            const SizedBox(width: 20),
            _buildStatItem(
              icon: Iconsax.message,
              count: _post!['comments'] ?? 0,
              color: Colors.blue.shade400,
            ),
            const Spacer(),
            if (_post!['solved'] == true)
              Row(
                children: [
                  const Icon(Iconsax.verify, size: 18, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(
                    'Solved',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required int count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsHeader() {
    return Row(
      children: [
        Text(
          'Comments',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            (_post!['comments'] ?? 0).toString(),
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    final comments = _post!['commentList'] as List? ?? [];
    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'No comments yet. Start the conversation!',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final comment = comments[index];
        final name = comment['userName'] ?? 'User';
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(fontSize: 14, color: Color(0xFF2E7D32), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(comment['createdAt']),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment['text'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Write a comment...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 14),
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSubmittingComment ? null : _submitComment,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: _isSubmittingComment
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Iconsax.send_1, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

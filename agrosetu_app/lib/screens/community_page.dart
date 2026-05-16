import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_translations.dart';
import '../services/api_service.dart';
import '../services/user_service.dart';
import 'post_details_page.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

String _localizedCategory(String key) {
  switch (key) {
    case 'All':
      return 'community.cat_all'.tr;
    case 'Rice':
      return 'community.cat_rice'.tr;
    case 'Wheat':
      return 'community.cat_wheat'.tr;
    case 'Corn':
      return 'community.cat_corn'.tr;
    case 'Market':
      return 'community.cat_market'.tr;
    case 'General':
      return 'community.cat_general'.tr;
    default:
      return key;
  }
}

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  static const _kPostsCachePrefix = 'community_posts_cache_';

  int _selectedTab = 0;
  List<Map<String, dynamic>> _discussions = [];
  bool _isLoading = true;
  bool _showingCachedFallback = false;
  String? _currentUserId;
  Map<String, dynamic>? _currentUser;

  // Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchLoading = false;

  final List<String> _categories = const ['All', 'Rice', 'Wheat', 'Corn', 'Market', 'General'];

  @override
  void initState() {
    super.initState();
    _loadUserAndPosts();
  }

  Future<void> _loadUserAndPosts() async {
    try {
      // Get current user
      final user = await UserService.getUser();
      if (user != null) {
        setState(() => _currentUser = user);
        _currentUserId = user['id'];
      }
      
      // Load posts
      await _fetchPosts();
    } catch (e) {
      debugPrint('Error loading user: $e');
      _fetchPosts();
    }
  }

  Future<void> _fetchPosts() async {
    try {
      setState(() => _isLoading = true);

      final category = _selectedTab == 0 ? 'All' : _categories[_selectedTab];

      // Show cached posts immediately (so the UI is never blank when offline).
      final cached = await _loadCachedPosts(category);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _discussions = cached;
          _showingCachedFallback = true;
          _isLoading = false;
        });
      }

      final response = await ApiService.getPosts(category);

      if (!mounted) return;
      if (response['status'] == 'ok') {
        final fresh = List<Map<String, dynamic>>.from(response['posts'] ?? []);
        await _savePostsToCache(category, fresh);
        setState(() {
          _discussions = fresh;
          _showingCachedFallback = false;
          _isLoading = false;
        });
      } else if (cached.isEmpty) {
        // Network failed and we have nothing to show.
        setState(() => _isLoading = false);
        _showOfflineToast();
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (_discussions.isEmpty) _showOfflineToast();
    }
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.orange.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Iconsax.wifi_square, size: 14, color: Colors.orange.shade800),
          const SizedBox(width: 6),
          Text(
            'community.cached_offline'.tr,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.orange.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('community.offline_toast'.tr),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCachedPosts(String category) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kPostsCachePrefix$category');
      if (raw == null) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _savePostsToCache(
      String category, List<Map<String, dynamic>> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Strip image data from cache to keep it lightweight.
      final lightweight = posts.map((p) {
        final copy = Map<String, dynamic>.from(p);
        copy.remove('image_data');
        if (copy['imageUrl'] is String &&
            (copy['imageUrl'] as String).length > 1024) {
          copy['imageUrl'] = '';
        }
        return copy;
      }).toList();
      await prefs.setString(
          '$_kPostsCachePrefix$category', jsonEncode(lightweight));
    } catch (e) {
      debugPrint('[Community] cache write skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryTabs(),
            if (_showingCachedFallback) _buildOfflineBanner(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _discussions.isEmpty
                      ? _buildEmptyState()
                      : _buildDiscussionsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentUser == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('community.login_to_post'.tr),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
          _showNewPostDialog();
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(Iconsax.add, color: Colors.white),
      ),
    );
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearchLoading = false;
      });
      return;
    }

    setState(() => _isSearchLoading = true);
    
    try {
      final response = await ApiService.searchUsers(query);
      if (response['status'] == 'ok') {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response['users']);
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _isSearchLoading = false);
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7D32),
            Color(0xFF1B5E20),
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (!_isSearching) ...[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Iconsax.message, size: 24, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'community.title'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'community.subtitle'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _performSearch,
                    autofocus: true,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'community.search_hint'.tr,
                      hintStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () {
                          setState(() {
                            _isSearching = false;
                            _searchController.clear();
                            _searchResults = [];
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
              if (!_isSearching)
                IconButton(
                  onPressed: () => setState(() => _isSearching = true),
                  icon: const Icon(Iconsax.search_normal, color: Colors.white),
                ),
            ],
          ),
          if (_isSearching && (_isSearchLoading || _searchResults.isNotEmpty))
            Container(
              margin: const EdgeInsets.only(top: 12),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: _isSearchLoading
                  ? const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Text(user['name'][0].toUpperCase(), style: const TextStyle(color: Colors.green)),
                          ),
                          title: Text(user['name'], style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: Text(user['email'], style: GoogleFonts.poppins(fontSize: 12)),
                          onTap: () {
                            // Can add "View Profile" logic here later
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${'community.profile_view_soon_prefix'.tr}${user['name']}${'community.profile_view_soon_suffix'.tr}')),
                            );
                            setState(() {
                              _isSearching = false;
                              _searchController.clear();
                              _searchResults = [];
                            });
                          },
                        );
                      },
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_categories.length, (index) {
            final category = _categories[index];
            final isSelected = _selectedTab == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_localizedCategory(category)),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _selectedTab = index);
                  _fetchPosts();
                },
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected 
                    ? const Color(0xFF2E7D32) 
                    : Colors.grey.shade700,
                ),
                side: BorderSide(
                  color: isSelected
                    ? const Color(0xFF2E7D32)
                    : Colors.grey.shade300,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Iconsax.message,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'community.no_posts'.tr,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'community.first_post'.tr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscussionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _discussions.length,
      itemBuilder: (context, index) {
        final discussion = _discussions[index];
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailsPage(postId: discussion['id']),
              ),
            ).then((_) => _fetchPosts()); // Refresh when coming back
          },
          borderRadius: BorderRadius.circular(16),
          child: _DiscussionCard(
            discussion: discussion,
            onRefresh: _fetchPosts,
            currentUserId: _currentUserId,
            currentUserName: _currentUser?['name'],
          ),
        );
      },
    );
  }

  void _showNewPostDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedCategory = _categories[_selectedTab == 0 ? 1 : _selectedTab];
    Uint8List? dialogImageBytes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'community.start_discussion'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1B5E20),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: 'community.title_hint'.tr,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      hintText: 'community.desc_hint'.tr,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  // Category Dropdown
                  Row(
                    children: [
                      const Icon(Iconsax.category, size: 18, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Text('community.category_label'.tr, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCategory,
                          underline: const SizedBox(),
                          items: _categories.skip(1).map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(_localizedCategory(cat), style: GoogleFonts.poppins(fontSize: 14)));
                          }).toList(),
                          onChanged: (value) => setDialogState(() => selectedCategory = value ?? 'General'),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Image Picker and Preview
                  if (dialogImageBytes != null)
                    Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          height: 180,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: MemoryImage(dialogImageBytes!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 20,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setDialogState(() => dialogImageBytes = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.close, size: 16, color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            // image_picker.pickImage(source: gallery) is mobile-only;
                            // on macOS / Windows / Linux / web it no-ops. Route those
                            // platforms through file_picker instead.
                            final bool isDesktopOrWeb = kIsWeb ||
                                defaultTargetPlatform == TargetPlatform.macOS ||
                                defaultTargetPlatform == TargetPlatform.windows ||
                                defaultTargetPlatform == TargetPlatform.linux;
                            Uint8List bytes;
                            if (isDesktopOrWeb) {
                              final result = await FilePicker.pickFiles(
                                type: FileType.image,
                                allowMultiple: false,
                                withData: true,
                              );
                              if (result == null || result.files.isEmpty) return;
                              final picked = result.files.first.bytes;
                              if (picked == null) return;
                              bytes = picked;
                            } else {
                              final picker = ImagePicker();
                              final image = await picker.pickImage(
                                  source: ImageSource.gallery, imageQuality: 70);
                              if (image == null) return;
                              bytes = await image.readAsBytes();
                            }
                            setDialogState(() => dialogImageBytes = bytes);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green.shade700,
                            side: BorderSide(color: Colors.green.shade300),
                            backgroundColor: Colors.green.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Iconsax.image, size: 20),
                          label: Text(
                            (dialogImageBytes == null ? 'community.add_photo'.tr : 'community.change_photo'.tr) + ' (${'community.optional'.tr})',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty || descriptionController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('community.fill_all'.tr), backgroundColor: Colors.orange),
                          );
                          return;
                        }

                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final response = await ApiService.createPost(
                            title: titleController.text,
                            description: descriptionController.text,
                            category: selectedCategory,
                            author: {
                              'id': _currentUser?['id'],
                              'name': _currentUser?['name'],
                              'email': _currentUser?['email'],
                            },
                            imageData: dialogImageBytes != null ? base64Encode(dialogImageBytes!) : null,
                          );

                          if (response['status'] == 'ok') {
                            navigator.pop();
                            await _fetchPosts();
                            messenger.showSnackBar(
                              SnackBar(content: Text('community.created_ok'.tr), backgroundColor: Colors.green),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(content: Text(response['message'] ?? 'community.failed'.tr), backgroundColor: Colors.red),
                            );
                          }
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('${'community.error_prefix'.tr}$e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text('community.post_button'.tr, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscussionCard extends StatefulWidget {
  final Map<String, dynamic> discussion;
  final VoidCallback onRefresh;
  final String? currentUserId;
  final String? currentUserName;

  const _DiscussionCard({
    required this.discussion,
    required this.onRefresh,
    this.currentUserId,
    this.currentUserName,
  });

  @override
  State<_DiscussionCard> createState() => _DiscussionCardState();
}

class _DiscussionCardState extends State<_DiscussionCard> {
  bool _isLiked = false;

  /// Safely decodes a base64 image string. Returns null when the value is
  /// missing, empty, or not valid base64 — so a corrupt post can never crash
  /// the entire feed.
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
      debugPrint('[Community] base64 decode failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    (widget.discussion['author']?['name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.discussion['author']?['name'] ?? 'community.anonymous'.tr,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1B5E20),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _localizedCategory(widget.discussion['category'] ?? 'General'),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      widget.discussion['timestamp'] ?? 'community.just_now'.tr,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.discussion['solved'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.verify,
                        size: 12,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'community.solved'.tr,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Title
          Text(
            widget.discussion['title'] ?? 'community.no_title'.tr,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Description
          Text(
            widget.discussion['description'] ?? 'community.no_description'.tr,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Image Preview (if exists)
          if (widget.discussion['imageUrl'] != null && widget.discussion['imageUrl'].toString().isNotEmpty)
            Builder(
              builder: (context) {
                final imageData = _safeDecodeBase64(widget.discussion['imageUrl']);
                if (imageData == null) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: MemoryImage(imageData),
                      fit: BoxFit.cover,
                      onError: (e, stack) {
                        debugPrint('[Community] Image error: $e');
                      },
                    ),
                  ),
                );
              }
            ),
          
          // Stats
          Row(
            children: [
              Row(
                children: [
                  Icon(
                    Iconsax.message,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.discussion['comments'] ?? 0}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  if (widget.currentUserId == null) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('community.login_to_like'.tr),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  
                  // Optimistic UI: flip locally first, then attempt server sync.
                  // Roll back if the server call fails so the heart never lies
                  // about persistence.
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isLiked = !_isLiked);

                  final result = await ApiService.likePost(
                    postId: widget.discussion['id'],
                    userId: widget.currentUserId!,
                    userName: widget.currentUserName ?? 'Someone',
                  );
                  if (!mounted) return;
                  if (result['status'] != 'ok') {
                    setState(() => _isLiked = !_isLiked);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(result['message']?.toString() ??
                            'community.like_failed'.tr),
                        backgroundColor: Colors.red.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      Iconsax.heart,
                      size: 14,
                      color: _isLiked ? Colors.red.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.discussion['likes'] ?? 0}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

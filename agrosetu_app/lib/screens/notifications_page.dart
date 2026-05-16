import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../l10n/app_translations.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';
import 'post_details_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifs = await NotificationService.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = notifs;
      _isLoading = false;
    });
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'notif.now'.tr;
      if (diff.inMinutes < 60) return '${diff.inMinutes}${'notif.minute_ago'.tr}';
      if (diff.inHours < 24) return '${diff.inHours}${'notif.hour_ago'.tr}';
      if (diff.inDays < 7) return '${diff.inDays}${'notif.day_ago'.tr}';

      return DateFormat.yMMMd(AppTranslations.currentLocale.value).format(dt);
    } catch (e) {
      return 'notif.unknown'.tr;
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'detection':
        return Iconsax.camera;
      case 'market':
        return Iconsax.chart;
      case 'weather':
        return Iconsax.cloud;
      case 'activity':
        return Iconsax.activity;
      case 'like':
        return Iconsax.heart;
      case 'comment':
        return Iconsax.message_text;
      default:
        return Iconsax.notification;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type) {
      case 'detection':
        return Colors.purple;
      case 'market':
        return Colors.orange;
      case 'weather':
        return Colors.blue;
      case 'activity':
        return Colors.green;
      case 'like':
        return Colors.red;
      case 'comment':
        return Colors.blueAccent;
      default:
        return Colors.grey;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await NotificationService.markAsRead(notificationId);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Color(0xFF2E7D32)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'notif.title'.tr,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh, color: Color(0xFF2E7D32), size: 20),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadNotifications();
            },
          ),
          if (_notifications.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('notif.clear_all_title'.tr),
                    content: Text('notif.clear_undone'.tr),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('common.cancel'.tr),
                      ),
                      TextButton(
                        onPressed: () {
                          NotificationService.clearAll();
                          Navigator.pop(context);
                          _loadNotifications();
                        },
                        child: Text(
                          'notif.clear'.tr,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Iconsax.trash, size: 18),
              label: Text(
                'notif.clear'.tr,
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: const Color(0xFF2E7D32),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.7,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Iconsax.notification_bing,
                            size: 64,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'notif.empty'.tr,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final isRead = notif['read'] == true;
                      final String? type = notif['type'];
                      final String senderName = notif['senderName'] ?? 'notif.someone'.tr;
                      final String? postTitle = notif['postTitle'];

                      String dynamicTitle = notif['title'] ?? 'notif.notification'.tr;
                      if (type == 'like') {
                        dynamicTitle = '$senderName${'notif.liked_your_post'.tr}';
                      } else if (type == 'comment') {
                        dynamicTitle = '$senderName${'notif.commented_post'.tr}';
                      }

                      return InkWell(
                        onTap: () {
                          if (notif['id'] != null) _markAsRead(notif['id']);
                          if (notif['postId'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailsPage(postId: notif['postId']),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : const Color(0xFFF1F8E9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRead
                                  ? Colors.grey.shade200
                                  : const Color(0xFF2E7D32).withValues(alpha: 0.1),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _getNotificationColor(type).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    _getNotificationIcon(type),
                                    color: _getNotificationColor(type),
                                    size: 24,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dynamicTitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (postTitle != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '"$postTitle"',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                          color: const Color(0xFF2E7D32),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatTime(notif['timestamp'] ?? ''),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../services/notification_service.dart';
import 'package:intl/intl.dart';

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

      if (diff.inMinutes < 1) return 'Now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return DateFormat('MMM d, yyyy').format(dt);
    } catch (e) {
      return 'Unknown';
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
      case 'like': // ADDED
        return Iconsax.heart;
      case 'comment': // ADDED
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
      case 'like': // ADDED
        return Colors.red;
      case 'comment': // ADDED
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
          'Notifications',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
        actions: [
          // ADDED: Refresh Button to manually trigger sync
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
                    title: const Text('Clear all notifications?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          NotificationService.clearAll();
                          Navigator.pop(context);
                          _loadNotifications();
                        },
                        child: const Text(
                          'Clear',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Iconsax.trash, size: 18),
              label: Text(
                'Clear',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            ),
        ],
      ),
      body: RefreshIndicator( // ADDED: Pull to refresh
        onRefresh: _loadNotifications,
        color: const Color(0xFF2E7D32),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _notifications.isEmpty
                ? SingleChildScrollView( // Changed to scrollable for RefreshIndicator
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
                            'No notifications yet',
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

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isRead
                                ? Colors.transparent
                                : const Color(0xFF2E7D32).withValues(alpha: 0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getNotificationColor(notif['type'])
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getNotificationIcon(notif['type']),
                              color:
                                  _getNotificationColor(notif['type']),
                              size: 24,
                            ),
                          ),
                          title: Text(
                            notif['title'] ?? 'Notification',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                notif['body'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
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
                          trailing: isRead
                              ? null
                              : GestureDetector(
                                  onTap: () => _markAsRead(notif['id']),
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
} 
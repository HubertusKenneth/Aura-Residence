import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class NotificationsPage extends StatefulWidget {
  final int initialIndex;

  const NotificationsPage({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final GlobalKey<_NotificationsTabState> _notificationsTabKey = GlobalKey<_NotificationsTabState>();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialIndex,
      child: Scaffold(
        backgroundColor: const Color(0xffF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: const Text("Activity Center", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
          centerTitle: false,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black87),
              onSelected: (value) {
                if (value == "Mark All Read") {
                  _notificationsTabKey.currentState?._markAllAsRead();
                } else if (value == "Clear Old") {
                  _notificationsTabKey.currentState?._clearOldNotifications();
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  const PopupMenuItem(value: "Mark All Read", child: Text("Mark all as read")),
                  const PopupMenuItem(value: "Clear Old", child: Text("Clear old notifications")),
                ];
              },
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Color(0xffF9A826),
            indicatorWeight: 3,
            labelColor: Color(0xffF9A826),
            unselectedLabelColor: Colors.black54,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: "Notifications"),
              Tab(text: "Announcements"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _NotificationsTab(key: _notificationsTabKey),
            const _AnnouncementsTab(),
          ],
        ),
      ),
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  const _NotificationsTab({Key? key}) : super(key: key);
  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  String selectedTab = "All";

  final List<String> filterTabs = ["All", "Maintenance", "Payments", "Applications", "Contracts", "System"];

  Future<void> _markAllAsRead() async {
    try {
      var querySnapshot = await FirebaseFirestore.instance
          .collection("Users")
          .doc(currentUid)
          .collection("Notifications")
          .where('isRead', isEqualTo: false)
          .get();

      if (querySnapshot.docs.isEmpty) {
        Fluttertoast.showToast(msg: "All notifications are already read");
        return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      Fluttertoast.showToast(msg: "All notifications marked as read", backgroundColor: Colors.green);
    } catch (e) {
      debugPrint("Error marking all as read: $e");
      Fluttertoast.showToast(msg: "Failed to mark as read", backgroundColor: Colors.red);
    }
  }

  Future<void> _clearOldNotifications() async {
    try {
      DateTime thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      var querySnapshot = await FirebaseFirestore.instance
          .collection("Users")
          .doc(currentUid)
          .collection("Notifications")
          .where('timestamp', isLessThan: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      if (querySnapshot.docs.isEmpty) {
        Fluttertoast.showToast(msg: "No old notifications to clear");
        return;
      }

      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      Fluttertoast.showToast(msg: "Old notifications cleared successfully", backgroundColor: Colors.green);
    } catch (e) {
      debugPrint("Error clearing old notifications: $e");
      Fluttertoast.showToast(msg: "Failed to clear old notifications", backgroundColor: Colors.red);
    }
  }

  Future<void> _markAsRead(String notifId) async {
    try {
      await FirebaseFirestore.instance.collection("Users").doc(currentUid).collection("Notifications").doc(notifId).update({'isRead': true});
    } catch (e) {
      debugPrint("Error marking notif as read: $e");
    }
  }

  Future<void> _deleteNotification(String notifId) async {
    try {
      await FirebaseFirestore.instance.collection("Users").doc(currentUid).collection("Notifications").doc(notifId).delete();
      Fluttertoast.showToast(msg: "Notification archived");
    } catch (e) {
      debugPrint("Error archiving notif: $e");
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    Duration diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return "${diff.inDays} days ago";
    if (diff.inHours > 0) return "${diff.inHours} hours ago";
    if (diff.inMinutes > 0) return "${diff.inMinutes} mins ago";
    return "Just now";
  }

  String _getTimeGroup(DateTime dateTime) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime startOfWeek = today.subtract(Duration(days: now.weekday - 1));

    DateTime notifDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (notifDate == today) return "Today";
    if (notifDate == yesterday) return "Yesterday";
    if (notifDate.isAfter(startOfWeek) || notifDate.isAtSameMomentAs(startOfWeek)) return "This Week";
    return "Older";
  }

  Map<String, dynamic> _getNotificationStyle(String title, String body) {
    String text = "$title $body".toLowerCase();

    if (text.contains("maintenance") || text.contains("repair") || text.contains("technician") || text.contains("report")) {
      return {'type': 'Maintenance', 'icon': Icons.home_repair_service, 'iconBg': Colors.blue.shade50, 'iconColor': Colors.blue.shade700, 'buttonText': 'View Report'};
    }
    else if (text.contains("payment") || text.contains("bill") || text.contains("tagihan") || text.contains("rp") || text.contains("paid") || text.contains("overdue")) {
      return {'type': 'Payments', 'icon': Icons.account_balance_wallet, 'iconBg': Colors.amber.shade100, 'iconColor': Colors.amber.shade800, 'buttonText': 'View Payment'};
    }
    else if (text.contains("booking") || text.contains("facility") || text.contains("court") || text.contains("room")) {
      if (text.contains("decline") || text.contains("reject") || text.contains("cancel")) {
        return {'type': 'System', 'icon': Icons.event_busy, 'iconBg': Colors.red.shade50, 'iconColor': Colors.red.shade700, 'buttonText': 'View Booking'};
      }
      return {'type': 'System', 'icon': Icons.event_available, 'iconBg': Colors.green.shade50, 'iconColor': Colors.green.shade700, 'buttonText': 'View Booking'};
    }
    else if (text.contains("application") || text.contains("request") || text.contains("tenant") || text.contains("handover")) {
      if (text.contains("decline") || text.contains("reject")) {
        return {'type': 'Applications', 'icon': Icons.dangerous, 'iconBg': Colors.red.shade100, 'iconColor': Colors.red.shade700, 'buttonText': 'View Reason'};
      }
      return {'type': 'Applications', 'icon': Icons.person, 'iconBg': Colors.deepOrange.shade100, 'iconColor': Colors.deepOrange.shade700, 'buttonText': 'View Details'};
    }
    else if (text.contains("contract") || text.contains("lease") || text.contains("extension")) {
      return {'type': 'Contracts', 'icon': Icons.description, 'iconBg': Colors.blue.shade100, 'iconColor': Colors.blue.shade700, 'buttonText': 'View Contract'};
    }
    else if (text.contains("approve") || text.contains("success") || text.contains("verified")) {
      return {'type': 'System', 'icon': Icons.check_circle, 'iconBg': Colors.green.shade100, 'iconColor': Colors.green.shade700, 'buttonText': 'View Details'};
    } else {
      return {'type': 'System', 'icon': Icons.info, 'iconBg': Colors.grey.shade200, 'iconColor': Colors.grey.shade700, 'buttonText': 'View Details'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: filterTabs.map((tab) {
                bool isSelected = selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => selectedTab = tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xffF9A826) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("Users").doc(currentUid).collection("Notifications").orderBy("timestamp", descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xffF9A826)));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

              List<DocumentSnapshot> validDocs = [];
              DateTime now = DateTime.now();

              for (var doc in snapshot.data!.docs) {
                var data = doc.data() as Map<String, dynamic>;
                Timestamp? ts = data['timestamp'] as Timestamp?;

                var style = _getNotificationStyle(data['title'] ?? "", data['body'] ?? "");
                if (selectedTab == "All" || selectedTab == style['type']) validDocs.add(doc);
              }

              if (validDocs.isEmpty) return _buildEmptyState();

              Map<String, List<DocumentSnapshot>> groupedNotifs = {"Today": [], "Yesterday": [], "This Week": [], "Older": []};

              for (var doc in validDocs) {
                Timestamp? ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                groupedNotifs[ts != null ? _getTimeGroup(ts.toDate()) : "Today"]!.add(doc);
              }

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (groupedNotifs["Today"]!.isNotEmpty) _buildGroupSection("Today", groupedNotifs["Today"]!),
                  if (groupedNotifs["Yesterday"]!.isNotEmpty) _buildGroupSection("Yesterday", groupedNotifs["Yesterday"]!),
                  if (groupedNotifs["This Week"]!.isNotEmpty) _buildGroupSection("This Week", groupedNotifs["This Week"]!),
                  if (groupedNotifs["Older"]!.isNotEmpty) _buildGroupSection("Older", groupedNotifs["Older"]!),
                  const SizedBox(height: 30),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_rounded, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("No notifications yet", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 5),
          Text("You're all caught up!", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildGroupSection(String title, List<DocumentSnapshot> docs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 12, top: 10), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
        ...docs.map((doc) => _buildNotificationCard(doc)).toList(),
      ],
    );
  }

  Widget _buildNotificationCard(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    String id = doc.id;
    String title = data['title'] ?? "Notification";
    String body = data['body'] ?? "";
    bool isRead = data['isRead'] ?? false;
    Timestamp? ts = data['timestamp'] as Timestamp?;
    String timeAgo = ts != null ? _getTimeAgo(ts.toDate()) : "Just now";

    var style = _getNotificationStyle(title, body);

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.archive, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteNotification(id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isRead ? Colors.grey.shade200 : const Color(0xffF9A826).withOpacity(0.5), width: isRead ? 1 : 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () { if (!isRead) _markAsRead(id); },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: style['iconBg'], shape: BoxShape.circle), child: Icon(style['icon'], color: style['iconColor'], size: 22)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(title, style: TextStyle(fontWeight: isRead ? FontWeight.w600 : FontWeight.bold, fontSize: 15, color: Colors.black87))),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Text(timeAgo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                if (!isRead) ...[const SizedBox(width: 6), Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle))]
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(body, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(color: const Color(0xffF9A826).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(style['buttonText'], style: const TextStyle(color: Color(0xffF9A826), fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                        )
                      ],
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

class _AnnouncementsTab extends StatefulWidget {
  const _AnnouncementsTab({Key? key}) : super(key: key);
  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  Set<String> userTowers = {};
  bool isLoadingTowers = true;

  @override
  void initState() {
    super.initState();
    _fetchUserTowers();
  }

  Future<void> _fetchUserTowers() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var query = await FirebaseFirestore.instance.collection('RentalApplications').where('tenantUid', isEqualTo: uid).get();

      Set<String> towers = {};
      for (var doc in query.docs) {
        var data = doc.data();
        String status = data['status'] ?? '';
        if (status == 'Occupied' || status == 'Approved & Active' || status.contains('Extension')) {
          towers.add(data['tower']?.toString().trim() ?? '');
        }
      }
      setState(() { userTowers = towers; isLoadingTowers = false; });
    } catch (e) {
      setState(() => isLoadingTowers = false);
    }
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return "";
    DateTime dt = ts.toDate();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingTowers) return const Center(child: CircularProgressIndicator(color: Color(0xffF9A826)));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("Broadcasts").orderBy("timestamp", descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xffF9A826)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

        var filteredDocs = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String targetName = data['targetName'] ?? '';
          return targetName == 'All Towers' || targetName == 'Semua Tower' || userTowers.contains(targetName);
        }).toList();

        if (filteredDocs.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            var data = filteredDocs[index].data() as Map<String, dynamic>;

            String desc = data['content'] ?? "";
            String time = _formatDateTime(data['timestamp'] as Timestamp?);
            String category = data['category'] ?? "Information";
            String target = data['targetName'] ?? "All Towers";

            bool isUrgent = category == "Important" || category == "Penting";
            if(target == "Semua Tower") target = "All Towers";

            return _buildNewsCard(desc, time, isUrgent, target);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("No Announcements", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 5),
          Text("Updates from management will appear here.", style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNewsCard(String desc, String time, bool isUrgent, String target) {
    return Card(
      elevation: isUrgent ? 3 : 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isUrgent ? Colors.red.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(
              color: isUrgent ? Colors.red.shade200 : Colors.grey.shade200,
              width: isUrgent ? 1.5 : 1.0
          )
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade800, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.apartment, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(target, style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Text(time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 15),

            if (isUrgent)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 5),
                    Text('IMPORTANT ANNOUNCEMENT', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                  ],
                ),
              ),

            Text(
                desc,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isUrgent ? Colors.black87 : Colors.blueGrey.shade800
                )
            ),

            const SizedBox(height: 15),
            const Divider(height: 1),
            const SizedBox(height: 10),

            const Row(
              children: [
                Icon(Icons.admin_panel_settings, size: 14, color: Colors.blueGrey),
                SizedBox(width: 6),
                Text("Building Management", style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'maintenance_rating_page.dart';
import 'maintenance_chat_page.dart';

class MaintenanceDetailPage extends StatefulWidget {
  final String reportId;
  final bool isReadOnly;
  const MaintenanceDetailPage({Key? key, required this.reportId, this.isReadOnly = false}) : super(key: key);

  @override
  State<MaintenanceDetailPage> createState() => _MaintenanceDetailPageState();
}

class _MaintenanceDetailPageState extends State<MaintenanceDetailPage> {
  bool _isDescExpanded = false;
  bool _isTimelineExpanded = false;
  final Color _primaryColor = const Color(0xffF9A826);

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case "low": return Colors.green.shade500;
      case "medium": return Colors.amber.shade600;
      case "high": return Colors.red.shade600;
      case "emergency": return Colors.red.shade800;
      default: return Colors.grey.shade600;
    }
  }

  Map<String, dynamic> _getCategoryStyles(String category) {
    switch (category) {
      case "Air Conditioning": return {"icon": Icons.ac_unit, "color": Colors.blue.shade400};
      case "Electrical": return {"icon": Icons.electrical_services, "color": Colors.amber.shade600};
      case "Plumbing": return {"icon": Icons.water_drop, "color": Colors.cyan.shade600};
      case "Furniture": return {"icon": Icons.chair, "color": Colors.brown.shade500};
      case "Appliances": return {"icon": Icons.kitchen, "color": Colors.grey.shade600};
      default: return {"icon": Icons.more_horiz, "color": Colors.blueGrey.shade500};
    }
  }

  String formatCurrency(num amount) => "Rp ${NumberFormat.currency(locale: 'id', symbol: '', decimalDigits: 0).format(amount)}";

  void _showPaymentSheet(int amount, Map<String, dynamic> data) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Payment Method", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Total: ${formatCurrency(amount)}", style: TextStyle(fontSize: 16, color: _primaryColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _paymentOption(ctx, "Bank Transfer", Icons.account_balance),
              _paymentOption(ctx, "Credit Card", Icons.credit_card),
              _paymentOption(ctx, "E-Wallet (OVO/GoPay)", Icons.wallet),
              _paymentOption(ctx, "Cash to Admin", Icons.money),
            ],
          ),
        )
    );
  }

  Widget _paymentOption(BuildContext ctx, String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: _primaryColor),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(ctx);
        _showLoadingAndComplete();
      },
    );
  }

  void _showLoadingAndComplete() async {
    showDialog(context: context, barrierDismissible: false, builder: (BuildContext dialogContext) { return Center(child: CircularProgressIndicator(color: _primaryColor)); });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    await FirebaseFirestore.instance.collection("maintenance_reports").doc(widget.reportId).update({
      "status": "Completed",
      "is_paid": true,
      "updated_at": FieldValue.serverTimestamp(),
      "tracking_logs": FieldValue.arrayUnion([
        {
          'title': 'Completed',
          'subtitle': 'Resident confirmed payment and issue resolution.',
          'timestamp': Timestamp.now(),
        }
      ])
    });

    String currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection("Users").doc(currentUserUid).collection("Notifications").add({
      "title": "Maintenance Completed",
      "body": "You have confirmed the completion of your maintenance report.",
      "isRead": false,
      "timestamp": FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MaintenanceRatingPage(reportId: widget.reportId)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("My Report", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection("maintenance_reports").doc(widget.reportId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _primaryColor));
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text("Data not found"));

          String status = data['status'] ?? 'Submitted';
          Timestamp? ts = data['timestamp'];
          String dateStr = ts != null ? DateFormat("dd MMM yyyy, HH:mm").format(ts.toDate()) : "";
          int rating = data['rating'] ?? 0;

          Widget contactAdminButton = (status != "Completed" && !widget.isReadOnly) ? Column(
            children: [
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: BorderSide(color: _primaryColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: Icon(Icons.chat_bubble_outline, color: _primaryColor),
                label: Text("Contact Admin", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaintenanceChatPage(reportId: widget.reportId, title: data['title']))),
              )),
            ],
          ) : const SizedBox.shrink();

          if (status == "Waiting Confirmation") {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(6)), child: Text(status, style: TextStyle(color: Colors.amber.shade600, fontSize: 12, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 10),
                          Text(data['title'] ?? 'Title', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 5),
                          Text("Unit ${data['unit_no']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                          Text("Reported on $dateStr", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ]
                    ),
                  ),
                  const SizedBox(height: 40),

                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Icon(Icons.person_pin, size: 100, color: _primaryColor.withOpacity(0.5)),
                      Container(
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                        child: Icon(Icons.check_circle, color: Colors.amber.shade400, size: 40),
                      )
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text("Technician has marked this issue\nas completed.", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  const Text("Please confirm if the issue has\nbeen resolved.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Technician Information", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            const CircleAvatar(child: Icon(Icons.person)),
                            const SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(data['technician_name'] ?? 'Technician', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text("${data['category']} Technician", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ])),
                            IconButton(icon: Icon(Icons.call, color: _primaryColor), onPressed: (){})
                          ],
                        ),
                        const SizedBox(height: 15),
                        const Text("Completed On", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(dateStr, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildConfirmationActions(context, data),
                  contactAdminButton,
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)), child: Text(status == "Submitted" ? "Pending" : status, style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold))),
                const SizedBox(height: 10),
                Text(data['title'] ?? 'Title', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text("Unit ${data['unit_no']} • Reported on $dateStr", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 25),

                const Text("Progress Timeline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 15),
                _buildThreeStepTimeline(status, data),
                const SizedBox(height: 25),

                _buildDetailsCard(data),

                if (status == "Completed" && rating == 0 && !widget.isReadOnly) ...[
                  const Divider(height: 40),
                  SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    icon: const Icon(Icons.star, color: Colors.white),
                    label: const Text("Leave a Rating", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaintenanceRatingPage(reportId: widget.reportId))),
                  ))
                ],

                contactAdminButton
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> data) {
    String priority = data['priority'] ?? 'Medium';
    String desc = data['description'] ?? '-';
    int repairCost = data['repair_cost'] ?? 0;
    bool isPaid = data['is_paid'] ?? false;
    var catStyles = _getCategoryStyles(data['category'] ?? '');

    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 15),
          _buildDetailRow("Category", catStyles["icon"], catStyles["color"], data['category'] ?? '-'),
          _buildDetailRow("Location", Icons.location_on_outlined, Colors.redAccent, data['location'] ?? '-'),
          _buildDetailRow("Priority", Icons.circle, _getPriorityColor(priority), priority, isPriority: true),

          if (repairCost > 0) ...[
            const Divider(height: 20),
            _buildDetailRow("Repair Cost", Icons.payments_outlined, isPaid ? Colors.green : Colors.red, "${formatCurrency(repairCost)} (${isPaid ? 'Paid' : 'Unpaid'})", isPriority: true),
          ],

          const SizedBox(height: 15), const Text("Description", style: TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 13, height: 1.5), maxLines: _isDescExpanded ? null : 3, overflow: _isDescExpanded ? TextOverflow.visible : TextOverflow.ellipsis),
          if (desc.length > 100) Align(alignment: Alignment.centerRight, child: InkWell(onTap: () => setState(() => _isDescExpanded = !_isDescExpanded), child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(_isDescExpanded ? "Show less" : "Show more", style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.bold)))))
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, IconData icon, Color iconColor, String value, {bool isPriority = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)), Row(children: [Icon(icon, color: iconColor, size: 16), const SizedBox(width: 8), Text(value, style: TextStyle(fontWeight: isPriority ? FontWeight.bold : FontWeight.normal, fontSize: 13, color: isPriority ? iconColor : Colors.black87))])]));
  }

  Widget _buildThreeStepTimeline(String currentStatus, Map<String, dynamic> data) {
    List<dynamic> rawLogs = data['tracking_logs'] ?? [];
    List<Map<String, dynamic>> logs = [];

    if (rawLogs.isEmpty) {
      logs.add({'title': 'Report Submitted', 'subtitle': 'Your report has been received.', 'timestamp': data['timestamp']});
      if (currentStatus != 'Submitted') {
        logs.add({'title': 'Status Updated', 'subtitle': 'Admin updated your report.', 'timestamp': data['updated_at'] ?? data['timestamp']});
      }
    } else {
      logs = List<Map<String, dynamic>>.from(rawLogs);
    }

    logs.sort((a, b) {
      Timestamp tA = a['timestamp'] as Timestamp? ?? Timestamp.now();
      Timestamp tB = b['timestamp'] as Timestamp? ?? Timestamp.now();
      return tA.compareTo(tB);
    });

    Map<String, dynamic>? logSubmitted;
    Map<String, dynamic>? logCompleted;
    List<Map<String, dynamic>> logProgress = [];

    for (var log in logs) {
      String title = log['title'] ?? '';
      if (title.contains('Submitted')) {
        logSubmitted = log;
      } else if (title == 'Completed') {
        logCompleted = log;
      } else {
        logProgress.add(log);
      }
    }

    bool hasStarted = logSubmitted != null || currentStatus != 'Submitted';
    bool inProgress = currentStatus != 'Submitted' && currentStatus != 'Completed';
    bool isDone = currentStatus == 'Completed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMasterTimelineStep(
            title: "Report Submitted",
            timestamp: logSubmitted?['timestamp'] ?? data['timestamp'],
            isActive: true,
            isCompleted: hasStarted,
            isFirst: true,
            isLast: false,
          ),

          _buildExpandableProgressStep(
            isActive: hasStarted,
            isCompleted: isDone,
            logs: logProgress,
          ),

          _buildMasterTimelineStep(
            title: "Completed",
            timestamp: logCompleted?['timestamp'],
            isActive: isDone,
            isCompleted: isDone,
            isFirst: false,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterTimelineStep({required String title, required Timestamp? timestamp, required bool isActive, required bool isCompleted, required bool isFirst, required bool isLast}) {
    Color iconColor = isCompleted ? Colors.green : (isActive ? Colors.blue : Colors.grey.shade300);
    IconData iconData = isCompleted ? Icons.check_circle : (isActive ? Icons.radio_button_checked : Icons.circle);
    String dateLabel = timestamp != null ? DateFormat('dd MMM yyyy • HH:mm').format(timestamp.toDate()) : 'Pending';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(iconData, color: iconColor, size: 22),
            if (!isLast)
              Container(height: 35, width: 2, color: isCompleted ? Colors.green : Colors.grey.shade200, margin: const EdgeInsets.symmetric(vertical: 4)),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isActive || isCompleted ? Colors.black87 : Colors.grey, fontSize: 15)),
              const SizedBox(height: 2),
              Text(dateLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              if (!isLast) const SizedBox(height: 25)
            ],
          ),
        )
      ],
    );
  }

  Widget _buildExpandableProgressStep({required bool isActive, required bool isCompleted, required List<Map<String, dynamic>> logs}) {
    Color iconColor = isCompleted ? Colors.green : (isActive ? Colors.blue : Colors.grey.shade300);
    IconData iconData = isCompleted ? Icons.check_circle : (isActive ? Icons.hourglass_top : Icons.circle);

    String dateLabel = "Awaiting Action";
    if (isActive) {
      if (logs.isNotEmpty) {
        Timestamp? ts = logs.last['timestamp'];
        dateLabel = ts != null ? DateFormat('dd MMM yyyy • HH:mm').format(ts.toDate()) : 'In Progress';
      } else {
        dateLabel = "In Progress";
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(iconData, color: iconColor, size: 22),
            Container(
                height: _isTimelineExpanded ? (logs.length * 55.0) + 10 : 35, // Tinggi dinamis
                width: 2,
                color: isCompleted ? Colors.green : (isActive ? Colors.blue : Colors.grey.shade200),
                margin: const EdgeInsets.symmetric(vertical: 4)
            ),
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("In Progress", style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Colors.black87 : Colors.grey, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(dateLabel, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                  if (logs.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _isTimelineExpanded = !_isTimelineExpanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Text(_isTimelineExpanded ? "Hide" : "Details", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            Icon(_isTimelineExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 14, color: Colors.blueGrey)
                          ],
                        ),
                      ),
                    )
                ],
              ),

              if (_isTimelineExpanded && logs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 15, bottom: 5),
                  child: Column(
                    children: logs.map((log) {
                      Timestamp? ts = log['timestamp'];
                      String logDate = ts != null ? DateFormat('HH:mm').format(ts.toDate()) : '';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(margin: const EdgeInsets.only(top: 4), height: 6, width: 6, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(log['title'] ?? 'Update', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                                  Text(log['subtitle'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            Text(logDate, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              if (!_isTimelineExpanded) const SizedBox(height: 25)
            ],
          ),
        )
      ],
    );
  }

  Widget _buildConfirmationActions(BuildContext context, Map<String, dynamic> data) {
    int repairCost = data['repair_cost'] ?? 0;
    bool isPaid = data['is_paid'] ?? false;

    if (widget.isReadOnly) {
      return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)), child: const Text("Waiting for the active resident to verify and pay.", textAlign: TextAlign.center, style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)));
    }

    return Column(
        children: [
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () async {
              if (repairCost > 0 && !isPaid) {
                _showPaymentSheet(repairCost, data);
              } else {
                await FirebaseFirestore.instance.collection("maintenance_reports").doc(widget.reportId).update({
                  "status": "Completed",
                  "updated_at": FieldValue.serverTimestamp(),
                  "tracking_logs": FieldValue.arrayUnion([
                    {
                      'title': 'Completed',
                      'subtitle': 'Resident confirmed the issue is resolved.',
                      'timestamp': Timestamp.now(),
                    }
                  ])
                });

                String currentUserUid = FirebaseAuth.instance.currentUser!.uid;
                await FirebaseFirestore.instance.collection("Users").doc(currentUserUid).collection("Notifications").add({
                  "title": "Maintenance Completed",
                  "body": "You have confirmed the completion of your maintenance report.",
                  "isRead": false,
                  "timestamp": FieldValue.serverTimestamp(),
                });

                if(mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MaintenanceRatingPage(reportId: widget.reportId)));
              }
            },
            label: Text(repairCost > 0 && !isPaid ? "Pay ${formatCurrency(repairCost)} & Confirm" : "Confirm Completed", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
          const SizedBox(height: 10),

          SizedBox(width: double.infinity, height: 50, child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.refresh, color: Colors.red),
            onPressed: () async {
              await FirebaseFirestore.instance.collection("maintenance_reports").doc(widget.reportId).update({
                "status": "Assigned",
                "updated_at": FieldValue.serverTimestamp(),
                "tracking_logs": FieldValue.arrayUnion([
                  {
                    'title': 'Issue Not Resolved',
                    'subtitle': 'Resident reported the issue is still not fixed.',
                    'timestamp': Timestamp.now(),
                  }
                ])
              });

              String currentUserUid = FirebaseAuth.instance.currentUser!.uid;
              await FirebaseFirestore.instance.collection("Users").doc(currentUserUid).collection("Notifications").add({
                "title": "Maintenance Update",
                "body": "You have requested further review. Admin has been notified.",
                "isRead": false,
                "timestamp": FieldValue.serverTimestamp(),
              });
            },
            label: const Text("Still Not Fixed", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          )),
        ]
    );
  }
}
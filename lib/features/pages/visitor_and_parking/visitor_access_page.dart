import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'generate_visitor_pass_page.dart';
import 'visitor_qr_detail_page.dart';

class VisitorAccessPage extends StatefulWidget {
  final String unitNo;
  const VisitorAccessPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<VisitorAccessPage> createState() => _VisitorAccessPageState();
}

class _VisitorAccessPageState extends State<VisitorAccessPage> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final Color _primaryColor = const Color(0xffF9A826);

  bool isLoadingAccess = true;
  bool hasAccess = false;
  String blockReason = "";

  @override
  void initState() {
    super.initState();
    _verifyAccess();
  }

  Future<void> _verifyAccess() async {
    try {
      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('unit_no', isEqualTo: widget.unitNo).get();
      if (unitQuery.docs.isNotEmpty) {
        var data = unitQuery.docs.first.data();
        if (_uid == data['ownerUid'] || _uid == data['tenantUid'] || _uid == data['residentUid']) {
          if (mounted) setState(() { hasAccess = true; isLoadingAccess = false; });
          return;
        }
      }

      var accessQuery = await FirebaseFirestore.instance.collection('unit_access_members')
          .where('unit_no', isEqualTo: widget.unitNo).where('user_uid', isEqualTo: _uid).where('status', isEqualTo: 'Active').get();

      if (accessQuery.docs.isNotEmpty) {
        var permissions = accessQuery.docs.first.data()['permissions'] ?? {};
        if (permissions['Can Create Visitor Pass'] == true) {
          if (mounted) setState(() { hasAccess = true; isLoadingAccess = false; });
        } else {
          if (mounted) setState(() { hasAccess = false; blockReason = "You don't have permission to create visitor passes. Please contact the primary resident."; isLoadingAccess = false; });
        }
      } else {
        if (mounted) setState(() { hasAccess = false; blockReason = "You don't have access to this unit."; isLoadingAccess = false; });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingAccess = false);
    }
  }

  bool _isPassExpired(Timestamp? visitDate, String? exitTime) {
    if (visitDate == null || exitTime == null) return false;

    DateTime date = visitDate.toDate();
    try {
      DateTime parsedTime = DateFormat("hh:mm a").parse(exitTime);
      DateTime exactExitTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);
      return DateTime.now().isAfter(exactExitTime);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingAccess) return Scaffold(backgroundColor: Colors.white, appBar: _buildAppBar(), body: Center(child: CircularProgressIndicator(color: _primaryColor)));

    if (!hasAccess) {
      return Scaffold(
        backgroundColor: Colors.white, appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 80, color: Colors.grey.shade300), const SizedBox(height: 15),
              const Text("Access Denied", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)), const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(blockReason, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("ApartmentUnits").where("unit_no", isEqualTo: widget.unitNo).snapshots(),
        builder: (context, unitSnapshot) {
          if (unitSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          bool isReadOnly = false;
          if (unitSnapshot.hasData && unitSnapshot.data!.docs.isNotEmpty) {
            var unitData = unitSnapshot.data!.docs.first.data() as Map<String, dynamic>;
            if (_uid == (unitData['ownerUid'] ?? '') && (unitData['residentUid'] ?? '').isNotEmpty && unitData['residentUid'] != _uid) {
              isReadOnly = true;
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("visitor_passes").where("unit_no", isEqualTo: widget.unitNo).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryColor));

              List<QueryDocumentSnapshot> allDocs = snapshot.data?.docs.toList() ?? [];
              if (allDocs.isNotEmpty) {
                allDocs.sort((a, b) { Timestamp? tA = (a.data() as Map)['created_at']; Timestamp? tB = (b.data() as Map)['created_at']; return (tB ?? Timestamp.now()).compareTo(tA ?? Timestamp.now()); });
              }

              var activeDocs = allDocs.where((d) {
                var data = d.data() as Map;
                bool expired = _isPassExpired(data['visit_date'], data['exit_time']);
                return data['status'] == 'Active' && !expired;
              }).toList();

              var upcomingDocs = allDocs.where((d) {
                var data = d.data() as Map;
                bool expired = _isPassExpired(data['visit_date'], data['exit_time']);
                return data['status'] == 'Upcoming' && !expired;
              }).toList();

              var historyDocs = allDocs.where((d) {
                var data = d.data() as Map;
                bool expired = _isPassExpired(data['visit_date'], data['exit_time']);
                return ['Completed', 'Checked Out', 'Expired', 'Cancelled', 'Denied'].contains(data['status']) || expired;
              }).toList();

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  isReadOnly ? _buildReadOnlyBanner() : _buildCreatePassCard(),
                  const SizedBox(height: 25),

                  if (allDocs.isEmpty) _buildEmptyState(isReadOnly)
                  else ...[
                    if (activeDocs.isNotEmpty) ...[ _buildSectionTitle("Active Pass"), _buildVisitorList(activeDocs), const SizedBox(height: 20) ],
                    if (upcomingDocs.isNotEmpty) ...[ _buildSectionTitle("Upcoming Visitors"), _buildVisitorList(upcomingDocs), const SizedBox(height: 20) ],
                    if (historyDocs.isNotEmpty) ...[ _buildSectionTitle("Visitor History"), _buildVisitorList(historyDocs, isHistory: true) ],
                  ]
                ],
              );
            },
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() { return AppBar(backgroundColor: Colors.white, elevation: 0, centerTitle: true, title: const Text("Visitor Access", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)), actions: [IconButton(icon: const Icon(Icons.info_outline, color: Colors.black87), onPressed: () {})]); }

  Widget _buildReadOnlyBanner() { return Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade200)), child: Row(children: [Icon(Icons.lock_outline_rounded, color: Colors.amber.shade800, size: 35), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Visitor Access Unavailable", style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 4), Text("This unit is currently occupied by another resident. Visitor access privileges are assigned only to the active occupant.", style: TextStyle(color: Colors.amber.shade800, fontSize: 12))]))])); }

  Widget _buildCreatePassCard() {
    return Container(
      padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Expanded(child: Text("Create New Pass", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))), Icon(Icons.qr_code_scanner, color: Colors.white.withOpacity(0.8), size: 40)]),
          const SizedBox(height: 8), const Text("Generate QR code for your guest to ensure seamless and secure entry.", style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)), const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 45, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GenerateVisitorPassPage(unitNo: widget.unitNo))), icon: const Icon(Icons.add, size: 18), label: const Text("Generate Pass", style: TextStyle(fontWeight: FontWeight.bold))))
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isReadOnly) { return Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Column(children: [Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Stack(alignment: Alignment.bottomRight, children: [Icon(Icons.door_front_door, size: 80, color: Colors.orange.shade200), Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.qr_code, color: _primaryColor, size: 35))])), const SizedBox(height: 24), const Text("No visitors yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 12), Text(isReadOnly ? "Only active residents can manage visitors." : "You haven't created any visitor passes.\nGenerate a QR pass to invite your guests.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 14))])); }

  Widget _buildSectionTitle(String title) { return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), Text("View All", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _primaryColor))])); }

  Widget _buildVisitorList(List<QueryDocumentSnapshot> docs, {bool isHistory = false}) {
    return Column(
      children: docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;

        bool isRealExpired = _isPassExpired(data['visit_date'], data['exit_time']);
        String status = data['status'] ?? 'Upcoming';

        if (isRealExpired && status != 'Cancelled' && status != 'Denied' && status != 'Checked Out' && status != 'Completed') {
          status = 'Expired';
        }

        Color statusColor;
        if (status == 'Active') statusColor = Colors.green;
        else if (status == 'Upcoming') statusColor = Colors.orange;
        else if (status == 'Completed' || status == 'Checked Out') statusColor = Colors.green.shade700; // Warna history berhasil
        else statusColor = Colors.grey;

        Timestamp? ts = data['visit_date'];
        String dateStr = ts != null ? DateFormat("dd MMM yyyy").format(ts.toDate()) : "";
        String timeStr = "${data['entry_time']} - ${data['exit_time']}";

        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)), color: Colors.white,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(backgroundColor: Colors.orange.shade50, child: Text((data['visitor_name'] ?? 'V').toString()[0].toUpperCase(), style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold))),
            title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(data['visitor_name'] ?? 'Visitor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)), Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12))]),
            subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(isHistory ? dateStr : "$dateStr, $timeStr", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)), if (status == 'Active') ...[const SizedBox(height: 6), Row(children: [const Icon(Icons.timer_outlined, size: 14, color: Colors.green), const SizedBox(width: 4), Text("Valid for entry", style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold))])]])),
            trailing: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.qr_code, color: Colors.black87, size: 20)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorQrDetailPage(passId: doc.id))),
          ),
        );
      }).toList(),
    );
  }
}
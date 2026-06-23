import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_maintenance_report_page.dart';
import 'maintenance_detail_page.dart';

class MaintenancePage extends StatefulWidget {
  final String unitNo;
  const MaintenancePage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage> {
  String _selectedFilter = "All";
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  final Color _primaryColor = const Color(0xffF9A826);
  final Color _darkOrange = const Color(0xffE65100);

  late Stream<QuerySnapshot> _unitStream;
  late Stream<QuerySnapshot> _reportsStream;

  bool isLoadingAccess = true;
  bool hasAccess = false;
  String blockReason = "";

  @override
  void initState() {
    super.initState();
    _unitStream = FirebaseFirestore.instance.collection("ApartmentUnits").where("unit_no", isEqualTo: widget.unitNo).snapshots();
    _reportsStream = FirebaseFirestore.instance.collection("maintenance_reports").where("unit_no", isEqualTo: widget.unitNo).snapshots();
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
        if (permissions['Can Submit Maintenance'] == true) {
          if (mounted) setState(() { hasAccess = true; isLoadingAccess = false; });
        } else {
          if (mounted) setState(() { hasAccess = false; blockReason = "You don't have permission to submit maintenance reports. Please contact the primary resident."; isLoadingAccess = false; });
        }
      } else {
        if (mounted) setState(() { hasAccess = false; blockReason = "You don't have access to this unit."; isLoadingAccess = false; });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingAccess = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Submitted": return Colors.red.shade500;
      case "Assigned": return Colors.purple.shade500;
      case "In Progress": return _primaryColor;
      case "Waiting Confirmation": return Colors.amber.shade600;
      case "Completed": return Colors.green.shade500;
      default: return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case "Low": return Colors.green.shade500;
      case "Medium": return Colors.amber.shade600;
      case "High": return Colors.red.shade600;
      case "Emergency": return Colors.red.shade800;
      default: return Colors.grey.shade600;
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
          stream: _unitStream,
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
              stream: _reportsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryColor));
                var allDocs = snapshot.data?.docs ?? [];

                if (allDocs.isEmpty) return Container(color: Colors.white, child: _buildFullEmptyState(isReadOnly));

                var filteredDocs = allDocs.where((doc) {
                  String status = (doc.data() as Map<String, dynamic>)['status'] ?? 'Submitted';
                  if (_selectedFilter == "Pending" && status != "Submitted") return false;
                  // In progress dan Assigned masuk ke filter yang sama
                  if (_selectedFilter == "In Progress" && status != "In Progress" && status != "Assigned") return false;
                  if (_selectedFilter == "Waiting" && status != "Waiting Confirmation") return false;
                  if (_selectedFilter == "Done" && status != "Completed") return false;
                  return true;
                }).toList();

                filteredDocs.sort((a, b) {
                  Timestamp? tA = (a.data() as Map)['updated_at'] ?? (a.data() as Map)['timestamp'];
                  Timestamp? tB = (b.data() as Map)['updated_at'] ?? (b.data() as Map)['timestamp'];
                  return (tB ?? Timestamp.now()).compareTo(tA ?? Timestamp.now());
                });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isReadOnly ? _buildReadOnlyBanner() : _buildTopBanner(),
                    const Padding(padding: EdgeInsets.only(left: 20, top: 10, bottom: 10), child: Text("Filter Status", style: TextStyle(fontWeight: FontWeight.bold))),
                    _buildFilterChips(),
                    Expanded(child: filteredDocs.isEmpty ? _buildFilterEmptyState() : _buildListView(filteredDocs, isReadOnly)),
                  ],
                );
              },
            );
          }
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(backgroundColor: Colors.white, elevation: 0, centerTitle: true, title: const Text("Maintenance", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)));
  }

  Widget _buildTopBanner() {
    return Container(
      margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, _darkOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16)
      ),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2), elevation: 0),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateMaintenanceReportPage(unitNo: widget.unitNo))),
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text("Report Issue", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
            const SizedBox(height: 12), const Text("Report any problem in your unit", style: TextStyle(color: Colors.white, fontSize: 12)),
          ])),
          const Icon(Icons.assignment_turned_in, size: 40, color: Colors.white)
        ],
      ),
    );
  }

  Widget _buildReadOnlyBanner() {
    return Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade200)), child: Row(children: [Icon(Icons.lock_outline_rounded, color: Colors.amber.shade800, size: 35), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Reporting Disabled", style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 4), Text("Maintenance requests can only be managed by the active resident.", style: TextStyle(color: Colors.amber.shade800, fontSize: 12))]))]));
  }

  Widget _buildFullEmptyState(bool isReadOnly) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildCustomIllustration(), const SizedBox(height: 40),
              const Text("No maintenance reports yet", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 12),
              Text(isReadOnly ? "Only active residents can report issues." : "Report any issue in your unit and\nwe'll help you fix it.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, height: 1.5, fontSize: 14)), const SizedBox(height: 40),
              if (!isReadOnly)
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateMaintenanceReportPage(unitNo: widget.unitNo))),
                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                      label: const Text("Report Issue", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                  ),
                )
            ]
        ),
      ),
    );
  }

  Widget _buildCustomIllustration() {
    return SizedBox(
      height: 220, width: 250,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 180, height: 180, decoration: BoxDecoration(color: _primaryColor.withOpacity(0.05), shape: BoxShape.circle)),
          Positioned(top: 25, child: Container(width: 110, height: 140, decoration: BoxDecoration(color: _primaryColor.withOpacity(0.7), borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(8.0), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(height: 10), _buildCheckRow(), const SizedBox(height: 12), _buildCheckRow(), const SizedBox(height: 12), _buildCheckRow()]))))),
          Positioned(top: 15, child: Container(width: 50, height: 20, decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(8)))),
          Positioned(bottom: 25, left: 5, child: Column(children: [Icon(Icons.spa, color: _primaryColor.withOpacity(0.4), size: 40), Container(width: 30, height: 25, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))))])),
          Positioned(bottom: 25, right: 5, child: Column(children: [Icon(Icons.spa, color: Colors.green.shade500, size: 50), Container(width: 35, height: 25, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(8), bottomRight: Radius.circular(8))))])),
        ],
      ),
    );
  }

  Widget _buildCheckRow() { return Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check, color: Colors.grey.shade400, size: 16), const SizedBox(width: 6), Container(width: 35, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))]); }

  Widget _buildFilterEmptyState() => const Center(child: Text("No reports found for this filter.", style: TextStyle(color: Colors.grey)));

  Widget _buildFilterChips() {
    List<String> filters = ["All", "Pending", "In Progress", "Waiting", "Done"];
    return SizedBox(height: 40, child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: filters.length, itemBuilder: (context, index) {
      bool isSelected = _selectedFilter == filters[index];
      return Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(showCheckmark: false, label: Text(filters[index]), selected: isSelected, selectedColor: _primaryColor, backgroundColor: Colors.white, labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade600), onSelected: (val) { if (val) setState(() => _selectedFilter = filters[index]); }));
    }));
  }

  Widget _buildListView(List<QueryDocumentSnapshot> docs, bool isReadOnly) {
    return ListView.builder(
      padding: const EdgeInsets.all(20), itemCount: docs.length,
      itemBuilder: (context, index) {
        var data = docs[index].data() as Map<String, dynamic>;
        String docId = docs[index].id;
        String status = data['status'] ?? 'Submitted';
        String priority = data['priority'] ?? 'Medium';
        Color statusColor = _getStatusColor(status);
        Color prioColor = _getPriorityColor(priority);

        Timestamp? ts = data['updated_at'] ?? data['timestamp'];
        String timeAgo = "Recently";
        if (ts != null) {
          Duration diff = DateTime.now().difference(ts.toDate());
          if (diff.inMinutes < 60) timeAgo = "Updated ${diff.inMinutes} mins ago";
          else if (diff.inHours < 24) timeAgo = "Updated ${diff.inHours} hours ago";
          else if (diff.inDays == 1) timeAgo = "Updated Yesterday";
          else timeAgo = "Updated ${diff.inDays} days ago";
        }

        int rating = data['rating'] ?? 0;

        return Card(
          color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaintenanceDetailPage(reportId: docId, isReadOnly: isReadOnly))),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                children: [
                  Container(height: 90, width: 80, decoration: BoxDecoration(color: _primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.home_repair_service_rounded, color: _primaryColor.withOpacity(0.7), size: 35)),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(data['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: prioColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(priority, style: TextStyle(color: prioColor, fontSize: 10, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        const SizedBox(height: 4), Text("Unit ${data['unit_no']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), const SizedBox(height: 8),
                        Row(children: [Icon(Icons.circle, color: statusColor, size: 10), const SizedBox(width: 6), Text(status == "Submitted" ? "Pending" : status, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold))]),
                        if (status == 'Completed' && rating > 0) ...[const SizedBox(height: 6), Row(children: List.generate(5, (idx) => Icon(Icons.star, size: 14, color: idx < rating ? Colors.amber : Colors.grey.shade300)))],
                        const SizedBox(height: 6), Text(timeAgo, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey)
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
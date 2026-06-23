import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'create_unit_invitation_page.dart';

class UnitAccessPage extends StatefulWidget {
  final String unitNo;
  final bool isPrimaryResident;

  const UnitAccessPage({Key? key, required this.unitNo, required this.isPrimaryResident}) : super(key: key);

  @override
  State<UnitAccessPage> createState() => _UnitAccessPageState();
}

class _UnitAccessPageState extends State<UnitAccessPage> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final Color _primaryColor = const Color(0xffF9A826);

  bool _isRealPrimary = false;
  bool _isCheckingRole = true;

  @override
  void initState() {
    super.initState();
    _verifyPrimaryStatus();
  }

  Future<void> _verifyPrimaryStatus() async {
    try {
      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('unit_no', isEqualTo: widget.unitNo).get();
      if (unitQuery.docs.isNotEmpty) {
        var data = unitQuery.docs.first.data();
        String ownerUid = data['ownerUid'] ?? '';
        String tenantUid = data['tenantUid'] ?? '';
        String residentUid = data['residentUid'] ?? '';

        if (_uid == ownerUid || _uid == tenantUid || _uid == residentUid) {
          _isRealPrimary = true;
        }
      }
    } catch (e) {
      debugPrint("Error verifying role: $e");
    }

    if (mounted) {
      setState(() {
        _isCheckingRole = false;
      });
    }
  }

  Future<void> _removeMember(String docId, String memberName, String role, String tower, String unitNo, String targetUid, bool isLeaving) async {
    String title = isLeaving ? "Leave Unit?" : "Remove Member?";
    String content = isLeaving
        ? "Are you sure you want to leave Unit $unitNo? You will lose access immediately."
        : "Are you sure you want to remove $memberName from Unit $unitNo?";

    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
              onPressed: () async {
                Navigator.pop(dialogContext);

                await FirebaseFirestore.instance.collection("unit_access_members").doc(docId).update({
                  'status': 'Inactive',
                  'removed_at': FieldValue.serverTimestamp(),
                });

                try {
                  var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
                  for (var doc in secQuery.docs) {
                    await doc.reference
                        .collection("Members")
                        .doc(targetUid)
                        .collection("Bookings")
                        .doc("SHARED_${unitNo}_$targetUid")
                        .delete();
                  }
                } catch (e) {
                  debugPrint("Gagal menghapus data dropdown: $e");
                }

                if (role == 'Resident Member') {
                  var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();

                  if (unitQuery.docs.isNotEmpty) {
                    var unitDoc = unitQuery.docs.first;
                    String existingNames = unitDoc['residentName'] ?? '';
                    String existingPhones = unitDoc['residentPhone'] ?? '';

                    List<String> names = existingNames.split('\n');
                    List<String> phones = existingPhones.split('\n');

                    int index = names.indexWhere((n) => n.trim() == memberName.trim());
                    if (index != -1 && index != 0) {
                      names.removeAt(index);
                      if (index < phones.length) phones.removeAt(index);

                      await unitDoc.reference.update({'residentName': names.join('\n'), 'residentPhone': phones.join('\n')});
                    }
                  }
                }
              },
              child: Text(isLeaving ? "Leave" : "Remove", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.unitNo.isEmpty || widget.unitNo == "Unknown" || widget.unitNo == "No Unit") {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: const Center(child: Text("You are not connected to any unit.", style: TextStyle(color: Colors.grey))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _isCheckingRole
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("unit_access_members").where("unit_no", isEqualTo: widget.unitNo).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryColor));

          List<QueryDocumentSnapshot> activeMembers = [];
          List<QueryDocumentSnapshot> historyMembers = [];

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'Active') {
                activeMembers.add(doc);
              } else {
                historyMembers.add(doc);
              }
            }
          }

          historyMembers.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            Timestamp? tA = aData['removed_at'] as Timestamp?;
            Timestamp? tB = bData['removed_at'] as Timestamp?;
            if (tA == null && tB == null) return 0;
            if (tA == null) return 1;
            if (tB == null) return -1;
            return tB.compareTo(tA);
          });

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _primaryColor.withOpacity(0.3))),
                child: Row(
                  children: [
                    Icon(Icons.meeting_room, color: _primaryColor),
                    const SizedBox(width: 12),
                    Expanded(child: Text("Managing access for Unit ${widget.unitNo}", style: TextStyle(color: Colors.orange.shade900, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              _buildSectionTitle("Active Members", activeMembers.length),
              if (activeMembers.isEmpty)
                _buildEmptyState()
              else
                ...activeMembers.map((doc) => _buildMemberCard(doc, isHistory: false)),

              if (historyMembers.isNotEmpty) ...[
                const SizedBox(height: 35),
                const Divider(),
                const SizedBox(height: 15),
                _buildSectionTitle("History (Past Members)", historyMembers.length),
                ...historyMembers.map((doc) => _buildMemberCard(doc, isHistory: true)),
              ]
            ],
          );
        },
      ),
      bottomNavigationBar: (_isCheckingRole || !_isRealPrimary) ? null : Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateUnitInvitationPage(unitNo: widget.unitNo))),
            icon: const Icon(Icons.person_add, color: Colors.white),
            label: const Text("Invite Member", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white, elevation: 0, centerTitle: true,
      title: const Text("Unit Access", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(width: 10),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10)), child: Text(count.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("No shared members yet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Text("Invite family members or trusted people to access your apartment unit together.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(QueryDocumentSnapshot doc, {required bool isHistory}) {
    var data = doc.data() as Map<String, dynamic>;
    String targetUid = data['user_uid'] ?? '';
    bool isMe = targetUid == _uid;
    String role = data['role'] ?? 'Resident Member';
    String tower = data['tower'] ?? 'Unknown';

    MaterialColor badgeColor = Colors.blue;
    if (role == 'Primary Resident') badgeColor = Colors.green;
    if (role == 'Limited Access') badgeColor = Colors.purple;
    if (isHistory) badgeColor = Colors.grey;

    bool canRemove = false;
    String btnText = "Remove Access";

    if (!isHistory) {
      if (_isRealPrimary && !isMe) {
        canRemove = true;
      } else if (!_isRealPrimary && isMe) {
        canRemove = true;
        btnText = "Leave Unit";
      }
    }

    String dateText = "";
    if (isHistory) {
      Timestamp? removedAt = data['removed_at'];
      if (removedAt != null) {
        DateTime dt = removedAt.toDate();
        dateText = "Removed as $role on ${dt.day}/${dt.month}/${dt.year}";
      } else {
        dateText = "Removed as $role";
      }
    } else {
      Timestamp? joinedAt = data['joined_at'] ?? data['created_at'];
      if (joinedAt != null) {
        DateTime dt = joinedAt.toDate();
        dateText = "Joined: ${dt.day}/${dt.month}/${dt.year}";
      }
    }

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      color: isHistory ? Colors.grey.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                    radius: 25,
                    backgroundColor: isHistory ? Colors.grey.shade300 : _primaryColor.withOpacity(0.1),
                    child: Text((data['user_name'] ?? 'U').toString()[0].toUpperCase(), style: TextStyle(color: isHistory ? Colors.grey.shade600 : _primaryColor, fontWeight: FontWeight.bold, fontSize: 18))
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isMe ? "${data['user_name']} (You)" : data['user_name'] ?? 'User', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isHistory ? Colors.grey.shade700 : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(isHistory ? "Removed" : role, style: TextStyle(color: isHistory ? Colors.grey.shade700 : badgeColor.shade700, fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (dateText.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(isHistory ? Icons.history : Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(dateText, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                  ),
                ],
              ),
            ],

            if (canRemove) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                      onPressed: () => _removeMember(doc.id, data['user_name'], role, tower, widget.unitNo, targetUid, isMe && !_isRealPrimary),
                      child: Text(btnText, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class JoinUnitPage extends StatefulWidget {
  const JoinUnitPage({Key? key}) : super(key: key);

  @override
  State<JoinUnitPage> createState() => _JoinUnitPageState();
}

class _JoinUnitPageState extends State<JoinUnitPage> {
  final TextEditingController _codeCtrl = TextEditingController();
  final Color _primaryColor = const Color(0xffF9A826);
  bool _isLoading = false;
  late final String _uid;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser!.uid;
  }

  Future<void> _submitCode() async {
    String inputCode = _codeCtrl.text.trim().toUpperCase();

    if (inputCode.length != 6) {
      Fluttertoast.showToast(msg: "Please enter a valid 6-character code.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      var inviteQuery = await FirebaseFirestore.instance
          .collection("unit_invitations")
          .where("code", isEqualTo: inputCode)
          .get();

      if (inviteQuery.docs.isEmpty) {
        Fluttertoast.showToast(msg: "Invalid invitation code.");
        setState(() => _isLoading = false);
        return;
      }

      var inviteDoc = inviteQuery.docs.first;
      var inviteData = inviteDoc.data();

      if (inviteData['created_by'] == _uid) {
        Fluttertoast.showToast(msg: "You cannot use an invitation code you generated yourself.");
        setState(() => _isLoading = false);
        return;
      }

      Timestamp expiresAt = inviteData['expires_at'];
      if (expiresAt.toDate().isBefore(DateTime.now())) {
        Fluttertoast.showToast(msg: "This invitation code has expired.");
        setState(() => _isLoading = false);
        return;
      }

      String unitNo = inviteData['unit_no'];
      String tower = inviteData['tower'] ?? "Unknown Tower";
      String role = inviteData['role'];
      Map<String, dynamic> permissions = inviteData['permissions'] ?? {};

      var unitMasterQuery = await FirebaseFirestore.instance
          .collection('ApartmentUnits')
          .where('tower', isEqualTo: tower)
          .where('unit_no', isEqualTo: unitNo)
          .get();

      if (unitMasterQuery.docs.isNotEmpty) {
        var unitData = unitMasterQuery.docs.first.data();
        if (unitData['ownerUid'] == _uid || unitData['tenantUid'] == _uid || unitData['residentUid'] == _uid) {
          Fluttertoast.showToast(msg: "You are already the Primary Resident of Unit $unitNo.");
          setState(() => _isLoading = false);
          return;
        }
      }

      String userName = "Resident";
      String userEmail = FirebaseAuth.instance.currentUser!.email ?? "";
      String userPhone = "";
      String? secretaryId;

      var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
      for (var doc in secQuery.docs) {
        var member = await doc.reference.collection("Members").doc(_uid).get();
        if (member.exists && member.data() != null) {
          secretaryId = doc.id;
          userName = member.data()!['Name'] ?? "Resident";
          userPhone = member.data()!['Phone'] ?? "";
          break;
        }
      }

      var existQuery = await FirebaseFirestore.instance
          .collection("unit_access_members")
          .where("unit_no", isEqualTo: unitNo)
          .where("user_uid", isEqualTo: _uid)
          .where("status", isEqualTo: "Active")
          .get();

      if (existQuery.docs.isNotEmpty) {
        Fluttertoast.showToast(msg: "You are already an active member of Unit $unitNo.");
        setState(() => _isLoading = false);
        return;
      }

      await FirebaseFirestore.instance.collection("unit_access_members").add({
        "unit_no": unitNo,
        "tower": tower,
        "user_uid": _uid,
        "user_name": userName,
        "user_email": userEmail,
        "role": role,
        "permissions": permissions,
        "status": "Active",
        "joined_at": FieldValue.serverTimestamp(),
      });

      if (secretaryId != null) {
        await FirebaseFirestore.instance
            .collection("Secretary")
            .doc(secretaryId)
            .collection("Members")
            .doc(_uid)
            .collection("Bookings")
            .doc("SHARED_${unitNo}_$_uid")
            .set({
          "unit_no": unitNo,
          "tower": tower,
          "transaction_type": role == "Resident Member" ? "Shared Resident" : "Limited Access",
          "duration": "Shared Access",
          "contract_end_date": "Permanent",
          "is_rented_out": false,
          "status": "Occupied",
          "timestamp": FieldValue.serverTimestamp(),
        });
      }

      if (role == "Resident Member" && unitMasterQuery.docs.isNotEmpty) {
        var unitDoc = unitMasterQuery.docs.first;
        String existingNames = unitDoc.data()['residentName'] ?? '';
        String existingPhones = unitDoc.data()['residentPhone'] ?? '';

        List<String> namesList = existingNames.isNotEmpty ? existingNames.split('\n') : [];
        List<String> phonesList = existingPhones.isNotEmpty ? existingPhones.split('\n') : [];

        if (!namesList.contains(userName)) {
          namesList.add(userName);
          phonesList.add(userPhone);

          await unitDoc.reference.update({
            'residentName': namesList.join('\n'),
            'residentPhone': phonesList.join('\n'),
          });
        }
      }

      await inviteDoc.reference.delete();

      _codeCtrl.clear();
      Fluttertoast.showToast(msg: "Successfully joined Unit $unitNo!", backgroundColor: Colors.green);

      // Kita tidak pop context agar user bisa melihat unit barunya di list bawah
      setState(() => _isLoading = false);

    } catch (e) {
      Fluttertoast.showToast(msg: "An error occurred: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveUnit(String docId, String role, String tower, String unitNo, String memberName) async {
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Leave Unit?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text("Are you sure you want to leave Unit $unitNo? You will lose access immediately."),
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
                        .doc(_uid)
                        .collection("Bookings")
                        .doc("SHARED_${unitNo}_$_uid")
                        .delete();
                  }
                } catch (e) {
                  debugPrint("Failed to delete dropdown data: $e");
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
                    if (index != -1) {
                      names.removeAt(index);
                      if (index < phones.length) phones.removeAt(index);

                      await unitDoc.reference.update({'residentName': names.join('\n'), 'residentPhone': phones.join('\n')});
                    }
                  }
                }

                Fluttertoast.showToast(msg: "You have left Unit $unitNo.", backgroundColor: Colors.black87);
              },
              child: const Text("Leave", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("Join Unit", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.vpn_key_outlined, color: _primaryColor, size: 40)),
                  const SizedBox(height: 20),
                  const Text("Enter Invitation Code", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  const Text("Ask the primary resident to generate a 6-digit code.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 25),

                  TextField(
                    controller: _codeCtrl,
                    textAlign: TextAlign.center,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    inputFormatters: [UpperCaseTextFormatter()],
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _primaryColor, letterSpacing: 10),
                    decoration: InputDecoration(
                      counterText: "", hintText: "XXXXXX", hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 10),
                      filled: true, fillColor: Colors.grey.shade50, contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _primaryColor, width: 2)),
                    ),
                    onChanged: (val) { if (val.length == 6) FocusScope.of(context).unfocus(); },
                  ),
                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isLoading ? null : _submitCode,
                      child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Join Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            const Text("My Joined Units", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            const SizedBox(height: 15),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("unit_access_members").where("user_uid", isEqualTo: _uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: _primaryColor));

                List<QueryDocumentSnapshot> activeUnits = [];
                List<QueryDocumentSnapshot> historyUnits = [];

                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    if (data['status'] == 'Active') activeUnits.add(doc);
                    else historyUnits.add(doc);
                  }
                }

                // Sorting
                activeUnits.sort((a, b) {
                  Timestamp? tA = (a.data() as Map)['joined_at'];
                  Timestamp? tB = (b.data() as Map)['joined_at'];
                  return (tB ?? Timestamp.now()).compareTo(tA ?? Timestamp.now());
                });

                historyUnits.sort((a, b) {
                  Timestamp? tA = (a.data() as Map)['removed_at'];
                  Timestamp? tB = (b.data() as Map)['removed_at'];
                  return (tB ?? Timestamp.now()).compareTo(tA ?? Timestamp.now());
                });

                if (activeUnits.isEmpty && historyUnits.isEmpty) {
                  return Container(
                    width: double.infinity, padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                    child: Column(
                      children: [
                        Icon(Icons.home_work_outlined, size: 50, color: Colors.grey.shade300),
                        const SizedBox(height: 15),
                        const Text("No joined units yet", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (activeUnits.isNotEmpty) ...[
                      const Text("Active Access", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 10),
                      ...activeUnits.map((doc) => _buildUnitCard(doc, isHistory: false)),
                    ],

                    if (historyUnits.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text("History (Past Access)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 10),
                      ...historyUnits.map((doc) => _buildUnitCard(doc, isHistory: true)),
                    ]
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitCard(QueryDocumentSnapshot doc, {required bool isHistory}) {
    var data = doc.data() as Map<String, dynamic>;
    String unitNo = data['unit_no'] ?? 'Unknown';
    String tower = data['tower'] ?? 'Unknown';
    String role = data['role'] ?? 'Resident Member';
    String memberName = data['user_name'] ?? '';

    MaterialColor badgeColor = Colors.blue;
    if (role == 'Primary Resident') badgeColor = Colors.green;
    if (role == 'Limited Access') badgeColor = Colors.purple;
    if (isHistory) badgeColor = Colors.grey;

    String dateText = "";
    if (isHistory) {
      Timestamp? removedAt = data['removed_at'];
      if (removedAt != null) {
        DateTime dt = removedAt.toDate();
        dateText = "Removed as $role on ${DateFormat('dd MMM yyyy').format(dt)}";
      } else {
        dateText = "Removed as $role";
      }
    } else {
      Timestamp? joinedAt = data['joined_at'];
      if (joinedAt != null) {
        DateTime dt = joinedAt.toDate();
        dateText = "Joined: ${DateFormat('dd MMM yyyy').format(dt)}";
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: isHistory ? Colors.grey.shade200 : _primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.meeting_room, color: isHistory ? Colors.grey.shade500 : _primaryColor),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Unit $unitNo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isHistory ? Colors.grey.shade700 : Colors.black87)),
                      const SizedBox(height: 4),
                      Text(tower, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: badgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(isHistory ? "Access Removed" : role, style: TextStyle(color: badgeColor.shade700, fontSize: 10, fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
                if (!isHistory)
                  IconButton(
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    tooltip: "Leave Unit",
                    onPressed: () => _leaveUnit(doc.id, role, tower, unitNo, memberName),
                  )
              ],
            ),
            if (dateText.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(isHistory ? Icons.history : Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(child: Text(dateText, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic))),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
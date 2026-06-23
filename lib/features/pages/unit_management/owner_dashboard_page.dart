import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class OwnerDashboardPage extends StatefulWidget {
  const OwnerDashboardPage({Key? key}) : super(key: key);
  @override
  State<OwnerDashboardPage> createState() => _OwnerDashboardPageState();
}

class _OwnerDashboardPageState extends State<OwnerDashboardPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  Future<void> _updateAppStatus(String appId, String newStatus, String tenantUid, String unitNo, {String? reason}) async {
    try {
      Map<String, dynamic> updates = {
        "status": newStatus,
        "updatedAt": FieldValue.serverTimestamp(),
      };
      if (reason != null) updates["decline_reason"] = reason;
      await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update(updates);

      Fluttertoast.showToast(msg: "Status Successfully Updated!");
    } catch (e) { Fluttertoast.showToast(msg: "Error: $e"); }
  }

  Future<void> _approveExtensionPayment(String appId, String reqEndDate, String reqDuration) async {
    try {
      await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update({
        "status": "Occupied",
        "transaction_type": "Rent",
        "contract_end_date": reqEndDate,
        "duration": reqDuration,
        "updatedAt": FieldValue.serverTimestamp(),
        "extension_approved_at": FieldValue.serverTimestamp(),
        "last_extension_duration": reqDuration,
        "requested_end_date": FieldValue.delete(),
        "requested_duration": FieldValue.delete(),
        "requested_payment": FieldValue.delete(),
      });
      Fluttertoast.showToast(msg: "Extension Payment Verified & Finalized!");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  void _showDeclineDialog(String appId, String tenantUid, String unitNo, String tower, String transactionType) {
    TextEditingController reasonCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Reject Applicant"),
          content: TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(hintText: "Reason for rejection (Optional)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  await _updateAppStatus(appId, "Declined by Owner", tenantUid, unitNo, reason: reasonCtrl.text);

                  try {
                    var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits')
                        .where('tower', isEqualTo: tower)
                        .where('unit_no', isEqualTo: unitNo).get();

                    if (unitQuery.docs.isNotEmpty) {
                      String revertStatus = transactionType.contains("Buy") ? "Dijual" : "Disewakan";
                      await unitQuery.docs.first.reference.update({
                        'status': revertStatus,
                      });
                    }
                  } catch (e) {
                    debugPrint("Error reverting unit to catalog: $e");
                  }

                }, child: const Text("Reject", style: TextStyle(color: Colors.white))),
          ],
        )
    );
  }

  Future<void> _approveEndContract(String appId, String tower, String unitNo) async {
    try {
      await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update({
        "status": "Contract Ended",
        "updatedAt": FieldValue.serverTimestamp(),
      });

      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits')
          .where('tower', isEqualTo: tower)
          .where('unit_no', isEqualTo: unitNo).get();

      if (unitQuery.docs.isNotEmpty) {
        await unitQuery.docs.first.reference.update({
          'status': 'Disewakan',
          'residentUid': FieldValue.delete(),
          'residentName': FieldValue.delete(),
          'residentPhone': FieldValue.delete(),
          'subleaser_uid': FieldValue.delete(),
        });
      }

      Fluttertoast.showToast(msg: "End Contract Approved! Unit is now available.");
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    }
  }

  void _showDeclineEndContractDialog(String appId) {
    TextEditingController reasonCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Reject End Contract"),
          content: TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(hintText: "Reason for rejection (Optional)", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update({
                    "status": "Occupied",
                    "end_contract_decline_reason": reasonCtrl.text,
                    "updatedAt": FieldValue.serverTimestamp(),
                    "end_contract_declined_at": FieldValue.serverTimestamp(),
                  });
                  Fluttertoast.showToast(msg: "End contract request rejected.");
                },
                child: const Text("Reject", style: TextStyle(color: Colors.white))
            ),
          ],
        )
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String displayStatus = status;

    if (status.contains("Pending") || status.contains("Requesting") || status.contains("Awaiting")) {
      bgColor = Colors.orange.shade50; textColor = Colors.orange.shade800;
    } else if (status == "Occupied" || status == "Approved & Active") {
      bgColor = Colors.green.shade50; textColor = Colors.green.shade800;
      displayStatus = "Active Tenant";
    } else if (status.contains("Ended") || status.contains("Decline") || status.contains("Cancel")) {
      bgColor = Colors.grey.shade200; textColor = Colors.grey.shade700;
    } else if (status == "Ownership Transferred") { // PERBAIKAN: Badge khusus unit yang sudah terjual
      bgColor = Colors.purple.shade50; textColor = Colors.purple.shade800;
      displayStatus = "Unit Sold & Transferred";
    } else {
      bgColor = Colors.blue.shade50; textColor = Colors.blue.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(displayStatus, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  String _calculateRemainingTime(String? endDateStr) {
    if (endDateStr == null || endDateStr.isEmpty || endDateStr == "Permanent") return "Permanent";
    try {
      DateTime end = DateTime.parse(endDateStr);
      DateTime now = DateTime.now();
      if (end.isBefore(now)) return "Expired";
      Duration diff = end.difference(now);
      int days = diff.inDays;
      if (days >= 30) {
        int months = days ~/ 30;
        int remainDays = days % 30;
        return remainDays == 0 ? "$months months remaining" : "$months mo $remainDays days remaining";
      } else {
        return "$days days remaining";
      }
    } catch(e) { return "Active"; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Property Dashboard", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("RentalApplications").where('ownerUid', isEqualTo: uid).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No property data found."));

            var allDocs = snapshot.data!.docs;
            DateTime now = DateTime.now();

            Map<String, QueryDocumentSnapshot> activeUniqueDocs = {};
            List<QueryDocumentSnapshot> finishedDocs = [];

            for (var doc in allDocs) {
              var data = doc.data() as Map<String, dynamic>;
              String tower = (data['tower'] ?? "").toString().trim();
              String unitNo = (data['unit_no'] ?? "").toString().trim();
              String tenantUid = (data['tenantUid'] ?? "").toString().trim();
              String status = data['status'] ?? "";
              String type = data['transaction_type'] ?? "";

              bool isFinishedExtension = type == "Lease Extension" && (status == "Approved & Active" || status == "Occupied");
              bool isFinishedState = status == "Contract Ended" || status == "Ownership Transferred" || status.contains("Decline") || status.contains("Cancel") || isFinishedExtension;

              if (isFinishedState) {
                finishedDocs.add(doc);
              } else {
                String uniqueKey = "${tower}_${unitNo}_${tenantUid}";
                if (!activeUniqueDocs.containsKey(uniqueKey)) {
                  activeUniqueDocs[uniqueKey] = doc;
                } else {
                  if (doc.metadata.hasPendingWrites) {
                    activeUniqueDocs[uniqueKey] = doc;
                    continue;
                  }
                  if (activeUniqueDocs[uniqueKey]!.metadata.hasPendingWrites) continue;

                  var existingData = activeUniqueDocs[uniqueKey]!.data() as Map<String, dynamic>;
                  Timestamp tExisting = existingData['updatedAt'] as Timestamp? ?? existingData['timestamp'] as Timestamp? ?? Timestamp(0, 0);
                  Timestamp tNew = data['updatedAt'] as Timestamp? ?? data['timestamp'] as Timestamp? ?? Timestamp(0, 0);

                  if (tNew.compareTo(tExisting) > 0) {
                    activeUniqueDocs[uniqueKey] = doc;
                  }
                }
              }
            }

            List<QueryDocumentSnapshot> cleanDocs = activeUniqueDocs.values.toList() + finishedDocs;

            List<Map<String, dynamic>> needsActionDocs = [];
            List<Map<String, dynamic>> activeDocs = [];
            List<Map<String, dynamic>> recentUpdateDocs = [];
            List<Map<String, dynamic>> historyDocs = [];

            for (var doc in cleanDocs) {
              var data = doc.data() as Map<String, dynamic>;
              var item = {'id': doc.id, 'docRef': doc.reference, ...data};

              String s = data['status'] ?? "";
              String type = data['transaction_type'] ?? "";

              DateTime docDate;
              if (doc.metadata.hasPendingWrites) {
                docDate = now;
              } else {
                Timestamp? ts = data['updatedAt'] as Timestamp?;
                if (ts == null) ts = data['timestamp'] as Timestamp?;
                docDate = ts?.toDate() ?? now;
              }

              Duration diff = now.difference(docDate);
              bool isFinishedState = s == "Contract Ended" || s == "Ownership Transferred" || s.contains("Decline") || s.contains("Cancel");

              if (diff.inDays >= 7 && isFinishedState && !doc.metadata.hasPendingWrites) {
                Future.microtask(() => doc.reference.delete());
                continue;
              }

              if (s == "Pending Owner Approval" || s == "Awaiting Owner Signature" || s == "Requesting End Contract" || (type == "Lease Extension" && s == "Payment Verification Pending")) {
                needsActionDocs.add(item);
              }
              else if (s == "Occupied" || s == "Approved & Active" || s == "Awaiting Payment" || s == "Awaiting Admin Payment Verification" || s == "Pending Initial Review" || s == "Processing Move-in") {
                activeDocs.add(item);
              }
              else if (isFinishedState) {
                if (diff.inHours < 5) recentUpdateDocs.add(item);
                else historyDocs.add(item);
              }

              if (data['extension_approved_at'] != null) {
                Timestamp extTs = data['extension_approved_at'] as Timestamp;
                Duration extDiff = now.difference(extTs.toDate());
                if (extDiff.inDays < 7) {
                  var extItem = {
                    'id': doc.id + "_ext_app",
                    'unit_no': data['unit_no'],
                    'tenantName': data['tenantName'],
                    'status': "Extension Approved",
                    'duration': data['last_extension_duration'] ?? "Extended",
                    'transaction_type': "Lease Extension",
                    'updatedAt': extTs,
                    'timestamp': extTs,
                  };
                  if (extDiff.inHours < 5) recentUpdateDocs.add(extItem);
                  else historyDocs.add(extItem);
                }
              }

              if (data['extension_declined_at'] != null) {
                Timestamp extTs = data['extension_declined_at'] as Timestamp;
                Duration extDiff = now.difference(extTs.toDate());
                if (extDiff.inDays < 7) {
                  var extItem = {
                    'id': doc.id + "_ext_dec",
                    'unit_no': data['unit_no'],
                    'tenantName': data['tenantName'],
                    'status': "Extension Declined",
                    'transaction_type': "Lease Extension",
                    'updatedAt': extTs,
                    'timestamp': extTs,
                  };
                  if (extDiff.inHours < 5) recentUpdateDocs.add(extItem);
                  else historyDocs.add(extItem);
                }
              }

              if (data['end_contract_declined_at'] != null) {
                Timestamp extTs = data['end_contract_declined_at'] as Timestamp;
                Duration extDiff = now.difference(extTs.toDate());
                if (extDiff.inDays < 7) {
                  var extItem = {
                    'id': doc.id + "_end_dec",
                    'unit_no': data['unit_no'],
                    'tenantName': data['tenantName'],
                    'status': "End Contract Declined",
                    'transaction_type': "Rent",
                    'updatedAt': extTs,
                    'timestamp': extTs,
                  };
                  if (extDiff.inHours < 5) recentUpdateDocs.add(extItem);
                  else historyDocs.add(extItem);
                }
              }
            }

            activeDocs.sort((a, b) {
              Timestamp tA = a['timestamp'] as Timestamp? ?? Timestamp.now();
              Timestamp tB = b['timestamp'] as Timestamp? ?? Timestamp.now();
              return tA.compareTo(tB);
            });

            recentUpdateDocs.sort((a,b) {
              Timestamp tA = a['updatedAt'] as Timestamp? ?? a['timestamp'] as Timestamp? ?? Timestamp.now();
              Timestamp tB = b['updatedAt'] as Timestamp? ?? b['timestamp'] as Timestamp? ?? Timestamp.now();
              return tB.compareTo(tA);
            });

            historyDocs.sort((a,b) {
              Timestamp tA = a['updatedAt'] as Timestamp? ?? a['timestamp'] as Timestamp? ?? Timestamp.now();
              Timestamp tB = b['updatedAt'] as Timestamp? ?? b['timestamp'] as Timestamp? ?? Timestamp.now();
              return tB.compareTo(tA);
            });

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (needsActionDocs.isNotEmpty) ...[
                    const Text("Needs Action", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                    const SizedBox(height: 10),
                    ...needsActionDocs.map((doc) => _buildActionCard(doc)).toList(),
                    const SizedBox(height: 20),
                  ],

                  if (activeDocs.isNotEmpty) ...[
                    const Text("Active & Incoming Tenants", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    ...activeDocs.map((doc) => _buildActiveCard(doc)).toList(),
                    const SizedBox(height: 20),
                  ],

                  if (recentUpdateDocs.isNotEmpty) ...[
                    const Text("Recent Updates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 10),
                    ...recentUpdateDocs.map((doc) => _buildHistoryCard(doc)).toList(),
                    const SizedBox(height: 20),
                  ],

                  const Divider(),
                  ExpansionTile(
                    title: const Text("History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)),
                    children: historyDocs.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(15.0), child: Text("No older history available.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)))]
                        : historyDocs.map((doc) => _buildHistoryCard(doc)).toList(),
                  )
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildActionCard(Map<String, dynamic> data) {
    String status = data['status'] ?? "";
    String type = data['transaction_type'] ?? "";
    String appId = data['id'];
    String tower = data['tower'] ?? "Tower A";

    String requestType = "Request: New Rental";
    if (type == "Lease Extension") {
      requestType = "Request: Lease Extension";
    } else if (type.contains("Buy")) {
      requestType = "Request: Purchase Unit";
    }

    String tenantMainName = (data['tenantName'] ?? "Unknown Applicant").toString().split(RegExp(r'\n|\r')).first.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
          boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Unit ${data['unit_no']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 5),
          Text(type.contains("Buy") ? "Buyer: $tenantMainName" : "Applicant: $tenantMainName", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          Text(requestType, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Divider(),

          if (type == "Lease Extension" && status == "Pending Owner Approval") ...[
            Row(
              children: [
                Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
                      await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update({
                        "status": "Occupied",
                        "transaction_type": "Rent",
                        "updatedAt": FieldValue.serverTimestamp(),
                        "extension_declined_at": FieldValue.serverTimestamp(),
                        "requested_end_date": FieldValue.delete(),
                        "requested_duration": FieldValue.delete(),
                        "requested_payment": FieldValue.delete(),
                      });
                      Fluttertoast.showToast(msg: "Extension Request Declined.");
                    },
                    child: const Text("Decline")
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _updateAppStatus(appId, "Awaiting Payment", data['tenantUid'], data['unit_no']),
                    child: const Text("Approve")
                )),
              ],
            )
          ] else if (type == "Lease Extension" && status == "Payment Verification Pending") ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                label: const Text("Verify Extension Payment", style: TextStyle(color: Colors.white)),
                onPressed: () => _approveExtensionPayment(appId, data['requested_end_date'] ?? data['contract_end_date'], data['requested_duration'] ?? "Extended"),
              ),
            )
          ] else if (status == "Pending Owner Approval" && type != "Lease Extension") ...[
            Row(
              children: [
                Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _showDeclineDialog(appId, data['tenantUid'], data['unit_no'], tower, type),
                    child: const Text("Decline")
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _updateAppStatus(appId, "Awaiting Payment", data['tenantUid'], data['unit_no']),
                    child: const Text("Approve", style: TextStyle(color: Colors.white))
                )),
              ],
            )
          ] else if (status == "Awaiting Owner Signature") ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.draw, color: Colors.white, size: 18),
                label: const Text("Sign Agreement", style: TextStyle(color: Colors.white)),
                onPressed: () => _updateAppStatus(appId, "Processing Move-in", data['tenantUid'], data['unit_no']),
              ),
            )
          ] else if (status == "Requesting End Contract") ...[
            Row(
              children: [
                Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () => _showDeclineEndContractDialog(appId),
                    child: const Text("Reject")
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: () => _approveEndContract(appId, tower, data['unit_no']),
                    child: const Text("End Contract", style: TextStyle(color: Colors.white))
                )),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildActiveCard(Map<String, dynamic> data) {
    String status = data['status'] ?? "";
    String type = data['transaction_type'] ?? "";

    String tenantMainName = (data['tenantName'] ?? "Unknown Applicant").toString().split(RegExp(r'\n|\r')).first.trim();

    bool isOfficiallyOccupied = status == "Occupied" || status == "Approved & Active";

    String remaining = "";
    if (isOfficiallyOccupied) {
      if (type == "Lease Extension" && (data['contract_end_date'] == null || data['contract_end_date'] == "")) {
        remaining = "Extended by ${data['duration'] ?? 'Unknown'}";
      } else {
        remaining = _calculateRemainingTime(data['contract_end_date']);
      }
    }

    String processInfo = "";
    if (status == "Pending Initial Review") processInfo = "Admin reviewing documents";
    else if (status == "Awaiting Payment") processInfo = "Waiting for tenant's payment";
    else if (status == "Awaiting Admin Payment Verification") processInfo = "Admin verifying payment";
    else if (status == "Processing Move-in") processInfo = "Preparing for move-in";

    if (type == "Lease Extension" && processInfo.isNotEmpty) processInfo = "Extension: $processInfo";
    else if (type.contains("Buy") && processInfo.isNotEmpty) processInfo = "Purchase: $processInfo";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Unit ${data['unit_no']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 5),
          Text(isOfficiallyOccupied ? "Tenant: $tenantMainName" : (type.contains("Buy") ? "Buyer: $tenantMainName" : "Applicant: $tenantMainName"), style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 10),

          if (isOfficiallyOccupied)
            Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 5),
              Text(remaining, style: const TextStyle(fontSize: 13, color: Colors.grey))
            ]),

          if (processInfo.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: isOfficiallyOccupied ? 6.0 : 0.0),
              child: Row(children: [
                const Icon(Icons.sync, size: 14, color: Colors.orange),
                const SizedBox(width: 5),
                Expanded(child: Text(processInfo, style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis))
              ]),
            ),

          if (type == "Lease Extension" && processInfo.isEmpty && isOfficiallyOccupied)
            const Padding(
              padding: EdgeInsets.only(top: 6.0),
              child: Row(children: [
                Icon(Icons.autorenew, size: 14, color: Colors.orange),
                SizedBox(width: 5),
                Text("Extension", style: TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold))
              ]),
            )
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> data) {
    String status = data['status'] ?? "";
    String type = data['transaction_type'] ?? "";

    String displayStatus = status;
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.history;

    if (status == "Extension Approved") {
      displayStatus = "Extension Approved (${data['duration']})";
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
    } else if (status == "Extension Declined" || status == "End Contract Declined") {
      statusColor = Colors.redAccent;
      statusIcon = Icons.cancel;
    } else if (status == "Contract Ended") {
      statusColor = Colors.redAccent;
    } else if (status == "Ownership Transferred") {
      displayStatus = "Unit Sold & Transferred";
      statusColor = Colors.purple;
      statusIcon = Icons.verified_user;
    }

    String tenantMainName = (data['tenantName'] ?? "Unknown Applicant").toString().split(RegExp(r'\n|\r')).first.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle), child: Icon(statusIcon, color: statusColor, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Unit ${data['unit_no']} - $tenantMainName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(displayStatus, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
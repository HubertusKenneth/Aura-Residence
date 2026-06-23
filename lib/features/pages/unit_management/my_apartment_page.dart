import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:my_apart/features/pages/unit_management/unit_booking_steps.dart';
import 'package:my_apart/features/pages/unit_management/owner_dashboard_page.dart';
import 'package:my_apart/features/pages/unit_management/unit_details_page.dart';
import 'package:my_apart/features/pages/billing/billing_page.dart';
import 'package:my_apart/features/pages/billing/billing_detail_page.dart';

class MyApartmentPage extends StatefulWidget {
  const MyApartmentPage({Key? key}) : super(key: key);
  @override
  State<MyApartmentPage> createState() => _MyApartmentPageState();
}

class _MyApartmentPageState extends State<MyApartmentPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  num _overdueTotalCache = 0;
  bool _hasFetchedBills = false;
  DocumentSnapshot? _cachedFirstOverdueDoc;

  int _lockoutDay = 10;

  @override
  void initState() {
    super.initState();
    _fetchDueDate();
    _runSelfHealing();
  }

  Future<void> _runSelfHealing() async {
    try {
      var myApps = await FirebaseFirestore.instance.collection("RentalApplications").where("tenantUid", isEqualTo: uid).get();
      for (var app in myApps.docs) {
        var appData = app.data();
        String status = appData['status'] ?? '';
        String tType = appData['transaction_type'] ?? '';

        if (status == "Occupied" || status == "Approved & Active" || status == "Owned") {
          bool isPerm = tType.contains("Buy") || (appData["duration"] ?? "").toString().contains("Permanent");
          if (isPerm) {
            var check = await FirebaseFirestore.instance.collection("ApartmentUnits")
                .where("tower", isEqualTo: appData['tower'])
                .where("unit_no", isEqualTo: appData['unit_no']).get();
            if (check.docs.isNotEmpty) {
              String currentOwner = check.docs.first.data()['ownerUid'] ?? "";
              if (currentOwner.isNotEmpty && currentOwner != uid) {
                await app.reference.update({"status": "Ownership Transferred"});
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Self Healing Error: $e");
    }
  }

  Future<void> _fetchDueDate() async {
    try {
      var configDoc = await FirebaseFirestore.instance.collection('AppConfig').doc('billing_rates').get();
      if (configDoc.exists) {
        if (mounted) setState(() { _lockoutDay = configDoc.data()?['due_date'] ?? 10; });
      }
    } catch (e) {
      debugPrint("Gagal load due date: $e");
    }
  }

  String getMemberStatusDisplay(String dbStatus) {
    switch (dbStatus) {
      case "Pending Initial Review": return "Awaiting Admin Initial Review";
      case "Awaiting Document Upload": return "Action Required: Upload Docs & Sign";
      case "Pending Admin Doc Verification": return "Awaiting Admin Document Verification";
      case "Pending Owner Approval": return "Awaiting Landlord Approval";
      case "Awaiting Payment": return "Action Required: Complete Payment";
      case "Payment Verification Pending": return "Awaiting Admin Payment Verification";
      case "Awaiting Owner Signature": return "Awaiting Landlord Signature";
      case "Processing Move-in": return "Preparing Move-in";
      case "Cancel Requested": return "Cancellation Requested";
      case "Declined":
      case "Declined by Admin":
      case "Declined by Owner": return "Application Declined";
      case "Occupied": return "Approved & Active";
      case "Contract Ended": return "Contract Ended";
      case "Ownership Transferred": return "Unit Sold & Transferred";
      default: return dbStatus;
    }
  }

  void _showActionDialog(String title, String message, {bool isSuccess = true}) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(25),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 40
                  ),
                ),
                const SizedBox(height: 20),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(message, style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5), textAlign: TextAlign.center),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isSuccess ? Colors.green : Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
    );
  }

  void _showSetPriceDialog(String unitNo, String tower, String applicationId) {
    TextEditingController monthlyCtrl = TextEditingController();
    TextEditingController yearlyCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: const Text("Set Rental Price", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Enter the custom rental price for your unit before publishing it to the catalog.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 15),
                      TextField(controller: monthlyCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Monthly Price", prefixText: "Rp ", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 15),
                      TextField(controller: yearlyCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Yearly Price", prefixText: "Rp ", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826)),
                      onPressed: isSubmitting ? null : () async {
                        if (monthlyCtrl.text.isEmpty || yearlyCtrl.text.isEmpty) { Fluttertoast.showToast(msg: "Please fill in all prices"); return; }
                        setDialogState(() { isSubmitting = true; });
                        try {
                          int customMonthly = int.parse(monthlyCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                          int customYearly = int.parse(yearlyCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

                          var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();
                          if(unitQuery.docs.isNotEmpty) {
                            await unitQuery.docs.first.reference.update({
                              'status': 'Disewakan', 'custom_price_monthly': customMonthly, 'custom_price_yearly': customYearly, 'subleaser_uid': uid, 'residentName': ''
                            });
                            await FirebaseFirestore.instance.collection("RentalApplications").doc(applicationId).update({"is_rented_out": true});
                            Navigator.pop(context);
                            _showActionDialog("Success", "Unit successfully published to catalog!");
                          }
                        } catch (e) {
                          setDialogState(() { isSubmitting = false; });
                          Navigator.pop(context);
                          _showActionDialog("Error", "Failed to publish unit: $e", isSuccess: false);
                        }
                      },
                      child: isSubmitting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Publish Unit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  void _showSellPriceDialog(String unitNo, String tower, String applicationId) {
    TextEditingController sellCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: const Text("Set Selling Price", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Enter the selling price for your unit before publishing it to the catalog.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 15),
                      TextField(controller: sellCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Total Selling Price", prefixText: "Rp ", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: isSubmitting ? null : () async {
                        if (sellCtrl.text.isEmpty) { Fluttertoast.showToast(msg: "Please fill in the selling price"); return; }
                        setDialogState(() { isSubmitting = true; });
                        try {
                          int customSell = int.parse(sellCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

                          var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();
                          if(unitQuery.docs.isNotEmpty) {
                            await unitQuery.docs.first.reference.update({
                              'status': 'Dijual', 'custom_price_sell': customSell, 'subleaser_uid': uid, 'residentName': ''
                            });
                            await FirebaseFirestore.instance.collection("RentalApplications").doc(applicationId).update({"is_rented_out": true});
                            Navigator.pop(context);
                            _showActionDialog("Success", "Unit successfully published for sale in catalog!");
                          }
                        } catch (e) {
                          setDialogState(() { isSubmitting = false; });
                          Navigator.pop(context);
                          _showActionDialog("Error", "Failed to publish unit for sale: $e", isSuccess: false);
                        }
                      },
                      child: isSubmitting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Publish for Sale", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  Future<void> _withdrawUnit(String unitNo, String tower, String applicationId) async {
    try {
      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();
      if(unitQuery.docs.isNotEmpty) {
        var unitData = unitQuery.docs.first.data();
        await unitQuery.docs.first.reference.update({
          'status': 'Terisi',
          'custom_price_monthly': FieldValue.delete(),
          'custom_price_yearly': FieldValue.delete(),
          'custom_price_sell': FieldValue.delete(),
          'subleaser_uid': FieldValue.delete(),
          'residentName': unitData['ownerName']
        });
        await FirebaseFirestore.instance.collection("RentalApplications").doc(applicationId).update({"is_rented_out": false});
        _showActionDialog("Success", "Unit successfully unlisted from catalog.");
      }
    } catch (e) {
      _showActionDialog("Error", "Failed to withdraw unit: $e", isSuccess: false);
    }
  }

  Future<void> _cancelAndRevertUnit(String appId, String tower, String unitNo, String transactionType) async {
    try {
      if (transactionType == "Lease Extension") {
        await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update({
          "status": "Occupied",
          "transaction_type": "Rent",
          "requested_duration": FieldValue.delete(),
          "requested_payment": FieldValue.delete(),
          "requested_end_date": FieldValue.delete(),
          "last_actor": "user",
          "last_action": "cancel_extension",
          "updatedAt": FieldValue.serverTimestamp()
        });

        var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
        if (secQuery.docs.isNotEmpty) {
          String secId = secQuery.docs.first.id;
          await FirebaseFirestore.instance.collection('Secretary').doc(secId).collection('Members').doc(uid).collection('Bookings').doc(appId).update({
            "status": "Occupied",
            "transaction_type": "Rent"
          });
        }
        Fluttertoast.showToast(msg: "Extension Request Cancelled.", backgroundColor: Colors.orange);
      } else {
        var unitQ = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();
        if(unitQ.docs.isNotEmpty) {
          var uData = unitQ.docs.first.data();
          String oUid = uData['ownerUid']?.toString() ?? "";
          String sUid = uData['subleaser_uid']?.toString() ?? "";
          String revertStatus = ((oUid.isNotEmpty && oUid != 'Management') || sUid.isNotEmpty) ? 'Disewakan' : 'Kosong';
          await unitQ.docs.first.reference.update({'status': revertStatus});
        }
        await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update({
          "status": "Cancel",
          "last_actor": "user",
          "last_action": "cancel_new",
          "updatedAt": FieldValue.serverTimestamp()
        });
        Fluttertoast.showToast(msg: "Rental Application Cancelled.", backgroundColor: Colors.orange);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to cancel request: $e", backgroundColor: Colors.red);
    }
  }

  Future<void> _cancelEndContractRequest(String appId) async {
    try {
      await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).update({
        "status": "Occupied",
        "last_actor": "user",
        "last_action": "cancel_end_contract",
        "updatedAt": FieldValue.serverTimestamp()
      });

      var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
      if (secQuery.docs.isNotEmpty) {
        String secId = secQuery.docs.first.id;
        await FirebaseFirestore.instance.collection('Secretary').doc(secId).collection('Members').doc(uid).collection('Bookings').doc(appId).update({"status": "Occupied"});
      }

      Fluttertoast.showToast(msg: "Termination Request Cancelled.", backgroundColor: Colors.orange);
    } catch (e) {
      Fluttertoast.showToast(msg: "Failed to cancel request: $e", backgroundColor: Colors.red);
    }
  }

  void _showCancelConfirmationDialog(String appId, String tower, String unitNo, String transactionType) {
    bool isExtension = transactionType == "Lease Extension";
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(isExtension ? "Cancel Extension?" : "Cancel Request?", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            isExtension
                ? "Are you sure you want to cancel your lease extension request? Your current contract will remain active."
                : "Are you sure you want to cancel this rental application?",
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("No", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _cancelAndRevertUnit(appId, tower, unitNo, transactionType);
                },
                child: const Text("Yes, Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        )
    );
  }

  void _showCancelEndContractDialog(String appId) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Cancel Request?", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            "Are you sure you want to cancel your request? Your lease contract will remain active.",
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("No", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  Navigator.pop(context);
                  _cancelEndContractRequest(appId);
                },
                child: const Text("Yes, Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        )
    );
  }

  void _showDeclineReason(String reason) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Row(children: [Icon(Icons.cancel, color: Colors.red), SizedBox(width: 10), Text("Application Declined", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
          content: Text("Your application was declined for the following reason:\n\n\"$reason\"", style: const TextStyle(height: 1.5, fontSize: 13, color: Colors.black87)),
          actions: [
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                )
            )
          ],
        )
    );
  }

  String formatCurrency(num amount) => "Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";

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
        return "$months Months";
      } else {
        return "$days Days";
      }
    } catch(e) { return "Unknown"; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
          title: const Text('My Applications & Units', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          automaticallyImplyLeading: false
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("RentalApplications").where('tenantUid', isEqualTo: uid).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xffF9A826)));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("You have no unit applications yet.", style: TextStyle(color: Colors.grey)));

            DateTime now = DateTime.now();

            List<Map<String, dynamic>> activeDocs = [];
            List<Map<String, dynamic>> recentDocs = [];
            List<Map<String, dynamic>> historyDocs = [];

            String? primaryUnitNo;

            for (var doc in snapshot.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              var booking = {'id': doc.id, 'docRef': doc.reference, ...data};
              String dbStatus = booking['status'] ?? "";

              if (dbStatus == "Occupied" || dbStatus == "Approved & Active" || dbStatus == "Requesting End Contract" || dbStatus == "Pending Owner Approval" || dbStatus == "Awaiting Payment") {
                if (booking['transaction_type'] != 'Lease Extension' || primaryUnitNo == null) {
                  primaryUnitNo = booking['unit_no'];
                }
              }

              Timestamp? ts = booking['updatedAt'] as Timestamp? ?? booking['timestamp'] as Timestamp?;
              DateTime docDate = ts?.toDate() ?? now;
              Duration diff = now.difference(docDate);

              bool isDeadStatus = dbStatus.contains("Decline") || dbStatus.contains("Cancel") || dbStatus == "Contract Ended" || dbStatus == "Ownership Transferred";

              if (isDeadStatus && diff.inDays >= 7) {
                FirebaseFirestore.instance.collection("RentalApplications").doc(doc.id).delete();
                continue;
              }

              if (!isDeadStatus) {
                activeDocs.add(booking);
              } else {
                if (diff.inHours < 5) {
                  recentDocs.add(booking);
                } else {
                  historyDocs.add(booking);
                }
              }
            }

            activeDocs.sort((a, b) => (b['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(a['timestamp'] as Timestamp? ?? Timestamp.now()));
            recentDocs.sort((a, b) => (b['updatedAt'] as Timestamp? ?? b['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(a['updatedAt'] as Timestamp? ?? a['timestamp'] as Timestamp? ?? Timestamp.now()));
            historyDocs.sort((a, b) => (b['updatedAt'] as Timestamp? ?? b['timestamp'] as Timestamp? ?? Timestamp.now()).compareTo(a['updatedAt'] as Timestamp? ?? a['timestamp'] as Timestamp? ?? Timestamp.now()));

            Widget baseContent = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activeDocs.isNotEmpty) ...[
                  const Text("Active & Ongoing Applications", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 15),
                  ...activeDocs.map((booking) => _buildBookingCard(booking, isHistory: false)).toList(),
                ],

                if (recentDocs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text("Recent Updates", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                  const SizedBox(height: 15),
                  ...recentDocs.map((booking) => _buildBookingCard(booking, isHistory: true)).toList(),
                ],

                if (historyDocs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text("History", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 14)),
                    children: historyDocs.map((booking) => _buildBookingCard(booking, isHistory: true)).toList(),
                  )
                ]
              ],
            );

            if (primaryUnitNo != null) {
              return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection("billing_invoices").where("unit_no", isEqualTo: primaryUnitNo).snapshots(),
                  builder: (context, billSnap) {
                    num totalOverdueAmount = 0;
                    DocumentSnapshot? firstOverdueDoc;

                    String currentPeriod = DateFormat('MMMM yyyy').format(DateTime.now());

                    if (billSnap.hasData && billSnap.data!.docs.isNotEmpty) {
                      for (var doc in billSnap.data!.docs) {
                        var d = doc.data() as Map<String, dynamic>;
                        String period = d['billing_period'] ?? '';
                        String st = d['status'] ?? '';

                        if (period != currentPeriod && (st == "UNPAID" || st == "OVERDUE")) {
                          totalOverdueAmount += (d['total_amount'] ?? 0);
                          if (firstOverdueDoc == null) firstOverdueDoc = doc;
                        }
                      }
                      _overdueTotalCache = totalOverdueAmount;
                      _cachedFirstOverdueDoc = firstOverdueDoc;
                      _hasFetchedBills = true;
                    }

                    Map<String, dynamic>? primaryApp;
                    try { primaryApp = activeDocs.firstWhere((element) => element['unit_no'] == primaryUnitNo && element['transaction_type'] != 'Lease Extension'); } catch(e) {}

                    bool isPermanent = primaryApp != null && (primaryApp['transaction_type'] == 'Buy' || primaryApp['duration'] == 'Permanent (Ownership)');
                    String roleForUnit = isPermanent ? "Owner" : "Tenant";

                    bool shouldLockout = roleForUnit == "Tenant" && totalOverdueAmount > 0 && DateTime.now().day > _lockoutDay;

                    return Stack(
                        children: [
                          SingleChildScrollView(
                            physics: shouldLockout ? const NeverScrollableScrollPhysics() : null,
                            padding: const EdgeInsets.all(20),
                            child: baseContent,
                          ),

                          if (shouldLockout)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black87.withOpacity(0.85),
                                child: Center(
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 30),
                                      padding: const EdgeInsets.all(25),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))]
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.gavel, color: Colors.red, size: 50),
                                            const SizedBox(height: 10),
                                            const Text("Unit Access Suspended", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                                            const SizedBox(height: 15),
                                            Text(
                                              "It is past the $_lockoutDay${_lockoutDay == 1 ? 'st' : _lockoutDay == 2 ? 'nd' : _lockoutDay == 3 ? 'rd' : 'th'} of the month.\n\nYou have an overdue balance of ${formatCurrency(_overdueTotalCache)}.\n\nYour access to the unit and facilities is temporarily restricted. Please settle your overdue bills immediately to restore access.",
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(height: 1.5, fontSize: 13),
                                            ),
                                            const SizedBox(height: 25),
                                            SizedBox(
                                                width: double.infinity,
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      padding: const EdgeInsets.symmetric(vertical: 15),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                                  ),
                                                  icon: const Icon(Icons.payment, color: Colors.white),
                                                  label: const Text("Pay Overdue Bills", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                  onPressed: () {
                                                    if (_cachedFirstOverdueDoc != null) {
                                                      Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                              builder: (_) => BillingDetailPage(
                                                                  invoiceId: _cachedFirstOverdueDoc!.id,
                                                                  invoiceData: _cachedFirstOverdueDoc!.data() as Map<String, dynamic>,
                                                                  isViewOnly: false,
                                                                  isCurrentMonth: false,
                                                                  autoOpenPayment: true
                                                              )
                                                          )
                                                      ).then((_) => setState((){}));
                                                    } else {
                                                      Navigator.push(context, MaterialPageRoute(builder: (_) => BillingPage(unitNo: primaryUnitNo!))).then((_) => setState((){}));
                                                    }
                                                  },
                                                )
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                        ]
                    );
                  }
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: baseContent,
            );
          }
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking, {required bool isHistory}) {
    String appId = booking['id'];
    String dbStatus = booking['status'] ?? "Pending Initial Review";
    String transactionType = booking['transaction_type'] ?? "Rent";
    bool isRentedOut = booking['is_rented_out'] ?? false;

    String displayStatus = getMemberStatusDisplay(dbStatus);
    Color statusColor = Colors.orange;

    if (dbStatus == "Occupied" || dbStatus == "Approved & Active" || dbStatus == "Extension Approved") {
      statusColor = Colors.green;
    } else if (dbStatus.contains("Decline") || dbStatus.contains("Cancel") || dbStatus == "Contract Ended") {
      statusColor = Colors.red;
    } else if (dbStatus == "Ownership Transferred") {
      statusColor = Colors.purple;
    }

    if (transactionType == "Lease Extension") {
      if (dbStatus == "Payment Verification Pending") {
        displayStatus = "Awaiting Landlord Payment Verification";
      } else if (dbStatus == "Pending Owner Approval") {
        displayStatus = "Awaiting Landlord Approval for Extension";
      } else if (dbStatus == "Awaiting Payment") {
        displayStatus = "Extension Approved! Complete Payment";
        statusColor = Colors.green;
      }
    }

    String contractDate = booking['contract_end_date'] ?? "";
    if (contractDate.isNotEmpty && contractDate != "Permanent") {
      try { DateTime dt = DateTime.parse(contractDate); contractDate = "Ends: ${dt.day}/${dt.month}/${dt.year}"; } catch(e) {}
    } else if (contractDate == "Permanent") {
      contractDate = "Permanent";
    }

    String displayDuration = "";
    if (dbStatus == "Occupied" || dbStatus == "Approved & Active") {
      displayDuration = _calculateRemainingTime(booking['contract_end_date']);
      if (displayDuration == "Permanent" || transactionType == "Buy") {
        displayDuration = "Ownership";
      } else {
        displayDuration = "Active Tenant • $displayDuration";
      }
    } else {
      if (transactionType == "Buy") {
        displayDuration = "Ownership";
      } else if (transactionType == "Lease Extension") {
        displayDuration = "Extension (${booking['requested_duration']})";
      } else {
        displayDuration = booking['duration'] ?? "Monthly";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isHistory ? Colors.grey.shade300 : const Color(0xffF9A826).withOpacity(0.5),
              width: 1.5
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            decoration: BoxDecoration(
                color: isHistory ? Colors.grey.shade50 : const Color(0xffF9A826).withOpacity(0.05),
                border: Border(bottom: BorderSide(color: isHistory ? Colors.grey.shade200 : const Color(0xffF9A826).withOpacity(0.2)))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Unit ${booking['unit_no']}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withOpacity(0.4))
                    ),
                    child: Text(displayStatus, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold))
                )
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          "${booking['tower']} • $displayDuration",
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (contractDate.isNotEmpty && (!isHistory || dbStatus == "Extension Approved"))
                        Text(contractDate, style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold))
                    ]
                ),

                if (!isHistory) ...[
                  const SizedBox(height: 15),

                  if (dbStatus == "Awaiting Document Upload") ...[
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826)), icon: const Icon(Icons.upload_file, color: Colors.white, size: 18), label: const Text("Upload Docs & Agree to Lease", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => UnitBookingSteps(applicationData: booking, uid: uid, applicationId: appId)));
                    })),
                    TextButton(onPressed: () => _showCancelConfirmationDialog(appId, booking['tower'], booking['unit_no'], transactionType), child: const Text("Cancel", style: TextStyle(color: Colors.red)))

                  ] else if (dbStatus == "Awaiting Payment") ...[
                    SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), icon: const Icon(Icons.payment, color: Colors.white, size: 18), label: const Text("Complete Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentPage(applicationData: booking, uid: uid, applicationId: appId)));
                    })),
                    TextButton(onPressed: () => _showCancelConfirmationDialog(appId, booking['tower'], booking['unit_no'], transactionType), child: const Text("Request Cancel", style: TextStyle(color: Colors.red)))

                  ] else if (dbStatus == "Pending Initial Review" || dbStatus == "Pending Admin Doc Verification" || dbStatus == "Pending Owner Approval") ...[
                    SizedBox(width: double.infinity, child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), onPressed: () => _showCancelConfirmationDialog(appId, booking['tower'], booking['unit_no'], transactionType), child: const Text("Cancel Request", style: TextStyle(fontWeight: FontWeight.bold))))

                  ] else if (dbStatus == "Payment Verification Pending" || dbStatus == "Awaiting Owner Signature" || dbStatus == "Processing Move-in") ...[
                    SizedBox(width: double.infinity, child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.grey, side: BorderSide(color: Colors.grey.shade300)),
                        onPressed: null,
                        icon: const Icon(Icons.hourglass_top, size: 18),
                        label: const Text("Processing Request...", style: TextStyle(fontWeight: FontWeight.bold))
                    ))

                  ] else if (dbStatus == "Occupied" || dbStatus == "Approved & Active" || dbStatus == "Requesting End Contract") ...[
                    if (transactionType == "Rent" || transactionType == "Lease Extension")
                      FutureBuilder<QuerySnapshot>(
                          future: FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: booking['tower']).where('unit_no', isEqualTo: booking['unit_no']).get(),
                          builder: (context, snapshot) {
                            return SizedBox(width: double.infinity, child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                                icon: const Icon(Icons.info_outline, color: Colors.white, size: 18),
                                label: const Text("View Unit Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => UnitDetailsPage(unitData: snapshot.data!.docs.first.data() as Map<String, dynamic>))).then((_) => setState((){}));
                                  } else {
                                    Fluttertoast.showToast(msg: "Loading details...");
                                  }
                                }
                            ));
                          }
                      )
                    else if (transactionType == "Buy") ...[
                      SizedBox(width: double.infinity, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey), icon: const Icon(Icons.description, color: Colors.white, size: 18), label: const Text("View Unit Certificate", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), onPressed: () { Fluttertoast.showToast(msg: "Opening Ownership Certificate..."); })),
                      const SizedBox(height: 10),

                      StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('ApartmentUnits')
                              .where('tower', isEqualTo: booking['tower'])
                              .where('unit_no', isEqualTo: booking['unit_no'])
                              .snapshots(),
                          builder: (context, unitSnapshot) {

                            bool isCataloged = isRentedOut;
                            bool isReservedOrOccupied = false;
                            String btnText = "Rent Out / Sell Unit";

                            if (unitSnapshot.hasData && unitSnapshot.data!.docs.isNotEmpty) {
                              var uData = unitSnapshot.data!.docs.first.data() as Map<String, dynamic>;
                              String uStatus = uData['status'] ?? "";
                              String rUid = (uData['residentUid'] ?? "").toString().trim();

                              if (uStatus == "Reserved") {
                                isCataloged = true;
                                isReservedOrOccupied = true;
                                btnText = "Unit Reserved (Check Dashboard)";
                              } else if (uStatus == "Terisi" && rUid.isNotEmpty && rUid != uid) {
                                isCataloged = true;
                                isReservedOrOccupied = true;
                                btnText = "Unit Occupied by Tenant";
                              } else if (uStatus == "Disewakan" || uStatus == "Dijual") {
                                isCataloged = true;
                                btnText = "Unlist (Remove from Catalog)";
                              } else {
                                isCataloged = false;
                                btnText = "Manage Unit Listing";
                              }
                            }

                            return Column(
                              children: [
                                if (isCataloged && !isReservedOrOccupied)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        icon: const Icon(Icons.cancel),
                                        label: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        onPressed: () => _withdrawUnit(booking['unit_no'], booking['tower'], appId)
                                    ),
                                  )
                                else if (isReservedOrOccupied)
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.orange.shade700,
                                          side: BorderSide(color: Colors.orange.shade700),
                                        ),
                                        icon: const Icon(Icons.lock),
                                        label: Text(btnText, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboardPage()))
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.blue,
                                            side: const BorderSide(color: Colors.blue),
                                          ),
                                          icon: const Icon(Icons.real_estate_agent),
                                          label: const Text("Rent Out", style: TextStyle(fontWeight: FontWeight.bold)),
                                          onPressed: () => _showSetPriceDialog(booking['unit_no'], booking['tower'], appId),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.green,
                                            side: const BorderSide(color: Colors.green),
                                          ),
                                          icon: const Icon(Icons.sell),
                                          label: const Text("Sell Unit", style: TextStyle(fontWeight: FontWeight.bold)),
                                          onPressed: () => _showSellPriceDialog(booking['unit_no'], booking['tower'], appId),
                                        ),
                                      )
                                    ],
                                  ),
                              ],
                            );
                          }
                      ),
                    ],

                    if (dbStatus == "Requesting End Contract") ...[
                      const SizedBox(height: 10),
                      SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                              onPressed: () => _showCancelEndContractDialog(appId),
                              child: const Text("Cancel Request", style: TextStyle(fontWeight: FontWeight.bold))
                          )
                      )
                    ]
                  ]
                ] else ...[
                  if (dbStatus == "Declined" || dbStatus == "Declined by Admin" || dbStatus == "Declined by Owner") ...[
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, elevation: 0),
                            icon: const Icon(Icons.info_outline, color: Colors.red, size: 18),
                            label: const Text("View Reason", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              String reason = booking['reject_reason'] ?? booking['decline_reason'] ?? 'No reason provided.';
                              _showDeclineReason(reason);
                            }
                        )
                    ),
                  ],
                  if (!appId.contains("_ext_") && !appId.contains("_end_"))
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () async { await FirebaseFirestore.instance.collection("RentalApplications").doc(appId).delete(); Fluttertoast.showToast(msg: "History Record Deleted.", backgroundColor: Colors.grey); }, child: const Text("Delete Record", style: TextStyle(color: Colors.grey, fontSize: 12))),
                      ],
                    )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}
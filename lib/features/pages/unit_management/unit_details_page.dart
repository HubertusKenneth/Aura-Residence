import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:my_apart/features/pages/unit_management/unit_contract_extension_page.dart';
import 'package:my_apart/features/pages/billing/billing_page.dart';

class UnitDetailsPage extends StatefulWidget {
  final Map<String, dynamic> unitData;

  const UnitDetailsPage({Key? key, required this.unitData}) : super(key: key);

  @override
  State<UnitDetailsPage> createState() => _UnitDetailsPageState();
}

class _UnitDetailsPageState extends State<UnitDetailsPage> {
  bool isManagingResidents = false;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  String unitType = "Loading...";
  String ownerNameDisplay = "Loading...";
  bool isCurrentlyRentedToOther = false;

  bool isPrimaryResident = false;
  bool isSharedMember = false;
  bool isOwner = false;
  bool isTenant = false;

  bool isRequestingEndContract = false;
  bool isRequestingExtension = false;

  Map<String, dynamic> memberPermissions = {};
  String sharedRole = "";

  String realDuration = "";
  String realEndDate = "";
  String realTransactionType = "";

  bool isListedForSale = false;
  bool isListedForRent = false;

  @override
  void initState() {
    super.initState();
    _fetchMasterUnitData();
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  Future<void> _fetchMasterUnitData() async {
    try {
      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits')
          .where('tower', isEqualTo: widget.unitData['tower'])
          .where('unit_no', isEqualTo: widget.unitData['unit_no']).get();

      if (unitQuery.docs.isNotEmpty) {
        var dbData = unitQuery.docs.first.data();

        isSharedMember = widget.unitData['isSharedMember'] == true;
        isPrimaryResident = !isSharedMember;

        String ownerUid = dbData['ownerUid'] ?? '';
        String subUid = dbData['subleaser_uid'] ?? '';
        String dbStatus = dbData['status'] ?? '';

        isOwner = (_uid == ownerUid) && !isSharedMember;
        isTenant = isPrimaryResident && !isOwner;

        if (isSharedMember) {
          var accessQuery = await FirebaseFirestore.instance.collection('unit_access_members')
              .where('unit_no', isEqualTo: widget.unitData['unit_no'])
              .where('user_uid', isEqualTo: _uid)
              .get();

          if (accessQuery.docs.isNotEmpty) {
            var accData = accessQuery.docs.first.data();
            sharedRole = accData['role'] ?? 'Limited Access';
            memberPermissions = accData['permissions'] ?? {};
          }
        }

        realTransactionType = widget.unitData['transaction_type'] ?? '';
        realDuration = widget.unitData['duration'] ?? 'Monthly';
        realEndDate = widget.unitData['contract_end_date'] ?? 'Permanent';

        String userAppStatus = widget.unitData['status'] ?? '';
        isRequestingEndContract = userAppStatus == 'Requesting End Contract';
        isRequestingExtension = userAppStatus == 'Pending Owner Approval' || userAppStatus == 'Awaiting Payment';

        isListedForRent = dbStatus == 'Disewakan';
        isListedForSale = dbStatus == 'Dijual';

        bool rentedToOther = false;

        if (isOwner) {
          if ((dbStatus == 'Terisi' || dbStatus == 'Reserved') && subUid == _uid) {
            rentedToOther = true;
          }
        }

        setState(() {
          unitType = dbData['type'] ?? "Studio";
          ownerNameDisplay = (dbData['ownerName'] != null && dbData['ownerName'].toString().isNotEmpty)
              ? dbData['ownerName'].toString().split('\n').first
              : "Apartment Management";
          isCurrentlyRentedToOther = rentedToOther;
        });
      } else {
        setState(() { unitType = "Studio"; ownerNameDisplay = "Apartment Management"; });
      }
    } catch (e) {
      setState(() { unitType = "Unknown"; ownerNameDisplay = "Unknown"; });
    }
  }

  Future<void> _openResidentManager() async {
    setState(() { isManagingResidents = true; });

    try {
      String userPhone = "";
      String userName = "";

      var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
      for(var doc in secQuery.docs) {
        var member = await doc.reference.collection("Members").doc(_uid).get();
        if(member.exists && member.data() != null) {
          userPhone = member.data()?['Phone'] ?? "";
          userName = member.data()?['Name'] ?? "";
          break;
        }
      }

      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits')
          .where('tower', isEqualTo: widget.unitData['tower'])
          .where('unit_no', isEqualTo: widget.unitData['unit_no']).get();

      if (unitQuery.docs.isEmpty) {
        Fluttertoast.showToast(msg: "Unit not found in database.");
        setState(() { isManagingResidents = false; });
        return;
      }

      var unitDoc = unitQuery.docs.first;
      var dbUnitData = unitDoc.data();

      bool isPermanentOwner = _uid == dbUnitData['ownerUid'];
      String dbStatus = dbUnitData['status'] ?? '';
      String subUid = dbUnitData['subleaser_uid'] ?? '';

      bool lockedForOwner = false;
      if (isPermanentOwner && (dbStatus == 'Terisi' || dbStatus == 'Reserved') && subUid == _uid) {
        lockedForOwner = true;
      }

      String rawNames = dbUnitData['residentName'] ?? "";
      String rawPhones = dbUnitData['residentPhone'] ?? "";

      if (rawNames.isEmpty && !lockedForOwner) {
        rawNames = userName;
        rawPhones = userPhone;
      }

      List<String> currentNames = rawNames.isNotEmpty ? rawNames.split('\n') : [];
      List<String> currentPhones = rawPhones.isNotEmpty ? rawPhones.split('\n') : [];

      setState(() { isManagingResidents = false; });

      List<TextEditingController> nameCtrls = [];
      List<TextEditingController> phoneCtrls = [];

      for(int i = 0; i < currentNames.length; i++) {
        nameCtrls.add(TextEditingController(text: currentNames[i]));
        phoneCtrls.add(TextEditingController(text: i < currentPhones.length ? currentPhones[i] : ''));
      }

      if (nameCtrls.isEmpty) {
        nameCtrls.add(TextEditingController(text: lockedForOwner ? "No Tenant Data" : userName));
        phoneCtrls.add(TextEditingController(text: lockedForOwner ? "-" : userPhone));
      }

      bool isSaving = false;
      bool isReadOnlyView = lockedForOwner || isSharedMember;

      if (!mounted) return;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(lockedForOwner ? "Tenant Information" : "Resident List", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          if (!isReadOnlyView)
                            IconButton(icon: const Icon(Icons.group_add, color: Color(0xffF9A826)), onPressed: () { setDialogState(() { nameCtrls.add(TextEditingController()); phoneCtrls.add(TextEditingController()); }); })
                        ],
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      content: SizedBox(
                        width: double.maxFinite,
                        child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: nameCtrls.length,
                            itemBuilder: (context, index) {
                              bool isPrimary = index == 0;
                              return Card(
                                elevation: 0, margin: const EdgeInsets.only(bottom: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(isPrimary ? (lockedForOwner ? "Active Tenant" : "Primary Resident") : "Co-Resident ${index + 1}", style: TextStyle(fontWeight: FontWeight.bold, color: isPrimary ? Colors.blue : Colors.grey.shade700, fontSize: 12)),
                                          if (!isPrimary && !isReadOnlyView)
                                            GestureDetector(onTap: () { setDialogState(() { nameCtrls.removeAt(index); phoneCtrls.removeAt(index); }); }, child: const Icon(Icons.delete_outline, color: Colors.red, size: 18))
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      if (isReadOnlyView) ...[
                                        Container(
                                          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Full Name", style: TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 2),
                                              Text(nameCtrls[index].text.isEmpty ? "-" : nameCtrls[index].text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)), const SizedBox(height: 8),
                                              const Text("Phone Number", style: TextStyle(fontSize: 10, color: Colors.grey)), const SizedBox(height: 2),
                                              Text(phoneCtrls[index].text.isEmpty ? "-" : phoneCtrls[index].text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                            ],
                                          ),
                                        )
                                      ] else ...[
                                        TextField(controller: nameCtrls[index], decoration: const InputDecoration(labelText: "Full Name", isDense: true)), const SizedBox(height: 10),
                                        TextField(controller: phoneCtrls[index], keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Phone Number", isDense: true)),
                                      ]
                                    ],
                                  ),
                                ),
                              );
                            }
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: isSaving ? null : () => Navigator.pop(context), child: Text(isReadOnlyView ? "Close" : "Cancel", style: const TextStyle(color: Colors.grey))),
                        if (!isReadOnlyView)
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826)),
                              onPressed: isSaving ? null : () async {
                                bool isValid = true;
                                for (int i = 0; i < nameCtrls.length; i++) { if (nameCtrls[i].text.trim().isEmpty || phoneCtrls[i].text.trim().isEmpty) isValid = false; }
                                if (!isValid) { Fluttertoast.showToast(msg: "All resident fields must be filled."); return; }
                                setDialogState(() { isSaving = true; });
                                String finalNames = nameCtrls.map((c) => c.text.trim()).join('\n');
                                String finalPhones = phoneCtrls.map((c) => c.text.trim()).join('\n');
                                await unitDoc.reference.update({'residentName': finalNames, 'residentPhone': finalPhones});
                                Fluttertoast.showToast(msg: "Resident list updated successfully!");
                                Navigator.pop(context);
                              },
                              child: isSaving ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Save List", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                          )
                      ]
                  );
                }
            );
          }
      );
    } catch (e) {
      setState(() { isManagingResidents = false; });
      Fluttertoast.showToast(msg: "Error loading data: $e");
    }
  }

  void _showEndContractConfirmation(String unitNo) {
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 10),
              Text("End Contract?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 18)),
            ],
          ),
          content: const Text(
            "Are you sure you want to request an early termination of your lease?\n\nThis will notify the management/landlord. You will not lose access until they approve the request.",
            style: TextStyle(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  var appQuery = await FirebaseFirestore.instance.collection("RentalApplications")
                      .where("tenantUid", isEqualTo: _uid)
                      .where("unit_no", isEqualTo: unitNo)
                      .where("status", whereIn: ["Occupied", "Approved & Active"])
                      .get();

                  if (appQuery.docs.isNotEmpty) {
                    await appQuery.docs.first.reference.update({
                      "status": "Requesting End Contract",
                      "updatedAt": FieldValue.serverTimestamp()
                    });

                    var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
                    if (secQuery.docs.isNotEmpty) {
                      String secId = secQuery.docs.first.id;
                      await FirebaseFirestore.instance.collection('Secretary').doc(secId)
                          .collection('Members').doc(_uid).collection('Bookings').doc(appQuery.docs.first.id)
                          .update({'status': 'Requesting End Contract'});
                    }

                    Fluttertoast.showToast(msg: "Termination request sent to Management.");
                    if (mounted) Navigator.pop(context);
                  } else {
                    Fluttertoast.showToast(msg: "No active contract found.");
                  }
                } catch(e) {
                  Fluttertoast.showToast(msg: "Failed to request termination.");
                }
              },
              child: const Text("Yes, Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
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
        int months = days ~/ 30; int remainDays = days % 30;
        return remainDays == 0 ? "$months months remaining" : "$months mo $remainDays days remaining";
      } else {
        return "$days days remaining";
      }
    } catch(e) { return "Unknown"; }
  }

  @override
  Widget build(BuildContext context) {
    String unitNo = widget.unitData['unit_no'] ?? "Unknown";
    String tower = widget.unitData['tower'] ?? "Unknown Tower";

    bool isPermanentInfo = isOwner || realDuration.contains('Permanent') || realTransactionType.contains('Buy');
    if (isTenant) {
      isPermanentInfo = false;
    }

    String displayDuration;
    if (isPermanentInfo) {
      displayDuration = "Permanent (Ownership)";
    } else {
      displayDuration = _calculateRemainingTime(realEndDate);
    }

    return Scaffold(
      backgroundColor: const Color(0xffF5F6F8),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black87), title: const Text("Unit Information", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange.shade400, Colors.deepOrange.shade500], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)), child: Text(isPermanentInfo ? "Owned Unit" : "Currently Occupied", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 15),
                  Text("Unit $unitNo", style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Row(children: [const Icon(Icons.location_city, color: Colors.white70, size: 16), const SizedBox(width: 5), Text(tower, style: const TextStyle(color: Colors.white, fontSize: 14))])
                ],
              ),
            ),

            const SizedBox(height: 25),
            const Text("Unit Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _buildDetailItem(Icons.apartment, "Unit Type", unitType),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _buildDetailItem(Icons.person_outline, "Owner / Landlord", ownerNameDisplay),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                  _buildDetailItem(isPermanentInfo ? Icons.verified : Icons.timelapse, isPermanentInfo ? "Lease Duration" : "Lease Duration Remaining", displayDuration),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),

                  if (isPermanentInfo)
                    _buildActionDetailItem(Icons.description, "Ownership Certificate", "View Certificate", () { Fluttertoast.showToast(msg: "Opening Ownership Certificate..."); })
                  else
                    _buildActionDetailItem(Icons.vpn_key_outlined, "Passcode / Check-in", "View Instructions", () { Fluttertoast.showToast(msg: "Passcode: 123456. Please take the key at the Lobby."); }),
                ],
              ),
            ),

            const SizedBox(height: 25),
            const Text("Additional Features", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 15),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  _buildFeatureItem(
                      (isCurrentlyRentedToOther || isSharedMember) ? Icons.visibility : Icons.group_add,
                      (isCurrentlyRentedToOther || isSharedMember) ? Colors.blueGrey : Colors.orange,
                      (isCurrentlyRentedToOther || isSharedMember) ? "View Resident Data" : "Manage Resident Data",
                      (isCurrentlyRentedToOther || isSharedMember) ? "View the details of active residents." : "Add or update family members/roommates",
                          () { if (!isManagingResidents) _openResidentManager(); }
                  ),

                  if (isPrimaryResident && isTenant) ...[
                    if (!isRequestingExtension && !isRequestingEndContract) ...[
                      const Divider(height: 1),
                      _buildFeatureItem(Icons.more_time, Colors.blue, "Request Lease Extension", "Extend your stay in Unit $unitNo", () { Navigator.push(context, MaterialPageRoute(builder: (_) => UnitContractExtensionPage(unitNo: unitNo))); }),
                      const Divider(height: 1),
                      _buildFeatureItem(
                          Icons.exit_to_app,
                          Colors.red,
                          "Request End Contract",
                          "Submit a request to terminate your lease",
                              () => _showEndContractConfirmation(unitNo)
                      ),
                    ] else ...[
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.hourglass_top, color: Colors.orange)),
                        title: const Text("Request in Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange)),
                        subtitle: const Text("You have a pending contract update request.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    ]
                  ],

                  if (isPrimaryResident || (isSharedMember && sharedRole == "Resident Member" && memberPermissions['Can View Bills'] == true)) ...[
                    const Divider(height: 1),
                    _buildFeatureItem(Icons.receipt_long, Colors.green, "View Payment History", "Check all your past invoices and receipts", () { Navigator.push(context, MaterialPageRoute(builder: (_) => BillingPage(unitNo: unitNo))); }),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 22), const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87))]))
      ],
    );
  }

  Widget _buildActionDetailItem(IconData icon, String title, String actionText, VoidCallback onTap) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 22), const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), GestureDetector(onTap: onTap, child: Text(actionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue, decoration: TextDecoration.underline)))]))
      ],
    );
  }

  Widget _buildFeatureItem(IconData icon, Color iconColor, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
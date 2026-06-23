import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class UnitContractExtensionPage extends StatefulWidget {
  final String unitNo;
  const UnitContractExtensionPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<UnitContractExtensionPage> createState() => _UnitContractExtensionPageState();
}

class _UnitContractExtensionPageState extends State<UnitContractExtensionPage> {
  int selectedMonths = 6;
  bool isSubmitting = false;

  final int basePricePerMonth = 5000000;

  late Future<Map<String, dynamic>> _contractDataFuture;

  @override
  void initState() {
    super.initState();
    _contractDataFuture = _getContractData();
  }

  Map<String, int> _calculatePrice(int months) {
    int baseTotal = months * basePricePerMonth;
    int discount = 0;

    if (months >= 12) {
      discount = ((months / 12).floor() * 10000000) + ((months % 12) >= 6 ? 2000000 : 0);
    } else if (months >= 6) {
      discount = 2000000;
    }

    return {
      'base': baseTotal,
      'discount': discount,
      'total': baseTotal - discount,
    };
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  Future<Map<String, dynamic>> _getContractData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      var query = await FirebaseFirestore.instance.collection('RentalApplications')
          .where('tenantUid', isEqualTo: uid)
          .where('unit_no', isEqualTo: widget.unitNo)
          .get();

      if (query.docs.isNotEmpty) {
        var validDocs = query.docs.where((doc) {
          String status = (doc.data()['status'] ?? "").toString().trim().toLowerCase();
          return status == 'occupied' || status == 'approved & active' || status == 'owned' || status == 'awaiting payment' || status == 'pending owner approval';
        }).toList();

        if (validDocs.isEmpty) {
          return {'status': 'not_found', 'text': 'No active contract status', 'daysLeft': 0};
        }

        validDocs.sort((a,b) {
          Timestamp tA = a.data()['updatedAt'] as Timestamp? ?? a.data()['timestamp'] as Timestamp? ?? Timestamp(0,0);
          Timestamp tB = b.data()['updatedAt'] as Timestamp? ?? b.data()['timestamp'] as Timestamp? ?? Timestamp(0,0);
          return tB.compareTo(tA);
        });

        var data = validDocs.first.data();
        String endDateStr = (data['contract_end_date'] ?? "").toString().trim();
        String transTypeStr = (data['transaction_type'] ?? "").toString().trim().toLowerCase();
        String durationStr = (data['duration'] ?? "").toString().trim().toLowerCase();

        if (endDateStr.isEmpty || endDateStr.toLowerCase() == "permanent" || durationStr.contains("permanent") || transTypeStr == "buy") {
          return {'status': 'permanent', 'text': 'Permanent / Owned', 'daysLeft': 999, 'docId': validDocs.first.id, 'unitData': data};
        }

        DateTime end;
        try {
          end = DateTime.parse(endDateStr);
        } catch (e) {
          return {'status': 'error', 'text': 'Invalid Date Format', 'daysLeft': 0};
        }

        DateTime now = DateTime.now();
        int days = end.difference(now).inDays;

        if (days < 0) return {'status': 'expired', 'text': 'Expired', 'daysLeft': days, 'docId': validDocs.first.id, 'unitData': data, 'rawDate': endDateStr};

        String remaining = "";
        if (days >= 30) {
          int months = days ~/ 30; int remainDays = days % 30;
          remaining = remainDays == 0 ? "$months months left" : "$months mo $remainDays days left";
        } else { remaining = "$days days left"; }

        return {'status': 'active', 'date': endDateStr.split('T')[0], 'text': remaining, 'daysLeft': days, 'rawDate': endDateStr, 'docId': validDocs.first.id, 'unitData': data};
      }
      return {'status': 'not_found', 'text': 'Data not found in database', 'daysLeft': 0};
    } catch (e) {
      return {'status': 'error', 'text': 'System Error', 'daysLeft': 0};
    }
  }

  void _showSubmitConfirmationDialog() {
    if (selectedMonths < 1) {
      Fluttertoast.showToast(msg: "Please select a valid duration.");
      return;
    }

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Confirm Extension", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to request a lease extension for $selectedMonths Months? This request will be sent to the Management for approval.",
            style: const TextStyle(color: Colors.black87, height: 1.4),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826)),
                onPressed: () {
                  Navigator.pop(context);
                  _submitExtension();
                },
                child: const Text("Yes, Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        )
    );
  }

  void _submitExtension() async {
    setState(() { isSubmitting = true; });
    try {
      var contractMap = await _getContractData();

      if (contractMap['status'] == 'not_found' || contractMap['status'] == 'error' || contractMap['docId'] == null) {
        Fluttertoast.showToast(msg: "Failed: ${contractMap['text']}");
        setState(() { isSubmitting = false; });
        return;
      }

      if (contractMap['status'] == 'permanent') {
        Fluttertoast.showToast(msg: "This unit is permanently owned. No extension needed.");
        setState(() { isSubmitting = false; });
        return;
      }

      String docId = contractMap['docId'];

      DateTime baseDate = DateTime.now();
      if (contractMap['rawDate'] != null) {
        try { baseDate = DateTime.parse(contractMap['rawDate']); } catch (e) {}
      }

      DateTime newEndDate = DateTime(baseDate.year, baseDate.month + selectedMonths, baseDate.day);
      int finalPrice = _calculatePrice(selectedMonths)['total']!;

      String statusApproval = "Pending Owner Approval";

      await FirebaseFirestore.instance.collection("RentalApplications").doc(docId).update({
        "requested_duration": "$selectedMonths Months",
        "requested_payment": finalPrice,
        "total_payment": finalPrice,
        "transaction_type": "Lease Extension",
        "requested_end_date": newEndDate.toIso8601String(),
        "status": statusApproval,
        "last_actor": "user",
        "last_action": "request_extension",
        "updatedAt": FieldValue.serverTimestamp(),
      });

      var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
      if (secQuery.docs.isNotEmpty) {
        String uid = FirebaseAuth.instance.currentUser!.uid;
        String secId = secQuery.docs.first.id;
        await FirebaseFirestore.instance.collection('Secretary').doc(secId)
            .collection('Members').doc(uid).collection('Bookings').doc(docId)
            .update({'status': statusApproval, 'transaction_type': 'Lease Extension'});
      }

      Fluttertoast.showToast(msg: "Extension request sent to Management for approval!");

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch(e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      if (mounted) setState(() { isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Extend Lease", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
          future: _contractDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xffF9A826)));
            }

            var cData = snapshot.data ?? {'status': 'error', 'text': 'System Error', 'daysLeft': 0};
            int daysLeft = cData['daysLeft'] ?? 0;
            bool isExpiringSoon = daysLeft <= 30 && daysLeft > 0 && cData['status'] == 'active';

            if (cData['status'] == 'not_found' || cData['status'] == 'error') {
              return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                      const SizedBox(height: 15),
                      Text(cData['text'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 5),
                      const Text("Please contact management if this persists.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  )
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.blueGrey.shade700, Colors.blueGrey.shade900]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.blueGrey.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Current Contract", style: TextStyle(color: Colors.white70, fontSize: 13)),
                            if (isExpiringSoon)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.redAccent)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 12),
                                    SizedBox(width: 4),
                                    Text("Expiring Soon", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              )
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text("Unit ${widget.unitNo}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                        const Divider(color: Colors.white24, height: 30),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(cData['status'] == 'permanent' ? "Permanent Ownership" : "Ends on: ${cData['date'] ?? '-'}", style: const TextStyle(color: Colors.white))),
                            Text(cData['text'], style: TextStyle(color: isExpiringSoon ? Colors.redAccent : const Color(0xffF9A826), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isExpiringSoon)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Text("⚠️ Renew your contract now to avoid losing your unit.", style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(height: 35),

                  if (cData['status'] != 'permanent') ...[
                    const Text("Select Duration", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),

                    Row(
                      children: [
                        Expanded(child: _buildPresetCard(3)),
                        const SizedBox(width: 15),
                        Expanded(child: _buildPresetCard(6)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildPresetCard(12, isBestValue: true),

                    const SizedBox(height: 20),
                    const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("OR", style: TextStyle(color: Colors.grey, fontSize: 12))), Expanded(child: Divider())]),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: ![3, 6, 12].contains(selectedMonths) ? const Color(0xffF9A826) : Colors.grey.shade300, width: ![3, 6, 12].contains(selectedMonths) ? 2 : 1)
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit_calendar, color: Colors.grey, size: 20),
                          const SizedBox(width: 15),
                          const Text("Other: ", style: TextStyle(color: Colors.grey, fontSize: 14)),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: selectedMonths,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                                items: List.generate(12, (index) => index + 1).map((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text(
                                        "$value Months",
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)
                                    ),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  if (newValue != null) {
                                    setState(() { selectedMonths = newValue; });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),

                    const Text("Payment Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),

                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
                          border: Border.all(color: Colors.grey.shade100)
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow("Duration", "$selectedMonths Months"),
                          const SizedBox(height: 10),
                          _buildSummaryRow("Base Price", "${formatCurrency(basePricePerMonth)} / mo"),
                          const SizedBox(height: 10),

                          Builder(
                              builder: (context) {
                                var pricing = _calculatePrice(selectedMonths);
                                return Column(
                                  children: [
                                    _buildSummaryRow("Subtotal", formatCurrency(pricing['base']!)),
                                    if (pricing['discount']! > 0) ...[
                                      const SizedBox(height: 10),
                                      _buildSummaryRow("Long-term Discount", "- ${formatCurrency(pricing['discount']!)}", isDiscount: true),
                                    ],
                                    const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text("Total Estimated", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(formatCurrency(pricing['total']!), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xffF9A826))),
                                      ],
                                    )
                                  ],
                                );
                              }
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text("This unit is permanently owned. There is no need for lease extensions.", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey, fontSize: 16)),
                      ),
                    )
                  ]
                ],
              ),
            );
          }
      ),

      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))]
        ),
        child: SafeArea(
          child: SizedBox(
            height: 55, width: double.infinity,
            child: FutureBuilder<Map<String, dynamic>>(
                future: _contractDataFuture,
                builder: (context, snapshot) {
                  bool isPerm = snapshot.data?['status'] == 'permanent';
                  if (isPerm) return const SizedBox.shrink();

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffF9A826),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0
                    ),
                    onPressed: isSubmitting ? null : _showSubmitConfirmationDialog,
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Submit Extension Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  );
                }
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isDiscount ? Colors.green : Colors.black87, fontSize: 14)),
      ],
    );
  }

  Widget _buildPresetCard(int months, {bool isBestValue = false}) {
    bool isSelected = selectedMonths == months;
    var pricing = _calculatePrice(months);

    return GestureDetector(
      onTap: () {
        setState(() { selectedMonths = months; });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xffF9A826).withOpacity(0.08) : Colors.white,
            border: Border.all(color: isSelected ? const Color(0xffF9A826) : Colors.grey.shade200, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(15),
            boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))]
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("$months Months", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? const Color(0xffF9A826) : Colors.black87)),
                    if (isSelected) const Icon(Icons.check_circle, color: Color(0xffF9A826), size: 18)
                  ],
                ),
                const SizedBox(height: 8),
                Text(formatCurrency(pricing['total']!), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                if (pricing['discount']! > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text("Save ${formatCurrency(pricing['discount']!)}", style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
            if (isBestValue)
              Positioned(
                top: -25, right: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                  child: const Text("🔥 Best Value", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              )
          ],
        ),
      ),
    );
  }
}
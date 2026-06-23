import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'billing_detail_page.dart';
import 'late_fee_info_page.dart';

class BillingPage extends StatefulWidget {
  final String unitNo;
  const BillingPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  final Color colorPrimary = const Color(0xffF59E0B);
  final Color colorSecondary = const Color(0xff1E293B);
  final Color colorSuccess = Colors.green.shade600;
  final Color colorWarning = Colors.amber.shade600;
  final Color colorDanger = Colors.red.shade600;

  bool isLoadingRole = true;
  bool hasAccess = true;
  String currentRole = "Unknown";
  bool isUnitRentedOut = false;
  String? tenantUid;
  DateTime? contractStartDate;

  @override
  void initState() {
    super.initState();
    _initPageData();
  }

  String _getEnglishMonthYear(DateTime date) {
    const List<String> engMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return "${engMonths[date.month - 1]} ${date.year}";
  }

  int _getDailyElec(String unit, int year, int month, int day) {
    int seed = unit.hashCode + year + month + day;
    Random r = Random(seed);
    return 5 + r.nextInt(6);
  }

  double _getDailyWater(String unit, int year, int month, int day) {
    int seed = unit.hashCode + year + month + day;
    Random r = Random(seed);
    return 0.2 + (r.nextInt(7) / 10.0);
  }

  DateTime _parseSafeDate(dynamic dateData, {DateTime? fallback}) {
    if (dateData == null) return fallback ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    if (dateData is Timestamp) return dateData.toDate();
    try {
      return DateTime.parse(dateData.toString());
    } catch (e) {
      return fallback ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    }
  }

  Future<void> _initPageData() async {
    try {
      await _fetchUserRole();
      if (hasAccess) {
        await _checkAndAutoGenerateBill();
        await _applyLateFeesIfNeeded();
        await _checkAndSendAutoNotifications();
      }
    } catch (e) {
      debugPrint("Init Error: $e");
    } finally {
      if (mounted) setState(() => isLoadingRole = false);
    }
  }

  Future<void> _fetchUserRole() async {
    var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('unit_no', isEqualTo: widget.unitNo).where('ownerUid', isEqualTo: uid).get();
    if (unitQuery.docs.isNotEmpty) {
      currentRole = "Owner";
    } else {
      var rentQuery = await FirebaseFirestore.instance.collection('RentalApplications')
          .where('tenantUid', isEqualTo: uid)
          .where('unit_no', isEqualTo: widget.unitNo)
          .where('status', whereIn: ['Occupied', 'Approved & Active', 'Requesting End Contract', 'Extension Approved'])
          .get();

      if (rentQuery.docs.isNotEmpty) {
        currentRole = "Tenant";
      } else {
        var sharedQuery = await FirebaseFirestore.instance.collection('unit_access_members').where('unit_no', isEqualTo: widget.unitNo).where('user_uid', isEqualTo: uid).where('status', isEqualTo: 'Active').get();
        if (sharedQuery.docs.isNotEmpty) {
          var roleData = sharedQuery.docs.first.data();
          if (roleData['role'] == 'Resident Member') {
            currentRole = "Shared Member";
          } else {
            hasAccess = false;
            return;
          }
        } else {
          hasAccess = false;
          return;
        }
      }
    }

    var activeRents = await FirebaseFirestore.instance.collection('RentalApplications')
        .where('unit_no', isEqualTo: widget.unitNo)
        .where('status', whereIn: ['Occupied', 'Approved & Active', 'Extension Approved'])
        .get();

    if (activeRents.docs.isNotEmpty) {
      var rentData = activeRents.docs.first.data() as Map<String, dynamic>;
      isUnitRentedOut = true;
      tenantUid = rentData['tenantUid'];

      var rawStart = rentData['contract_start_date'] ?? rentData['start_date'] ?? rentData['timestamp'];
      contractStartDate = _parseSafeDate(rawStart, fallback: DateTime(DateTime.now().year, DateTime.now().month, 1));
    }
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  Future<void> _sendNotification(String targetId, String title, String body, String type) async {
    try {
      await FirebaseFirestore.instance.collection("Users").doc(targetId).collection("Notifications").add({
        "title": title, "body": body, "type": type, "timestamp": FieldValue.serverTimestamp(), "isRead": false,
      });
    } catch (e) {}
  }

  Future<void> _checkAndAutoGenerateBill() async {
    try {
      DateTime now = DateTime.now();
      String currentMonthName = _getEnglishMonthYear(now);
      String safeUnitNo = widget.unitNo.trim();
      String expectedInvoiceId = "INV-$safeUnitNo-${now.month}${now.year}";

      var docRef = FirebaseFirestore.instance.collection("billing_invoices").doc(expectedInvoiceId);
      var docSnap = await docRef.get();

      var queryByPeriod = await FirebaseFirestore.instance.collection("billing_invoices")
          .where("unit_no", isEqualTo: safeUnitNo)
          .where("billing_period", isEqualTo: currentMonthName)
          .get();

      Map<String, dynamic>? existingAdminData;
      String? oldRandomIdToDelete;

      if (queryByPeriod.docs.isNotEmpty) {
        for (var doc in queryByPeriod.docs) {
          if (doc.id != expectedInvoiceId) {
            existingAdminData = doc.data();
            oldRandomIdToDelete = doc.id;
          } else {
            existingAdminData = doc.data();
          }
        }
      }

      int maintRate = 200000;
      int elecRate = 1500;
      int waterRate = 8000;
      int dueDateDay = 10;

      try {
        var configDoc = await FirebaseFirestore.instance.collection('AppConfig').doc('billing_rates').get();
        if (configDoc.exists && configDoc.data() != null) {
          var configData = configDoc.data()!;
          int fetchedMaint = configData['maintenance_fee_monthly'] ?? configData['maintenance_fee'] ?? 0;
          if (fetchedMaint > 0) maintRate = fetchedMaint;

          elecRate = configData['electricity_kwh'] ?? 1500;
          waterRate = configData['water_m3'] ?? 8000;
          dueDateDay = configData['due_date'] ?? 10;
        }
      } catch (e) {}

      int totalElecUsage = 0;
      double totalWaterUsage = 0.0;
      int todayAddition = 0;

      DateTime defaultStartDate = DateTime(now.year, now.month, 1);
      DateTime cStart = contractStartDate ?? defaultStartDate;

      for (int d = 1; d <= now.day; d++) {
        bool isActive = true;

        DateTime checkDate = DateTime(now.year, now.month, d);
        DateTime startDate = DateTime(cStart.year, cStart.month, cStart.day);

        if (checkDate.isBefore(startDate)) isActive = false;

        if (isActive) {
          int dailyElec = _getDailyElec(safeUnitNo, now.year, now.month, d);
          double dailyWater = _getDailyWater(safeUnitNo, now.year, now.month, d);

          if (d < now.day) {
            totalElecUsage += dailyElec;
            totalWaterUsage += dailyWater;
          } else {
            todayAddition = (dailyElec * elecRate) + (dailyWater * waterRate).toInt();
          }
        }
      }

      int elecTotal = totalElecUsage * elecRate;
      int waterTotal = (totalWaterUsage * waterRate).toInt();
      int maintenanceTotal = maintRate;

      int grandTotal = elecTotal + waterTotal + maintenanceTotal;

      Map<String, dynamic>? parkingData;

      try {
        var parkQuery = await FirebaseFirestore.instance.collection('parking_memberships')
            .where('unit_no', isEqualTo: safeUnitNo)
            .where('status', whereIn: ['Active', 'Stopped'])
            .get();

        for (var parkDoc in parkQuery.docs) {
          var pData = parkDoc.data();
          bool shouldCharge = false;
          String pStatus = pData['status'] ?? '';

          DateTime paidUntil = _parseSafeDate(pData['paid_until'] ?? pData['end_date']);

          if (pStatus == 'Active') {
            if (now.year > paidUntil.year || (now.year == paidUntil.year && now.month >= paidUntil.month)) {
              shouldCharge = true;
            }
          } else if (pStatus == 'Stopped') {
            Timestamp? stoppedAtTs = pData['stopped_at'];
            if (stoppedAtTs != null) {
              DateTime stopDate = stoppedAtTs.toDate();
              if (stopDate.month == now.month && stopDate.year == now.year) {
                if (now.year > paidUntil.year || (now.year == paidUntil.year && now.month >= paidUntil.month)) {
                  shouldCharge = true;
                }
              }
            }
          }

          if (shouldCharge) {
            int parkFee = pData['monthly_fee'] ?? (pData['vehicle_type'] == 'Car' ? 200000 : 100000);
            parkingData = {
              "amount": parkFee,
              "desc": "${pData['vehicle_plate'] ?? ''} (${pData['vehicle_type'] ?? 'Vehicle'})",
              "prorated": false
            };
            grandTotal += parkFee;
            break;
          }
        }
      } catch (e) {}

      DateTime nextMonth = DateTime(now.year, now.month + 1, dueDateDay);
      String dueDateStr = "${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-${nextMonth.day.toString().padLeft(2, '0')}T00:00:00.000";

      String correctPayerUid = uid;
      if (currentRole == "Owner" && isUnitRentedOut && tenantUid != null) {
        correctPayerUid = tenantUid!;
      }

      Map<String, dynamic> breakdown = {
        "electricity": {"usage": totalElecUsage, "tariff": elecRate, "amount": elecTotal},
        "water": {"usage": totalWaterUsage.toStringAsFixed(1), "tariff": waterRate, "amount": waterTotal},
        "maintenance": {"prorated": false, "amount": maintenanceTotal}
      };

      if (parkingData != null) {
        breakdown["parking"] = parkingData;
      } else {
        breakdown.remove("parking");
      }

      if (existingAdminData != null && existingAdminData.containsKey('breakdown') && existingAdminData['breakdown']['penalty'] != null) {
        breakdown["penalty"] = existingAdminData['breakdown']['penalty'];
        grandTotal += (existingAdminData['breakdown']['penalty']['amount'] as num).toInt();
      }

      Map<String, dynamic> invoicePayload = {
        "unit_no": safeUnitNo,
        "billing_period": currentMonthName,
        "base_amount": grandTotal,
        "total_amount": grandTotal,
        "today_addition": todayAddition,
        "last_updated_day": now.day,
        "status": existingAdminData?['status'] ?? "UNPAID",
        "created_at": existingAdminData?['created_at'] ?? FieldValue.serverTimestamp(),
        "due_date": existingAdminData?['due_date'] ?? dueDateStr,
        "notified_new": existingAdminData?['notified_new'] ?? false,
        "notified_overdue": existingAdminData?['notified_overdue'] ?? false,
        "payer_uid": correctPayerUid,
        "payer_role": currentRole,
        "contract_start_date": cStart.toIso8601String(), // Simpan start date yang benar
        "breakdown": breakdown
      };

      if (!docSnap.exists) {
        await docRef.set(invoicePayload);
        if (oldRandomIdToDelete != null) {
          await FirebaseFirestore.instance.collection("billing_invoices").doc(oldRandomIdToDelete).delete();
        }
      }
      else {
        // FORCE UPDATE ke Firestore agar data Admin langsung sama dengan data perbaikan
        await docRef.update({
          "base_amount": grandTotal,
          "total_amount": grandTotal,
          "today_addition": todayAddition,
          "last_updated_day": now.day,
          "breakdown": breakdown,
          "contract_start_date": cStart.toIso8601String(),
        });
      }

    } catch (e) {
      debugPrint("FATAL Error auto-generating bill: $e");
    }
  }

  Future<void> _applyLateFeesIfNeeded() async {
    try {
      DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      int dailyLateFee = 50000;
      try {
        var configDoc = await FirebaseFirestore.instance.collection('AppConfig').doc('billing_rates').get();
        if (configDoc.exists && configDoc.data() != null) {
          dailyLateFee = configDoc.data()!['late_fee_per_day'] ?? 50000;
        }
      } catch(e) {}

      var unpaidInvoices = await FirebaseFirestore.instance.collection("billing_invoices")
          .where("unit_no", isEqualTo: widget.unitNo)
          .where("status", whereIn: ["UNPAID", "OVERDUE"])
          .get();

      for (var doc in unpaidInvoices.docs) {
        var data = doc.data();
        DateTime dueDate = _parseSafeDate(data['due_date']);
        DateTime penaltyStartDate = DateTime(dueDate.year, dueDate.month, dueDate.day + 1);

        if (today.isAfter(dueDate) || today.isAtSameMomentAs(penaltyStartDate)) {
          int daysLate = today.difference(dueDate).inDays;

          if (daysLate > 0) {
            int currentPenaltyAmount = daysLate * dailyLateFee;

            Map<String, dynamic> breakdown = data['breakdown'] ?? {};
            int existingPenalty = breakdown['penalty']?['amount'] ?? 0;

            if (currentPenaltyAmount > existingPenalty) {
              int difference = currentPenaltyAmount - existingPenalty;
              num currentTotal = data['total_amount'] ?? 0;

              breakdown['penalty'] = {
                "amount": currentPenaltyAmount,
                "desc": "$daysLate days late (${formatCurrency(dailyLateFee)}/day)"
              };

              await doc.reference.update({
                "status": "OVERDUE",
                "total_amount": currentTotal + difference,
                "breakdown": breakdown,
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error applying late fees: $e");
    }
  }

  Future<void> _checkAndSendAutoNotifications() async {
    if (currentRole == "Shared Member") return;

    try {
      var query = await FirebaseFirestore.instance.collection("billing_invoices")
          .where("unit_no", isEqualTo: widget.unitNo)
          .where("status", whereIn: ["UNPAID", "OVERDUE"])
          .get();

      for (var doc in query.docs) {
        var data = doc.data();
        bool isOverdue = data['status'] == 'OVERDUE';
        bool notifiedOverdue = data['notified_overdue'] == true;
        bool notifiedNew = data['notified_new'] == true;

        if (isOverdue && !notifiedOverdue) {
          await _sendNotification(
              uid,
              "Overdue Invoice 🚨",
              "Your bill for Unit ${widget.unitNo} (${data['billing_period']}) is overdue! Please settle it immediately to avoid access restriction.",
              "Payments"
          );
          await doc.reference.update({'notified_overdue': true, 'notified_new': true});

        } else if (!isOverdue && !notifiedNew) {
          await _sendNotification(
              uid,
              "New Invoice Available 🧾",
              "Your bill for Unit ${widget.unitNo} (${data['billing_period']}) is ready. Available to pay starting from the 1st of next month.",
              "Payments"
          );
          await doc.reference.update({'notified_new': true});
        }
      }
    } catch (e) {
      debugPrint("Error sending auto-notifications: $e");
    }
  }

  void _showHistoryAndStatementsModal(List<DocumentSnapshot> allDocs) {
    var paidDocs = allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == "PAID").toList();

    bool isReadOnly = currentRole == "Owner" && isUnitRentedOut;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("History & Statements", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
            Text(currentRole == "Shared Member" ? "Review past transactions for this unit." : (isReadOnly ? "Review your tenant's past transactions." : "Review your past transactions and download official PDF invoices."), style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10), const Divider(),
            Expanded(
              child: paidDocs.isEmpty ? const Center(child: Text("No completed payments found.", style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                  itemCount: paidDocs.length,
                  itemBuilder: (context, index) {
                    var data = paidDocs[index].data() as Map<String, dynamic>;
                    String period = data['billing_period'] ?? "Unknown Period";
                    num total = data['total_amount'] ?? 0;
                    String method = data['payment_method'] ?? "Unknown";
                    DateTime paidDate = _parseSafeDate(data['paid_at']);
                    String dateStr = DateFormat('dd MMM yyyy, HH:mm').format(paidDate);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: const Icon(Icons.receipt_long, color: Colors.teal, size: 22)),
                      title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("$period", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), Text(formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87))]),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [const Icon(Icons.check_circle, color: Colors.green, size: 12), const SizedBox(width: 4), Expanded(child: Text("Paid via $method • $dateStr", style: const TextStyle(fontSize: 11, color: Colors.grey)))])),
                      trailing: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.teal.shade700, side: BorderSide(color: Colors.teal.shade200), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), minimumSize: const Size(0, 32)), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => BillingDetailPage(invoiceId: paidDocs[index].id, invoiceData: data, isViewOnly: isReadOnly, isCurrentMonth: false, isSharedMember: currentRole == "Shared Member"))); }, child: const Text("View", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                    );
                  }
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    bool isOwnerView = currentRole == "Owner" && isUnitRentedOut;

    return Container(
      margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xffEFF6FF), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Colors.blue, size: 20), const SizedBox(width: 12),
          Expanded(child: RichText(text: TextSpan(style: const TextStyle(color: Color(0xff1E3A8A), fontSize: 12.0, height: 1.5), children: [
            if (isOwnerView) ...[const TextSpan(text: "You are viewing the billing status of your tenant. As the owner, "), const TextSpan(text: "you can monitor their payment activities and usage.", style: TextStyle(fontWeight: FontWeight.bold))]
            else ...[const TextSpan(text: "You can pay invoices "), const TextSpan(text: "on or after the 1st", style: TextStyle(fontWeight: FontWeight.bold)), const TextSpan(text: " of the month. Only "), const TextSpan(text: "overdue invoices", style: TextStyle(fontWeight: FontWeight.bold)), const TextSpan(text: " can be paid before the 1st.")]
          ])))
        ],
      ),
    );
  }

  Widget _buildGrandTotalCard(num unpaidTotal, num currentTotal, DocumentSnapshot? firstPayableDoc) {
    num grandTotal = unpaidTotal + currentTotal;
    bool hasUnpaid = unpaidTotal > 0;
    bool isOwnerView = currentRole == "Owner" && isUnitRentedOut;

    bool isOverdue = false;
    if (firstPayableDoc != null) {
      var data = firstPayableDoc.data() as Map<String, dynamic>;
      DateTime due = _parseSafeDate(data['due_date']);
      DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      isOverdue = today.isAfter(due);
    }

    DateTime nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);
    String availableDateFull = DateFormat('dd MMM yyyy').format(nextMonth);
    String availableDateShort = DateFormat('MMM d').format(nextMonth);
    String currentMonthStr = _getEnglishMonthYear(DateTime.now());

    Color badgeColor = isOverdue ? Colors.red : (hasUnpaid ? Colors.orange : Colors.blue);
    IconData badgeIcon = isOverdue ? Icons.error : (hasUnpaid ? Icons.warning : Icons.schedule);
    String badgeText = isOverdue ? "OVERDUE" : (hasUnpaid ? "UNPAID" : "UPCOMING");

    String infoText;
    if (isOwnerView) {
      infoText = isOverdue ? "Your tenant has overdue bills." : (hasUnpaid ? "Waiting for tenant's payment." : "Tenant is fully paid up.");
    } else {
      infoText = isOverdue ? "Please settle your overdue bills immediately!" : (hasUnpaid ? "Your bill is ready! Please pay immediately." : "Available to pay on $availableDateFull");
    }

    return Container(
      width: double.infinity, margin: const EdgeInsets.only(bottom: 25), decoration: BoxDecoration(color: const Color(0xff1E293B), borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
                children: [
                  Positioned(right: 0, top: 10, child: Icon(Icons.receipt_long, color: Colors.white.withOpacity(0.05), size: 90)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 16)), const SizedBox(width: 10), Text(isOwnerView ? "Tenant's Balance" : "Total Outstanding Balance", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))]),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: badgeColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(badgeIcon, color: badgeColor.withOpacity(0.8), size: 12), const SizedBox(width: 4), Text(badgeText, style: TextStyle(color: badgeColor.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold))]))
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(formatCurrency(grandTotal), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
                      const SizedBox(height: 8),

                      if (isOverdue) Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Text("Overdue: ${formatCurrency(unpaidTotal)}", style: TextStyle(color: Colors.red.shade300, fontSize: 12, fontWeight: FontWeight.bold)), const Text("  •  ", style: TextStyle(color: Colors.white54, fontSize: 12)), Text("Current: ${formatCurrency(currentTotal)}", style: const TextStyle(color: Colors.white70, fontSize: 12))])
                      else if (hasUnpaid) Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [Text("Unpaid: ${formatCurrency(unpaidTotal)}", style: TextStyle(color: Colors.orange.shade300, fontSize: 12, fontWeight: FontWeight.bold)), const Text("  •  ", style: TextStyle(color: Colors.white54, fontSize: 12)), Text("Current: ${formatCurrency(currentTotal)}", style: const TextStyle(color: Colors.white70, fontSize: 12))])
                      else Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [const Text("No unpaid bills", style: TextStyle(color: Colors.white70, fontSize: 12)), const Text("  •  ", style: TextStyle(color: Colors.white54, fontSize: 12)), Text("Includes $currentMonthStr bill", style: const TextStyle(color: Colors.white70, fontSize: 12))]),
                    ],
                  ),
                ]
            ),
          ),
          const Divider(color: Colors.white12, height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [const Icon(Icons.calendar_today, color: Colors.white54, size: 14), const SizedBox(width: 8), Expanded(child: Text(infoText, style: const TextStyle(color: Colors.white70, fontSize: 12)))]),
                if (!isOwnerView) ...[
                  const SizedBox(height: 15),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: isOverdue ? Colors.red.shade600 : (hasUnpaid ? Colors.orange.shade600 : Colors.white.withOpacity(0.1)),
                              foregroundColor: hasUnpaid ? Colors.white : Colors.white54,
                              disabledBackgroundColor: Colors.white.withOpacity(0.15),
                              disabledForegroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: hasUnpaid ? 8 : 0
                          ),
                          onPressed: hasUnpaid ? () {
                            if (firstPayableDoc != null) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => BillingDetailPage(invoiceId: firstPayableDoc!.id, invoiceData: firstPayableDoc!.data() as Map<String, dynamic>, isViewOnly: false, isCurrentMonth: false, autoOpenPayment: false, isSharedMember: currentRole == "Shared Member"))).then((_) => setState(() { isLoadingRole = true; _initPageData(); }));
                            }
                          } : null,
                          icon: Icon(hasUnpaid ? Icons.payment : Icons.lock_outline, size: 18),
                          label: Text(hasUnpaid ? "Pay Now" : "Pay (Available $availableDateShort)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))
                      )
                  )
                ],
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPreviousBillCard(Map<String, dynamic> data, String invoiceId) {
    String period = data['billing_period'] ?? "";
    num totalAmount = data['total_amount'] ?? 0;
    int lateFee = data['breakdown']?['penalty']?['amount'] ?? 0;
    DateTime due = _parseSafeDate(data['due_date']);
    DateTime penaltyStartDate = DateTime(due.year, due.month, due.day + 1);
    DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    int daysLate = today.difference(due).inDays;
    bool isOverdue = daysLate > 0;

    Color cardColor = isOverdue ? colorDanger : Colors.orange.shade600;
    Color bgColor = isOverdue ? Colors.red.shade50 : Colors.orange.shade50;
    IconData cardIcon = isOverdue ? Icons.warning_amber_rounded : Icons.info_outline;
    String statusText = isOverdue ? "OVERDUE (${daysLate} Day${daysLate > 1 ? 's' : ''} Late)" : "PAYABLE NOW";
    if (data['status'] == "PENDING") { statusText = "PENDING ADMIN VERIFICATION"; cardColor = Colors.purple; bgColor = Colors.purple.shade50; cardIcon = Icons.hourglass_top; }

    bool isOwnerView = currentRole == "Owner" && isUnitRentedOut;
    bool isReadOnly = isOwnerView || data['status'] == "PENDING";

    return GestureDetector(
      onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => BillingDetailPage(invoiceId: invoiceId, invoiceData: data, isViewOnly: isReadOnly, isCurrentMonth: false, isSharedMember: currentRole == "Shared Member"))).then((_) => setState(() { isLoadingRole = true; _initPageData(); })); },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: cardColor.withOpacity(0.3)), boxShadow: [BoxShadow(color: cardColor.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: cardColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(cardIcon, color: cardColor, size: 24)), const SizedBox(width: 15),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("$period — $statusText", style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 4), Text(formatCurrency(totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87)), if (lateFee > 0) Text("Includes Late Fee: ${formatCurrency(lateFee)}", style: TextStyle(color: colorDanger, fontSize: 11, fontWeight: FontWeight.bold))])),

            if (!isOwnerView && data['status'] != "PENDING")
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: cardColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), minimumSize: Size.zero),
                  onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => BillingDetailPage(invoiceId: invoiceId, invoiceData: data, isViewOnly: false, isCurrentMonth: false, autoOpenPayment: false, isSharedMember: currentRole == "Shared Member"))).then((_) => setState(() { isLoadingRole = true; _initPageData(); })); },
                  child: const Text("Pay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))
              )
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBillCard(Map<String, dynamic> data, String invoiceId) {
    num totalAmount = data['total_amount'] ?? 0;
    num todayAdd = data['today_addition'] ?? 0;
    String period = data['billing_period'] ?? "Current Month";
    DateTime nextMonth = DateTime(DateTime.now().year, DateTime.now().month + 1, 1);
    String availableDate = DateFormat('dd MMM yyyy').format(nextMonth);

    bool isOwnerView = currentRole == "Owner" && isUnitRentedOut;
    bool isReadOnly = isOwnerView || currentRole == "Shared Member";

    return Container(
      width: double.infinity, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Billing Cycle — $period", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.sync, color: Colors.blue, size: 14), const SizedBox(width: 5), const Text("ESTIMATED", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5))]))]),
                const SizedBox(height: 20), Text(formatCurrency(totalAmount), style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: colorSecondary, letterSpacing: -1)),
                if (todayAdd > 0 && !isOwnerView) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [const Icon(Icons.trending_up, color: Color(0xff10B981), size: 16), const SizedBox(width: 6), Text("+ ${formatCurrency(todayAdd)} usage today", style: const TextStyle(color: Color(0xff10B981), fontWeight: FontWeight.bold, fontSize: 12))])),
                const SizedBox(height: 25),
                Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xffF0F6FF), borderRadius: BorderRadius.circular(12)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.calendar_today, size: 18, color: Colors.blue), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [RichText(text: TextSpan(style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade800), children: [const TextSpan(text: "Finalized & Payable on: "), TextSpan(text: availableDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))])), const SizedBox(height: 4), Text(isOwnerView ? "Payments can only be made by Residents after 1st." : "You can pay this invoice starting from the 1st.", style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade600))]))])),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          InkWell(
            onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => BillingDetailPage(invoiceId: invoiceId, invoiceData: data, isViewOnly: isReadOnly, isCurrentMonth: true, isSharedMember: currentRole == "Shared Member"))).then((_) => setState(() { isLoadingRole = true; _initPageData(); })); },
            child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [const Icon(Icons.bar_chart, color: Colors.blueGrey, size: 24), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("View Details & Usage", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)), const SizedBox(height: 2), Text("See breakdown, daily usage, and more", style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])), const Icon(Icons.chevron_right, color: Colors.grey)])),
          )
        ],
      ),
    );
  }

  Widget _buildUpcomingBillCard() {
    DateTime now = DateTime.now(); DateTime nextMonth = DateTime(now.year, now.month + 1, 1);
    int daysLeft = nextMonth.difference(now).inDays;
    String nextPeriod = _getEnglishMonthYear(nextMonth);
    String nextDateStr = DateFormat('dd MMM yyyy').format(nextMonth);
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
      child: Row(children: [Icon(Icons.calendar_month, color: Colors.green.shade400, size: 30), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Next Billing ($nextPeriod)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)), const SizedBox(height: 2), Text("Starts accumulating in $daysLeft days", style: const TextStyle(fontSize: 12, color: Colors.grey))])), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)), child: Text("Starts $nextDateStr", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)))]),
    );
  }

  Widget _buildActionTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 22)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)), subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)), trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey), onTap: onTap));
  }

  Widget _buildAvoidLateFeeCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 30), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [const Icon(Icons.shield, color: Color(0xffF59E0B), size: 28), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Avoid Late Fee", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)), const SizedBox(height: 4), Text("A late fee of Rp 50.000/day will be applied after the due date.", style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4))])), const SizedBox(width: 10), OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: const Color(0xffF59E0B), side: const BorderSide(color: Color(0xffF59E0B)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: const Size(0, 36)), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const LateFeeInfoPage())); }, child: const Text("Learn More", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingRole) {
      return Scaffold(backgroundColor: const Color(0xffF8F9FA), appBar: AppBar(backgroundColor: Colors.white, elevation: 0, centerTitle: true, title: const Text("Billing & Invoices", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)), leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context))), body: Center(child: CircularProgressIndicator(color: colorPrimary)));
    }

    if (!hasAccess) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, centerTitle: true, title: const Text("Billing & Invoices", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)), leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 80, color: Colors.grey.shade300), const SizedBox(height: 15),
              const Text("Access Denied", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)), const SizedBox(height: 10),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text("Only Primary Residents and Resident Members can view billing details.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5))),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, centerTitle: true, title: const Text("Billing & Invoices", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)), leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context))),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection("billing_invoices").where("unit_no", isEqualTo: widget.unitNo).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: colorPrimary));
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No bills found."));

            String currentPeriod = _getEnglishMonthYear(DateTime.now());
            var allDocs = snapshot.data!.docs.toList();
            allDocs.sort((a, b) { DateTime dateA = _parseSafeDate((a.data() as Map)['created_at']); DateTime dateB = _parseSafeDate((b.data() as Map)['created_at']); return dateB.compareTo(dateA); });

            var currentBillDocs = allDocs.where((doc) => (doc.data() as Map)['billing_period'] == currentPeriod).toList();
            var previousUnpaidDocs = allDocs.where((doc) { var data = doc.data() as Map<String, dynamic>; return data['billing_period'] != currentPeriod && (data['status'] == "UNPAID" || data['status'] == "OVERDUE" || data['status'] == "PENDING"); }).toList();

            num totalUnpaidAmount = 0; DocumentSnapshot? firstPayableDoc;
            for(var doc in previousUnpaidDocs) { var data = doc.data() as Map<String, dynamic>; totalUnpaidAmount += data['total_amount'] ?? 0; if (firstPayableDoc == null) firstPayableDoc = doc; }
            num currentMonthAmount = 0; if (currentBillDocs.isNotEmpty) { currentMonthAmount = (currentBillDocs.first.data() as Map)['total_amount'] ?? 0; }
            bool isOwnerView = currentRole == "Owner" && isUnitRentedOut;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoBanner(), _buildGrandTotalCard(totalUnpaidAmount, currentMonthAmount, firstPayableDoc),
                  if (previousUnpaidDocs.isNotEmpty) ...[Text(isOwnerView ? "Tenant's Action Required" : "Action Required", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 15), ...previousUnpaidDocs.map((doc) => _buildPreviousBillCard(doc.data() as Map<String, dynamic>, doc.id)).toList(), const SizedBox(height: 25)],
                  const Text("Current Invoice", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 15),
                  if (currentBillDocs.isNotEmpty) _buildCurrentBillCard(currentBillDocs.first.data() as Map<String, dynamic>, currentBillDocs.first.id),
                  const SizedBox(height: 15), _buildUpcomingBillCard(), const SizedBox(height: 35),
                  const Text("Quick Actions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 15),
                  _buildActionTile(icon: Icons.receipt_long, color: Colors.teal, title: "History & Statements", subtitle: currentRole == "Shared Member" ? "View past transactions" : (isOwnerView ? "View tenant's past transactions" : "View past transactions & download PDFs"), onTap: () => _showHistoryAndStatementsModal(allDocs)),
                  if (!isOwnerView) ...[const SizedBox(height: 10), _buildAvoidLateFeeCard()]
                ],
              ),
            );
          }
      ),
    );
  }
}
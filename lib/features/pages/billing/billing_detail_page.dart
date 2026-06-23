import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class BillingDetailPage extends StatefulWidget {
  final String invoiceId;
  final Map<String, dynamic> invoiceData;
  final bool isViewOnly;
  final bool autoOpenPayment;
  final bool isCurrentMonth;
  final bool isSharedMember;

  const BillingDetailPage({
    Key? key,
    required this.invoiceId,
    required this.invoiceData,
    this.isViewOnly = false,
    this.autoOpenPayment = false,
    required this.isCurrentMonth,
    this.isSharedMember = false,
  }) : super(key: key);

  @override
  State<BillingDetailPage> createState() => _BillingDetailPageState();
}

class _BillingDetailPageState extends State<BillingDetailPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  final Color colorPrimary = const Color(0xffF59E0B);
  final Color colorSecondary = const Color(0xff1E293B);
  final Color colorSuccess = Colors.green.shade600;
  final Color colorWarning = Colors.amber.shade600;
  final Color colorDanger = Colors.red.shade600;

  Map<String, dynamic> breakdown = {};
  num displayTotalAmount = 0;

  int? selectedBarIndex;
  List<Map<String, dynamic>> chartDailyData = [];

  DateTime? contractStartDate;

  @override
  void initState() {
    super.initState();

    if (widget.invoiceData['breakdown'] != null) {
      breakdown = Map<String, dynamic>.from(widget.invoiceData['breakdown']);
    }
    displayTotalAmount = widget.invoiceData['total_amount'] ?? 0;

    if (widget.invoiceData['contract_start_date'] != null) {
      contractStartDate = _parseSafeDate(widget.invoiceData['contract_start_date']);
    }

    _generateChartData();
    _syncCurrentMonthBreakdown();

    if (widget.autoOpenPayment && !widget.isViewOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPaymentOptions());
    }
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
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

  void _syncCurrentMonthBreakdown() {
    if (!widget.isCurrentMonth) return;

    String unit = widget.invoiceData['unit_no'] ?? "UNIT";
    DateTime now = DateTime.now();
    int endDay = now.day - 1;

    if (endDay < 1) return;

    int totalElecUsage = 0;
    double totalWaterUsage = 0.0;

    int elecRate = breakdown['electricity']?['tariff'] ?? 1500;
    int waterRate = breakdown['water']?['tariff'] ?? 8000;
    int maintRate = breakdown['maintenance']?['amount'] ?? 0;
    int parkRate = breakdown['parking']?['amount'] ?? 0;
    int penaltyRate = breakdown['penalty']?['amount'] ?? 0;

    DateTime defaultStartDate = DateTime(now.year, now.month, 1);
    DateTime cStart = contractStartDate ?? defaultStartDate;

    for (int d = 1; d <= endDay; d++) {
      bool isActive = true;

      DateTime checkDate = DateTime(now.year, now.month, d);
      DateTime startDate = DateTime(cStart.year, cStart.month, cStart.day);

      if (checkDate.isBefore(startDate)) isActive = false;

      if (isActive) {
        totalElecUsage += _getDailyElec(unit, now.year, now.month, d);
        totalWaterUsage += _getDailyWater(unit, now.year, now.month, d);
      }
    }

    if (breakdown['electricity'] == null) {
      breakdown['electricity'] = {'tariff': elecRate};
    }
    breakdown['electricity'] = Map<String, dynamic>.from(breakdown['electricity']);
    breakdown['electricity']['usage'] = totalElecUsage;
    breakdown['electricity']['amount'] = totalElecUsage * elecRate;

    if (breakdown['water'] == null) {
      breakdown['water'] = {'tariff': waterRate};
    }
    breakdown['water'] = Map<String, dynamic>.from(breakdown['water']);
    breakdown['water']['usage'] = totalWaterUsage.toStringAsFixed(1);
    breakdown['water']['amount'] = (totalWaterUsage * waterRate).toInt();

    displayTotalAmount = (totalElecUsage * elecRate) + (totalWaterUsage * waterRate).toInt() + maintRate + parkRate + penaltyRate;
  }

  void _generateChartData() {
    String unit = widget.invoiceData['unit_no'] ?? "UNIT";
    DateTime targetMonthDate = widget.isCurrentMonth ? DateTime.now() : _parseSafeDate(widget.invoiceData['created_at']);

    int endDay = widget.isCurrentMonth ? DateTime.now().day - 1 : DateTime(targetMonthDate.year, targetMonthDate.month + 1, 0).day;
    if (endDay < 1) endDay = 1;

    int elecRate = breakdown['electricity']?['tariff'] ?? 1500;
    int waterRate = breakdown['water']?['tariff'] ?? 8000;

    chartDailyData.clear();

    int startDay = endDay - 6;
    if (startDay < 1) startDay = 1;

    DateTime defaultStartDate = DateTime(targetMonthDate.year, targetMonthDate.month, 1);
    DateTime cStart = contractStartDate ?? defaultStartDate;

    for(int d = startDay; d <= endDay; d++) {
      DateTime dayDate = DateTime(targetMonthDate.year, targetMonthDate.month, d);
      String dateLabel = DateFormat('dd MMM yyyy').format(dayDate);

      int elecUsage = 0;
      double waterUsage = 0.0;

      bool isActive = true;
      DateTime startDate = DateTime(cStart.year, cStart.month, cStart.day);
      if (dayDate.isBefore(startDate)) isActive = false;

      if (isActive) {
        elecUsage = _getDailyElec(unit, dayDate.year, dayDate.month, d);
        waterUsage = _getDailyWater(unit, dayDate.year, dayDate.month, d);
      }

      chartDailyData.add({
        "full_date": dateLabel,
        "elec": elecUsage,
        "water": waterUsage,
        "elec_cost": elecUsage * elecRate,
        "water_cost": (waterUsage * waterRate).toInt()
      });
    }
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

  Future<void> _sendNotification(String title, String body, String type) async {
    try {
      await FirebaseFirestore.instance.collection("Users").doc(uid).collection("Notifications").add({
        "title": title,
        "body": body,
        "type": type,
        "timestamp": FieldValue.serverTimestamp(),
        "isRead": false,
      });
    } catch (e) {
      debugPrint("Failed to send notification: $e");
    }
  }

  Future<void> _downloadInvoicePDF() async {
    if (widget.isSharedMember) {
      Fluttertoast.showToast(msg: "Shared Members cannot download invoices.", backgroundColor: Colors.black87);
      return;
    }

    String status = widget.invoiceData['status'] ?? "UNPAID";

    if (status != 'PAID') {
      Fluttertoast.showToast(msg: "Access Denied: Invoice must be paid fully to download.", backgroundColor: Colors.red);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text("Generating PDF Document...", textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    try {
      String unit = widget.invoiceData['unit_no'] ?? "UNIT";
      DateTime periodDate = _parseSafeDate(widget.invoiceData['created_at']);
      String mm = periodDate.month.toString().padLeft(2, '0');
      String yyyy = periodDate.year.toString();
      String fileName = "INV-$unit-$mm$yyyy.pdf";

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("TA APARTMENT", style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 5),
                pw.Text("Official Billing Statement", style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                pw.SizedBox(height: 20),

                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("RECEIPT", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.green600)),
                      pw.Text(widget.invoiceData['billing_period'] ?? "", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    ]
                ),
                pw.Divider(thickness: 2),
                pw.SizedBox(height: 10),

                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("Invoice ID: ${widget.invoiceId}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.Text("Unit No: $unit"),
                            pw.Text("Issue Date: ${DateFormat('dd MMM yyyy').format(periodDate)}"),
                          ]
                      ),
                      pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text("Due Date: ${DateFormat('dd MMM yyyy').format(_parseSafeDate(widget.invoiceData['due_date']))}", style: pw.TextStyle(color: PdfColors.red800)),
                            if (widget.invoiceData['paid_at'] != null)
                              pw.Text("Paid At: ${DateFormat('dd MMM yyyy').format(_parseSafeDate(widget.invoiceData['paid_at']))}", style: pw.TextStyle(color: PdfColors.green800)),
                          ]
                      ),
                    ]
                ),
                pw.SizedBox(height: 30),

                pw.Text("BILL SUMMARY", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Divider(),
                if (breakdown['electricity'] != null)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Electricity Usage (${breakdown['electricity']['usage']} kWh)"), pw.Text(formatCurrency(breakdown['electricity']['amount']))]),
                pw.SizedBox(height: 5),
                if (breakdown['water'] != null)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Water Usage (${breakdown['water']['usage']} m3)"), pw.Text(formatCurrency(breakdown['water']['amount']))]),
                pw.SizedBox(height: 5),
                if (breakdown['maintenance'] != null)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Maintenance Fee"), pw.Text(formatCurrency(breakdown['maintenance']['amount']))]),
                pw.SizedBox(height: 5),
                if (breakdown['parking'] != null && breakdown['parking']['amount'] > 0)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Parking (${breakdown['parking']['desc'] ?? 'Membership'})"), pw.Text(formatCurrency(breakdown['parking']['amount']))]),
                pw.SizedBox(height: 5),
                if (breakdown['penalty'] != null)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Late Fee Penalty", style: const pw.TextStyle(color: PdfColors.red)), pw.Text(formatCurrency(breakdown['penalty']['amount']), style: const pw.TextStyle(color: PdfColors.red))]),

                pw.SizedBox(height: 10),
                pw.Divider(thickness: 1.5),
                pw.SizedBox(height: 5),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text("TOTAL AMOUNT", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text(formatCurrency(displayTotalAmount), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))
                    ]
                ),

                pw.Spacer(),
                pw.Divider(),
                pw.Text("This is a computer-generated document. No signature is required.", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700), textAlign: pw.TextAlign.center),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/$fileName");
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      Fluttertoast.showToast(msg: "Document Generated!", backgroundColor: Colors.green.shade700);

      await OpenFile.open(file.path);

    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      Fluttertoast.showToast(msg: "Error generating PDF: $e", backgroundColor: Colors.red);
    }
  }

  Widget _buildDownloadButton(String status) {
    bool canDownload = status == 'PAID' && !widget.isSharedMember;
    String reason = widget.isSharedMember ? "Shared Members cannot download invoices" : (status == 'PAID' ? "" : "Invoice must be fully paid to download");

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, top: 10),
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: canDownload ? Colors.blue.shade600 : Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: Icon(canDownload ? Icons.picture_as_pdf : Icons.lock_outline, color: canDownload ? Colors.white : Colors.grey.shade500, size: 20),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(canDownload ? "Download Invoice" : "Download Invoice (Disabled)", style: TextStyle(color: canDownload ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 14)),
            if (!canDownload)
              Text(reason, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          ],
        ),
        onPressed: canDownload ? _downloadInvoicePDF : () {
          Fluttertoast.showToast(msg: reason, backgroundColor: Colors.black87);
        },
      ),
    );
  }

  void _showPaymentOptions() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Payment Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    if (breakdown['electricity'] != null) _detailRow("Electricity", formatCurrency(breakdown['electricity']['amount'])),
                    if (breakdown['water'] != null) _detailRow("Water", formatCurrency(breakdown['water']['amount'])),
                    if (breakdown['maintenance'] != null) _detailRow("Maintenance", formatCurrency(breakdown['maintenance']['amount'])),
                    if (breakdown['parking'] != null) _detailRow("Parking", formatCurrency(breakdown['parking']['amount'])),
                    if (breakdown['penalty'] != null) _detailRow("Late Fee", formatCurrency(breakdown['penalty']['amount']), color: colorDanger),
                    const Divider(height: 20),
                    _detailRow("TOTAL DUE", formatCurrency(displayTotalAmount), isBold: true),
                  ],
                ),
              ),

              const SizedBox(height: 25),
              const Text("Select Payment Method", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),

              _paymentTile(Icons.qr_code, "QRIS", Colors.blue, "QRIS", isManual: true),
              _paymentTile(Icons.credit_card, "Credit/Debit Card", Colors.orange, "Credit Card", isManual: true),
              _paymentTile(Icons.account_balance, "Virtual Account", Colors.green, "Virtual Account", isManual: true),
              const Divider(height: 20),
              _paymentTile(Icons.upload_file, "Manual Bank Transfer", Colors.purple, "Manual Transfer", isManual: true),
              const SizedBox(height: 20),
            ],
          ),
        )
    );
  }

  Widget _paymentTile(IconData icon, String title, Color color, String method, {bool isManual = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: isManual ? const Text("Requires admin verification", style: TextStyle(fontSize: 11, color: Colors.grey)) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {
          Navigator.pop(context);
          _processPayment(method, isManual);
        },
      ),
    );
  }

  void _processPayment(String method, bool isManual) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text("Processing via $method...", textAlign: TextAlign.center),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () async {
      Navigator.of(context, rootNavigator: true).pop();

      try {
        String newStatus = "PENDING";
        await FirebaseFirestore.instance.collection("billing_invoices").doc(widget.invoiceId).update({
          "status": newStatus,
          "payment_method": method,
          "paid_at": FieldValue.serverTimestamp(),
        });

        String period = widget.invoiceData['billing_period'] ?? "this month";

        await _sendNotification(
            "Payment Pending Verification",
            "Your payment for $period via $method is waiting for Admin approval.",
            "Payment"
        );

        if (mounted) {
          Navigator.pop(context, true);
          Fluttertoast.showToast(msg: "Payment Submitted! Waiting Admin.", backgroundColor: Colors.blue);
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Payment Failed: $e", backgroundColor: colorDanger);
      }
    });
  }

  Widget _buildInteractiveUsageInsight() {
    double maxUsage = 15.0;
    double maxBarHeight = 70.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: colorPrimary, size: 20),
              const SizedBox(width: 8),
              const Text("Daily Utility Tracker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 5),
          const Text("Tap a bar to see specific daily cost.", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 25),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(chartDailyData.length, (index) {
              double barHeight = (chartDailyData[index]['elec'] / maxUsage) * maxBarHeight;
              if (barHeight == 0) barHeight = 5;
              bool isSelected = selectedBarIndex == index;

              return GestureDetector(
                onTap: () => setState(() => selectedBarIndex = index),
                child: Column(
                  children: [
                    Container(
                      width: 30, height: barHeight,
                      decoration: BoxDecoration(
                          color: isSelected ? colorPrimary : Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(6)
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(chartDailyData[index]['full_date'].substring(0, 2), style: TextStyle(fontSize: 10, color: isSelected ? colorPrimary : Colors.grey, fontWeight: FontWeight.bold))
                  ],
                ),
              );
            }),
          ),

          if (selectedBarIndex != null && selectedBarIndex! < chartDailyData.length) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
              child: Column(
                children: [
                  Text(chartDailyData[selectedBarIndex!]['full_date'], style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade900)),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text("Electricity", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("${chartDailyData[selectedBarIndex!]['elec']} kWh", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.orange)),
                          Text("→ ${formatCurrency(chartDailyData[selectedBarIndex!]['elec_cost'])}", style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(height: 40, width: 1, color: Colors.orange.shade200),
                      Column(
                        children: [
                          const Text("Water", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("${chartDailyData[selectedBarIndex!]['water'].toStringAsFixed(1)} m³", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.blue)),
                          Text("→ ${formatCurrency(chartDailyData[selectedBarIndex!]['water_cost'])}", style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String title, num amount, IconData icon, Color iconColor, {String? subtitle, List<Widget>? details}) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)) : null,
        trailing: Text(formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        children: details != null && details.isNotEmpty
            ? [
          Container(
            padding: const EdgeInsets.all(15),
            margin: const EdgeInsets.only(left: 20, right: 20, bottom: 15),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: details),
          )
        ]
            : [],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: 14, color: color ?? Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.invoiceData['status'] ?? "UNPAID";
    String billingPeriod = widget.invoiceData['billing_period'] ?? "Current Month";

    DateTime due = _parseSafeDate(widget.invoiceData['due_date']);
    String dueStr = "${due.day.toString().padLeft(2, '0')} ${DateFormat('MMM yyyy').format(due)}";

    String availableDateStr = "01 ${DateFormat('MMM yyyy').format(due)}";

    Color statusColor = colorWarning;
    IconData statusIcon = Icons.pending_actions;
    if (status.toUpperCase() == "PAID") { statusColor = colorSuccess; statusIcon = Icons.check_circle; }
    else if (status.toUpperCase() == "OVERDUE") { statusColor = colorDanger; statusIcon = Icons.warning; }
    else if (status.toUpperCase() == "PENDING") { statusColor = Colors.blue; statusIcon = Icons.hourglass_top; }

    return Scaffold(
        backgroundColor: const Color(0xffF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0, centerTitle: true,
          title: Column(
            children: [
              Text("Invoice for $billingPeriod", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
              Text(widget.invoiceId, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 14),
                              const SizedBox(width: 5),
                              Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: widget.isCurrentMonth ? Colors.blue.shade100 : Colors.purple.shade100, borderRadius: BorderRadius.circular(20)),
                          child: Text(widget.isCurrentMonth ? "ESTIMATED" : "FINAL INVOICE", style: TextStyle(color: widget.isCurrentMonth ? Colors.blue.shade800 : Colors.purple.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Text("Total Amount", style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 5),
                    Text(formatCurrency(displayTotalAmount), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: colorSecondary, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Text(widget.isCurrentMonth ? "Available to Pay: $availableDateStr" : "Due Date: $dueStr", style: TextStyle(color: status == "OVERDUE" ? colorDanger : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),

              if (!widget.isViewOnly)
                _buildDownloadButton(status.toUpperCase()),

              if (widget.isCurrentMonth)
                _buildInteractiveUsageInsight()
              else
                const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.only(left: 25, bottom: 10),
                child: const Text("Usage & Breakdown", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 15)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 15, bottom: 5),
                      child: Text("Variable Usage Costs", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    ),

                    if (breakdown['electricity'] != null) ...[
                      _buildBreakdownItem("Electricity", breakdown['electricity']['amount'], Icons.bolt, Colors.orange, subtitle: "Total Usage: ${breakdown['electricity']['usage']} kWh", details: [
                        _detailRow("Accumulated Usage", "${breakdown['electricity']['usage']} kWh"),
                        _detailRow("Tariff / kWh", formatCurrency(breakdown['electricity']['tariff'])),
                        const Divider(),
                        _detailRow("Subtotal", formatCurrency(breakdown['electricity']['amount']), isBold: true),
                      ]),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                    ],

                    if (breakdown['water'] != null) ...[
                      _buildBreakdownItem("Water", breakdown['water']['amount'], Icons.water_drop, Colors.blue, subtitle: "Total Usage: ${breakdown['water']['usage']} m³", details: [
                        _detailRow("Accumulated Usage", "${breakdown['water']['usage']} m³"),
                        _detailRow("Tariff / m³", formatCurrency(breakdown['water']['tariff'])),
                        const Divider(),
                        _detailRow("Subtotal", formatCurrency(breakdown['water']['amount']), isBold: true),
                      ]),
                      const Divider(height: 1, indent: 20, endIndent: 20),
                    ],

                    Padding(
                      padding: const EdgeInsets.only(left: 20, top: 15, bottom: 5),
                      child: Text("Fixed Charges", style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                    ),

                    if (breakdown['maintenance'] != null) ...[
                      _buildBreakdownItem("Maintenance (IPL)", breakdown['maintenance']['amount'], Icons.cleaning_services, Colors.teal, subtitle: breakdown['maintenance']['prorated'] == true ? "Prorated Fixed Charge" : "Fixed Monthly Charge"),
                      if (breakdown['parking'] != null && breakdown['parking']['amount'] > 0 || breakdown['penalty'] != null) const Divider(height: 1, indent: 20, endIndent: 20),
                    ],

                    if (breakdown['parking'] != null && breakdown['parking']['amount'] > 0) ...[
                      _buildBreakdownItem("Parking Membership", breakdown['parking']['amount'], Icons.local_parking, Colors.indigo, subtitle: breakdown['parking']['desc']),
                      if (breakdown['penalty'] != null) const Divider(height: 1, indent: 20, endIndent: 20),
                    ],

                    if (breakdown['penalty'] != null) ...[
                      _buildBreakdownItem("Late Fee Penalty", breakdown['penalty']['amount'], Icons.gavel, colorDanger, subtitle: breakdown['penalty']['desc'], details: [
                        _detailRow("Total Penalty", formatCurrency(breakdown['penalty']['amount']), isBold: true, color: colorDanger),
                      ]),
                    ],

                    const SizedBox(height: 10),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),

        bottomNavigationBar: () {
          if (status.toUpperCase() == "PAID" || status.toUpperCase() == "PENDING" || widget.isCurrentMonth) {
            if (widget.isCurrentMonth) {
              return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.track_changes, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text("Tracking usage daily...", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  )
              );
            }
            return null;
          }

          if (!widget.isViewOnly) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: colorPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: _showPaymentOptions,
                    child: const Text("Pay Bill Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
            );
          }

          return null;
        }()
    );
  }
}
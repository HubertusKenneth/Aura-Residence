import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class UnitBookingSteps extends StatefulWidget {
  final Map<String, dynamic> applicationData;
  final String uid;
  final String applicationId;

  const UnitBookingSteps({
    Key? key,
    required this.applicationData,
    required this.uid,
    required this.applicationId
  }) : super(key: key);

  @override
  State<UnitBookingSteps> createState() => _UnitBookingStepsState();
}

class _UnitBookingStepsState extends State<UnitBookingSteps> {
  bool isKtpUploaded = false;
  bool isPayslipUploaded = false;

  void _simulateUpload(String docType) async {
    Fluttertoast.showToast(msg: "Uploading $docType...");
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      if (docType == "KTP") isKtpUploaded = true;
      if (docType == "Payslip") isPayslipUploaded = true;
    });
    Fluttertoast.showToast(msg: "$docType Uploaded Successfully!");
  }

  @override
  Widget build(BuildContext context) {
    bool canProceed = isKtpUploaded && isPayslipUploaded;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text("Step 1: Upload Docs"), backgroundColor: Colors.blueGrey, iconTheme: const IconThemeData(color: Colors.white), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("Please upload supporting documents for Admin verification.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            _buildUploadCard("ID Card (KTP / Passport)", isKtpUploaded, () => _simulateUpload("KTP")),
            const SizedBox(height: 15),
            _buildUploadCard("Payslip / Employment Letter", isPayslipUploaded, () => _simulateUpload("Payslip")),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: canProceed ? const Color(0xffF9A826) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: canProceed ? () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ContractPage(applicationData: widget.applicationData, uid: widget.uid, applicationId: widget.applicationId)));
                } : null,
                child: const Text("Next: Review Lease Agreement", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(String title, bool isUploaded, VoidCallback onTap) {
    return ListTile(
      tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isUploaded ? Colors.green : Colors.grey.shade300)),
      leading: Icon(isUploaded ? Icons.check_circle : Icons.upload_file, color: isUploaded ? Colors.green : Colors.blueGrey),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      trailing: isUploaded ? const Text("Uploaded", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)) : TextButton(onPressed: onTap, child: const Text("Upload")),
    );
  }
}

class ContractPage extends StatefulWidget {
  final Map<String, dynamic> applicationData;
  final String uid;
  final String applicationId;

  const ContractPage({Key? key, required this.applicationData, required this.uid, required this.applicationId}) : super(key: key);

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage> {
  bool isAgreed = false;
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text("Step 2: Lease Agreement"), backgroundColor: Colors.blueGrey, iconTheme: const IconThemeData(color: Colors.white), foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Please read the agreement carefully.", style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
                child: const SingleChildScrollView(
                    child: Text(
                        "LEASE AGREEMENT & RULES\n\n1. Tenant must pay rent on time.\n2. No smoking inside the unit.\n3. The security deposit is refundable at the end of the lease term provided there are no damages.\n4. Sub-leasing to third parties is strictly prohibited.\n5. Any modifications to the unit must require prior approval from the owner.",
                        style: TextStyle(color: Colors.black87, height: 1.5)
                    )
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Checkbox(value: isAgreed, activeColor: const Color(0xffF9A826), onChanged: (val) => setState(() => isAgreed = val!)),
                const Expanded(child: Text("I have read and agree to the terms and conditions above."))
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isAgreed ? const Color(0xffF9A826) : Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: (isAgreed && !isSubmitting) ? () async {
                  setState(() { isSubmitting = true; });
                  try {
                    await FirebaseFirestore.instance.collection("RentalApplications").doc(widget.applicationId).update({
                      "status": "Pending Admin Doc Verification", // Ke tahap 3
                      "docs_uploaded": true,
                      "terms_agreed": true,
                      "updatedAt": FieldValue.serverTimestamp() // Agar sorting Admin naik
                    });
                    Fluttertoast.showToast(msg: "Documents Submitted for Admin Verification!");
                    Navigator.pop(context);
                    Navigator.pop(context);
                  } catch(e) { Fluttertoast.showToast(msg: "Error: $e"); } finally { if(mounted) setState(() { isSubmitting = false; }); }
                } : null,
                child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Submit Documents", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> applicationData;
  final String uid;
  final String applicationId;

  const PaymentPage({Key? key, required this.applicationData, required this.uid, required this.applicationId}) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String selectedMethod = "Bank Transfer";
  bool isSubmitting = false;

  String formatCurrency(int amount) => "Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}";

  Future<void> _submitAll() async {
    setState(() { isSubmitting = true; });
    await Future.delayed(const Duration(seconds: 2));
    try {
      await FirebaseFirestore.instance.collection("RentalApplications").doc(widget.applicationId).update({
        "status": "Payment Verification Pending",
        "payment_method": selectedMethod,
        "updatedAt": FieldValue.serverTimestamp()
      });

      var secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
      if (secQuery.docs.isNotEmpty) {
        String secId = secQuery.docs.first.id;
        try {
          await FirebaseFirestore.instance.collection('Secretary').doc(secId).collection('Members').doc(widget.uid).collection('Bookings').doc(widget.applicationId).update({'status': 'Payment Verification Pending'});
        } catch(e){}
      }

      await FirebaseFirestore.instance.collection("Users").doc(widget.uid).collection("Notifications").add({
        "title": "Payment Sent",
        "body": "Your payment for Unit ${widget.applicationData['unit_no']} is waiting for Admin verification.",
        "timestamp": FieldValue.serverTimestamp(),
        "isRead": false,
      });

      Fluttertoast.showToast(msg: "Payment Sent for Verification!");
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      if (mounted) setState(() { isSubmitting = false; });
    }
  }

  Widget _buildPaymentOption(String title, String subtitle, IconData icon, String value) {
    bool isSelected = selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => selectedMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isSelected ? const Color(0xffF9A826).withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isSelected ? const Color(0xffF9A826) : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [] : [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))
            ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isSelected ? const Color(0xffF9A826).withOpacity(0.1) : Colors.grey.shade100,
                  shape: BoxShape.circle
              ),
              child: Icon(icon, color: isSelected ? const Color(0xffF9A826) : Colors.grey.shade600, size: 22),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSelected ? Colors.black87 : Colors.grey.shade700)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ]
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: selectedMethod,
              activeColor: const Color(0xffF9A826),
              onChanged: (v) => setState(() => selectedMethod = v.toString()),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isExtension = widget.applicationData['transaction_type'] == 'Lease Extension';
    int totalPayment = 0;

    if (isExtension) {
      totalPayment = widget.applicationData['requested_payment'] ?? widget.applicationData['total_payment'] ?? 0;
    } else {
      totalPayment = widget.applicationData['total_payment'] ?? 0;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Secure Payment", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- TOTAL PAYMENT CARD ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade900],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.blueGrey.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
                          ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text("Total Payment Amount", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 10),
                          Text(formatCurrency(totalPayment), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),

                          if (isExtension) ...[
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white30)
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.more_time, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text("Lease Extension: ${widget.applicationData['requested_duration']}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )
                          ] else ...[
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white30)
                              ),
                              child: Text("Unit ${widget.applicationData['unit_no']} • ${widget.applicationData['tower']}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            )
                          ]
                        ],
                      ),
                    ),

                    const SizedBox(height: 35),
                    const Text("Select Payment Method", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                    const SizedBox(height: 15),

                    // --- PAYMENT OPTIONS ---
                    _buildPaymentOption(
                        "Virtual Account / Bank Transfer",
                        "BCA, Mandiri, BNI, BRI, etc.",
                        Icons.account_balance,
                        "Bank Transfer"
                    ),
                    _buildPaymentOption(
                        "E-Wallet & QRIS",
                        "GoPay, OVO, Dana, ShopeePay",
                        Icons.qr_code_scanner,
                        "E-Wallet"
                    ),
                    _buildPaymentOption(
                        "Credit / Debit Card",
                        "Visa, Mastercard, JCB",
                        Icons.credit_card,
                        "Credit Card"
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))
                  ]
              ),
              child: SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF9A826),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0
                  ),
                  onPressed: isSubmitting ? null : _submitAll,
                  child: isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text("Confirm & Pay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

class ParkingPage extends StatefulWidget {
  final String unitNo;
  const ParkingPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<ParkingPage> createState() => _ParkingPageState();
}

class _ParkingPageState extends State<ParkingPage> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;

  final Color colorPrimary = const Color(0xffF59E0B);
  final Color colorSuccess = Colors.green.shade600;
  final Color colorWarning = Colors.amber.shade600;
  final Color colorDanger = Colors.red.shade600;
  final Color colorInfo = Colors.blueGrey.shade700;

  final List<String> vehicleColors = ['Black', 'White', 'Silver', 'Grey', 'Red', 'Blue', 'Yellow', 'Green', 'Other'];
  final List<String> carBrands = ['Toyota', 'Honda', 'Daihatsu', 'Mitsubishi', 'Suzuki', 'Nissan', 'Hyundai', 'Mazda', 'Wuling', 'BMW', 'Mercedes-Benz', 'Other'];
  final List<String> motoBrands = ['Honda', 'Yamaha', 'Suzuki', 'Kawasaki', 'Vespa', 'Piaggio', 'KTM', 'Other'];

  final int carPricePerMonth = 200000;
  final int motoPricePerMonth = 100000;

  bool isLoadingLease = true;
  bool isPermanent = false;
  int remainingMonths = 0;
  DateTime? leaseEndDate;
  String userTower = "Unknown";
  String userName = "Resident";

  String currentRole = "Unknown";
  bool isUnitRentedOut = false;

  @override
  void initState() {
    super.initState();
    _fetchLeaseData();
  }

  Future<void> _fetchLeaseData() async {
    try {
      var userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (userDoc.exists) {
        userName = userDoc.data()?['name'] ?? userDoc.data()?['fullName'] ?? FirebaseAuth.instance.currentUser?.displayName ?? "Resident";
      }

      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits')
          .where('unit_no', isEqualTo: widget.unitNo)
          .where('ownerUid', isEqualTo: uid)
          .get();

      if (unitQuery.docs.isNotEmpty) {
        currentRole = "Owner";
        var unitData = unitQuery.docs.first.data();
        userTower = unitData['tower'] ?? "Unknown";
        if (unitData['ownerName'] != null) userName = unitData['ownerName'];

        isPermanent = true;
        remainingMonths = 999;

        var checkRented = await FirebaseFirestore.instance.collection('RentalApplications')
            .where('unit_no', isEqualTo: widget.unitNo)
            .where('status', whereIn: ['Occupied', 'Approved & Active'])
            .get();

        if (checkRented.docs.isNotEmpty) {
          isUnitRentedOut = true;
        }
      } else {
        var rentQuery = await FirebaseFirestore.instance.collection('RentalApplications')
            .where('tenantUid', isEqualTo: uid)
            .where('unit_no', isEqualTo: widget.unitNo)
            .where('status', whereIn: ['Occupied', 'Approved & Active'])
            .get();

        if (rentQuery.docs.isNotEmpty) {
          currentRole = "Tenant";
          var data = rentQuery.docs.first.data();
          userTower = data['tower'] ?? "Unknown";
          if (data['tenantName'] != null) userName = data['tenantName'];

          if (data['contract_end_date'] == 'Permanent') {
            isPermanent = true;
            remainingMonths = 999;
          } else {
            DateTime end = DateTime.parse(data['contract_end_date']);
            leaseEndDate = end;
            DateTime now = DateTime.now();
            remainingMonths = (end.year - now.year) * 12 + end.month - now.month;
            if (remainingMonths < 0) remainingMonths = 0;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching lease: $e");
    } finally {
      setState(() => isLoadingLease = false);
    }
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  void _showPaymentHistory(String membershipId) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Payment History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              const Divider(),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("parking_payments")
                        .where("membership_id", isEqualTo: membershipId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No payments found."));

                      var docs = snapshot.data!.docs.toList();
                      docs.sort((a, b) {
                        Timestamp? tA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        Timestamp? tB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                        if (tA == null && tB == null) return 0;
                        if (tA == null) return -1;
                        if (tB == null) return 1;
                        return tB.compareTo(tA);
                      });

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          var data = docs[index].data() as Map<String, dynamic>;
                          String method = data['payment_method'] ?? 'Unknown';
                          int amount = data['amount'] ?? 0;

                          String dateStr = "Just Now";
                          if (data['timestamp'] != null) {
                            DateTime dt = (data['timestamp'] as Timestamp).toDate();
                            dateStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                          }

                          IconData methodIcon = Icons.payment;
                          Color methodColor = Colors.grey;
                          if (method.contains("QRIS")) { methodIcon = Icons.qr_code; methodColor = Colors.blue; }
                          else if (method.contains("Credit")) { methodIcon = Icons.credit_card; methodColor = Colors.orange; }
                          else if (method.contains("Virtual")) { methodIcon = Icons.account_balance; methodColor = Colors.green; }

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(backgroundColor: methodColor.withOpacity(0.1), child: Icon(methodIcon, color: methodColor, size: 20)),
                            title: Text(formatCurrency(amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("$method • $dateStr", style: const TextStyle(fontSize: 12)),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Text(data['status'] ?? "Paid", style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      );
                    }
                ),
              )
            ],
          ),
        )
    );
  }

  void _showExtendDialog(String membershipId, Map<String, dynamic> data) {
    DateTime currentParkingEnd = DateTime.parse(data['end_date']);
    int availableExtendMonths = 999;

    if (!isPermanent && leaseEndDate != null) {
      availableExtendMonths = (leaseEndDate!.year - currentParkingEnd.year) * 12 + leaseEndDate!.month - currentParkingEnd.month;
      if (availableExtendMonths < 0) availableExtendMonths = 0;
    }

    if (availableExtendMonths <= 0 && !isPermanent) {
      Fluttertoast.showToast(msg: "You cannot extend parking beyond your apartment lease limit.", backgroundColor: colorDanger);
      return;
    }

    int selectedDuration = 1;
    String type = data['vehicle_type'];
    String plate = data['vehicle_plate'];

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
            builder: (context, setModalState) {
              int pricePerMonth = type == "Car" ? carPricePerMonth : motoPricePerMonth;
              int totalPrice = pricePerMonth * selectedDuration;

              return Container(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Extend Parking Membership", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text("Vehicle: $plate ($type)", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 20),

                      if (!isPermanent)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(color: colorInfo.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: colorInfo, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text("You can extend up to a maximum of $availableExtendMonths month(s) based on your remaining apartment lease.", style: TextStyle(color: colorInfo, fontSize: 12))),
                            ],
                          ),
                        ),

                      const Text("Select Additional Duration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10, runSpacing: 10,
                        children: [1, 3, 6, 12].map((months) {
                          bool isAllowed = isPermanent || months <= availableExtendMonths;
                          bool isSelected = selectedDuration == months;

                          return GestureDetector(
                            onTap: isAllowed ? () => setModalState(() => selectedDuration = months) : null,
                            child: Container(
                              width: (MediaQuery.of(context).size.width - 50) / 2,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: isAllowed ? (isSelected ? colorPrimary.withOpacity(0.1) : Colors.white) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isAllowed ? (isSelected ? colorPrimary : Colors.grey.shade300) : Colors.grey.shade200),
                              ),
                              child: Center(
                                  child: Text("+$months Month${months > 1 ? 's' : ''}",
                                      style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isAllowed ? (isSelected ? colorPrimary : Colors.black87) : Colors.grey.shade400
                                      )
                                  )
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Rate / Month:", style: TextStyle(color: Colors.grey)), Text(formatCurrency(pricePerMonth), style: const TextStyle(fontWeight: FontWeight.bold))]),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Payment:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(formatCurrency(totalPrice), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorPrimary))]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: colorPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            Navigator.pop(context);
                            _showPaymentMethodDialog(
                                plate: plate,
                                type: type,
                                brand: data['vehicle_brand'] ?? '',
                                color: data['vehicle_color'] ?? '',
                                duration: selectedDuration,
                                total: totalPrice,
                                isExtension: true,
                                existingMembershipId: membershipId,
                                currentEndDate: currentParkingEnd,
                                monthlyFee: pricePerMonth
                            );
                          },
                          child: const Text("Proceed to Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
            }
        )
    );
  }

  void _showStopMembershipDialog(String membershipId) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red),
                const SizedBox(width: 10),
                const Text("Stop Membership?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            content: const Text(
                "Are you sure you want to stop your parking membership?\n\nYou will still be billed for the current month if you stop now. Your slot will be released, and you can register a new vehicle anytime.",
                style: TextStyle(height: 1.4)
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  await FirebaseFirestore.instance.collection('parking_memberships').doc(membershipId).update({
                    'status': 'Stopped',
                    'stopped_at': FieldValue.serverTimestamp(),
                  });
                  Fluttertoast.showToast(msg: "Parking membership stopped successfully.", backgroundColor: Colors.black87);
                },
                child: const Text("Yes, Stop", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ]
        )
    );
  }

  void _showRegistrationDialog() {
    if (remainingMonths <= 0 && !isPermanent) {
      Fluttertoast.showToast(msg: "Your lease has expired. Please extend your lease first.", backgroundColor: colorDanger);
      return;
    }

    String selectedType = "Car";
    String? selectedColor;
    String? selectedBrand;
    int selectedDuration = 1;
    bool isStnkUploaded = false;

    TextEditingController plateCtrl = TextEditingController();
    String? plateError;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => StatefulBuilder(
            builder: (context, setModalState) {

              int pricePerMonth = selectedType == "Car" ? carPricePerMonth : motoPricePerMonth;
              int totalPrice = pricePerMonth * selectedDuration;

              String endStr = isPermanent ? "Permanent Ownership" : "$remainingMonths months remaining (Ends: ${leaseEndDate!.day.toString().padLeft(2, '0')}/${leaseEndDate!.month.toString().padLeft(2, '0')}/${leaseEndDate!.year})";

              return Container(
                height: MediaQuery.of(context).size.height * 0.9,
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Register Vehicle", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 5),
                      const Text("Request parking membership & proceed to payment.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: colorInfo.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: colorInfo.withOpacity(0.1))),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, color: colorInfo),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Your Lease Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(endStr, style: TextStyle(color: colorInfo, fontSize: 13)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text("Vehicle Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() { selectedType = "Car"; selectedBrand = null; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: selectedType == "Car" ? colorPrimary.withOpacity(0.1) : Colors.grey.shade50, border: Border.all(color: selectedType == "Car" ? colorPrimary : Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                                child: Column(children: [Icon(Icons.directions_car, color: selectedType == "Car" ? colorPrimary : Colors.grey), const SizedBox(height: 5), Text("Car", style: TextStyle(fontWeight: FontWeight.bold, color: selectedType == "Car" ? colorPrimary : Colors.grey))]),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setModalState(() { selectedType = "Motorcycle"; selectedBrand = null; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(color: selectedType == "Motorcycle" ? colorPrimary.withOpacity(0.1) : Colors.grey.shade50, border: Border.all(color: selectedType == "Motorcycle" ? colorPrimary : Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                                child: Column(children: [Icon(Icons.two_wheeler, color: selectedType == "Motorcycle" ? colorPrimary : Colors.grey), const SizedBox(height: 5), Text("Motorcycle", style: TextStyle(fontWeight: FontWeight.bold, color: selectedType == "Motorcycle" ? colorPrimary : Colors.grey))]),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text("Select Membership Duration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10, runSpacing: 10,
                        children: [1, 3, 6, 12].map((months) {
                          bool isAllowed = isPermanent || months <= remainingMonths;
                          bool isSelected = selectedDuration == months;

                          return GestureDetector(
                            onTap: isAllowed ? () => setModalState(() => selectedDuration = months) : () {
                              Fluttertoast.showToast(msg: "Duration cannot exceed your remaining lease ($remainingMonths months).", backgroundColor: colorWarning);
                            },
                            child: Container(
                              width: (MediaQuery.of(context).size.width - 50) / 2,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: isAllowed ? (isSelected ? colorPrimary.withOpacity(0.1) : Colors.white) : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isAllowed ? (isSelected ? colorPrimary : Colors.grey.shade300) : Colors.grey.shade200),
                              ),
                              child: Center(
                                  child: Text("$months Month${months > 1 ? 's' : ''}",
                                      style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isAllowed ? (isSelected ? colorPrimary : Colors.black87) : Colors.grey.shade400
                                      )
                                  )
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      if (!isPermanent && remainingMonths < 12) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: colorWarning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: colorWarning, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text("Options exceeding your lease ($remainingMonths mo) are disabled.", style: TextStyle(color: colorWarning, fontSize: 11))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      TextField(
                          controller: plateCtrl,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (value) { if (plateError != null) setModalState(() => plateError = null); },
                          decoration: InputDecoration(labelText: "License Plate (e.g. B 1234 XYZ)", border: const OutlineInputBorder(), errorText: plateError)
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: selectedBrand, decoration: const InputDecoration(labelText: 'Vehicle Brand', border: OutlineInputBorder()),
                        items: (selectedType == "Car" ? carBrands : motoBrands).map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setModalState(() => selectedBrand = val!),
                      ),
                      const SizedBox(height: 15),
                      DropdownButtonFormField<String>(
                        value: selectedColor, decoration: const InputDecoration(labelText: 'Vehicle Color', border: OutlineInputBorder()),
                        items: vehicleColors.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) => setModalState(() => selectedColor = val!),
                      ),
                      const SizedBox(height: 15),

                      GestureDetector(
                        onTap: () {
                          Fluttertoast.showToast(msg: "Uploading STNK...");
                          Future.delayed(const Duration(seconds: 1), () {
                            setModalState(() => isStnkUploaded = true);
                            Fluttertoast.showToast(msg: "STNK Uploaded Successfully!");
                          });
                        },
                        child: Container(
                          width: double.infinity, padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                              color: isStnkUploaded ? colorSuccess.withOpacity(0.1) : Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isStnkUploaded ? colorSuccess.withOpacity(0.5) : Colors.blue.shade200)
                          ),
                          child: Column(
                              children: [
                                Icon(isStnkUploaded ? Icons.check_circle : Icons.upload_file, color: isStnkUploaded ? colorSuccess : Colors.blue, size: 30),
                                const SizedBox(height: 8),
                                Text(isStnkUploaded ? "STNK_Document.pdf (Uploaded)" : "Tap to Upload STNK Document *", style: TextStyle(color: isStnkUploaded ? colorSuccess : Colors.blue, fontWeight: FontWeight.bold))
                              ]
                          ),
                        ),
                      ),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),

                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(
                          children: [
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Duration:", style: TextStyle(color: Colors.grey)), Text("$selectedDuration Month(s)", style: const TextStyle(fontWeight: FontWeight.bold))]),
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Rate / Month:", style: TextStyle(color: Colors.grey)), Text(formatCurrency(pricePerMonth), style: const TextStyle(fontWeight: FontWeight.bold))]),
                            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Payment:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(formatCurrency(totalPrice), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorPrimary))]),
                          ],
                        ),
                      ),

                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: colorPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () async {
                            String plate = plateCtrl.text.trim().toUpperCase();
                            RegExp plateRegex = RegExp(r'^[A-Z]{1,2}\s\d{1,4}\s[A-Z]{1,3}$');
                            if (!plateRegex.hasMatch(plate)) {
                              setModalState(() => plateError = "Invalid format! Use format like: B 1234 XYZ");
                              return;
                            }
                            if (selectedBrand == null) { Fluttertoast.showToast(msg: "Please select a Vehicle Brand"); return; }
                            if (selectedColor == null) { Fluttertoast.showToast(msg: "Please select a Vehicle Color"); return; }
                            if (!isStnkUploaded) { Fluttertoast.showToast(msg: "Please upload STNK Document"); return; }

                            Navigator.pop(context);
                            _showPaymentMethodDialog(
                                plate: plate, type: selectedType, brand: selectedBrand!,
                                color: selectedColor!, duration: selectedDuration, total: totalPrice,
                                isExtension: false, monthlyFee: pricePerMonth
                            );
                          },
                          child: const Text("Proceed to Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              );
            }
        )
    );
  }

  void _showPaymentMethodDialog({
    required String plate, required String type, required String brand, required String color,
    required int duration, required int total, required bool isExtension,
    String? existingMembershipId, DateTime? currentEndDate, required int monthlyFee
  }) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text("Select Payment Method", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.qr_code, color: Colors.blue),
                    title: const Text("QRIS"),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                    onTap: () {
                      Navigator.pop(context);
                      _processPaymentAndSubmit(plate, type, brand, color, duration, total, "QRIS", isExtension, existingMembershipId, currentEndDate, monthlyFee);
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.credit_card, color: Colors.orange),
                    title: const Text("Credit Card"),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                    onTap: () {
                      Navigator.pop(context);
                      _processPaymentAndSubmit(plate, type, brand, color, duration, total, "Credit Card", isExtension, existingMembershipId, currentEndDate, monthlyFee);
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(Icons.account_balance, color: Colors.green),
                    title: const Text("Virtual Account Transfer"),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                    onTap: () {
                      Navigator.pop(context);
                      _processPaymentAndSubmit(plate, type, brand, color, duration, total, "Virtual Account", isExtension, existingMembershipId, currentEndDate, monthlyFee);
                    },
                  )
                ],
              )
          );
        }
    );
  }

  void _processPaymentAndSubmit(String plate, String type, String brand, String color, int duration, int total, String method, bool isExtension, String? existingMembershipId, DateTime? currentEndDate, int monthlyFee) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text("Processing $method Payment..."),
                  Text(formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              )
          );
        }
    );

    Future.delayed(const Duration(seconds: 2), () async {
      Navigator.of(context, rootNavigator: true).pop();

      try {
        DateTime now = DateTime.now();
        String mId = existingMembershipId ?? "";

        if (isExtension && existingMembershipId != null && currentEndDate != null) {
          DateTime newEndDate = DateTime(currentEndDate.year, currentEndDate.month + duration, currentEndDate.day);

          await FirebaseFirestore.instance.collection("parking_memberships").doc(existingMembershipId).update({
            "end_date": newEndDate.toIso8601String(),
            "paid_until": newEndDate.toIso8601String(), // Flag auto-renew billing
            "duration_months": FieldValue.increment(duration),
          });
          Fluttertoast.showToast(msg: "Membership Extended Successfully!", backgroundColor: colorSuccess);
        } else {
          DateTime endDate = DateTime(now.year, now.month + duration, now.day);

          DocumentReference membershipRef = await FirebaseFirestore.instance.collection("parking_memberships").add({
            "user_id": uid,
            "unit_no": widget.unitNo,
            "tower": userTower,
            "role": currentRole.toLowerCase(),
            "holder_name": userName,
            "vehicle_type": type,
            "vehicle_plate": plate,
            "vehicle_brand": brand,
            "vehicle_color": color,
            "status": "Pending",
            "slot_id": "-",
            "start_date": now.toIso8601String(),
            "end_date": endDate.toIso8601String(),
            "paid_until": endDate.toIso8601String(), // Flag auto-renew billing
            "monthly_fee": monthlyFee,
            "duration_months": duration,
            "timestamp": FieldValue.serverTimestamp(),
          });
          mId = membershipRef.id;
          Fluttertoast.showToast(msg: "Payment Successful! Waiting for Admin Approval.", backgroundColor: colorSuccess);
        }

        await FirebaseFirestore.instance.collection("parking_payments").add({
          "membership_id": mId,
          "user_id": uid,
          "amount": total,
          "status": "Paid",
          "payment_method": method,
          "description": isExtension ? "Extension Payment ($duration Mo)" : "Initial Registration ($duration Mo)",
          "timestamp": FieldValue.serverTimestamp(),
        });

      } catch (e) {
        Fluttertoast.showToast(msg: "Error saving data: $e", backgroundColor: colorDanger);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingLease) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: const Text("Parking Dashboard", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("parking_memberships").where("unit_no", isEqualTo: widget.unitNo).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: colorPrimary));

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }
          var validMemberships = snapshot.data!.docs.where((doc) {
            var status = (doc.data() as Map<String, dynamic>)['status'];
            return status == "Active" || status == "Pending";
          }).toList();

          if (validMemberships.isEmpty) return _buildEmptyState();

          var membership = validMemberships.first;
          Map<String, dynamic> data = membership.data() as Map<String, dynamic>;

          String status = data['status'] ?? "Pending";
          bool isActive = status == "Active";
          bool isPending = status == "Pending";

          String holderName = data['holder_name'] ?? (data['role'] != null ? data['role'].toString().toUpperCase() : 'UNKNOWN');

          String endStr = '-';
          if (isActive && data['end_date'] != null) {
            DateTime dt = DateTime.parse(data['end_date']);
            endStr = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentRole == "Owner" && isUnitRentedOut)
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.shade200)),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, color: Colors.blue, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(child: Text("View-Only Mode. This unit is rented out. Parking rights and operations belong to the active Tenant.", style: TextStyle(color: Colors.blue, fontSize: 12))),
                      ],
                    ),
                  ),

                const Text("Vehicle Status", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                const SizedBox(height: 15),

                Container(
                  width: double.infinity, padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))]
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: isActive ? colorSuccess.withOpacity(0.1) : colorWarning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Text(status.toUpperCase(), style: TextStyle(color: isActive ? colorSuccess : colorWarning, fontWeight: FontWeight.bold, fontSize: 11)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Text("Held by: ${holderName.toUpperCase()}", style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(data['vehicle_plate'], style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.5)),
                      Text("${data['vehicle_brand'] ?? 'Unknown'} • ${data['vehicle_color'] ?? ''}", style: const TextStyle(color: Colors.grey, fontSize: 13)),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Assigned Slot", style: TextStyle(fontSize: 11, color: Colors.grey)),
                              const SizedBox(height: 4),
                              Text(data['slot_id'] == "-" ? "Awaiting Assignment" : data['slot_id'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isPending ? Colors.grey : colorPrimary)),
                            ],
                          ),
                          if (isActive)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text("Valid Until", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(endStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                              ],
                            ),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                if (!(currentRole == "Owner" && isUnitRentedOut)) ...[
                  if (isActive) ...[
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: colorPrimary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _showExtendDialog(membership.id, data),
                        icon: const Icon(Icons.autorenew, color: Colors.white, size: 18),
                        label: const Text("Extend Membership", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: colorInfo, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _showPaymentHistory(membership.id),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text("View Payment History", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 15),

                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: colorDanger, side: BorderSide(color: colorDanger.withOpacity(0.5)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _showStopMembershipDialog(membership.id),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text("Stop Membership", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else if (isPending) ...[
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: colorWarning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [Icon(Icons.hourglass_empty, color: colorWarning), const SizedBox(width: 10), Expanded(child: Text("Payment Received. Your application is under review by Management. You will be notified once a slot is assigned.", style: TextStyle(color: colorWarning, fontSize: 12)))]),
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity, height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: colorInfo, side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _showPaymentHistory(membership.id),
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text("View Payment History", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    )
                  ]
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: colorPrimary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.no_crash_outlined, size: 80, color: colorPrimary)),
            const SizedBox(height: 20),

            if (currentRole == "Owner" && isUnitRentedOut) ...[
              const Text("No Parking Active", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 10),
              const Text("This unit is currently rented out. Only the active tenant can register and manage parking slots.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
            ] else ...[
              const Text("No Vehicle Registered", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 10),
              const Text("Register your vehicle to get an assigned parking slot securely within the building.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: colorPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: _showRegistrationDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Register Vehicle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
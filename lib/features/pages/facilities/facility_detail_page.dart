import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

String formatCurrency(num amount) {
  return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
}

class FacilityDetailPage extends StatelessWidget {
  final String unitNo;
  final Map<String, dynamic> facilityData;

  const FacilityDetailPage({Key? key, required this.unitNo, required this.facilityData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    num slotPrice = (facilityData['price_per_hour'] ?? 0) * 2;
    String displayPrice = slotPrice == 0 ? "Free" : "${formatCurrency(slotPrice)}\n/ slot";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87)
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16)
                    ),
                    child: const Icon(Icons.domain, size: 60, color: Colors.blue)
                ),
                const SizedBox(height: 20),
                Text(facilityData['name'] ?? '', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text(facilityData['category'] ?? '', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),

                Row(
                  children: [
                    _buildInfoItem(Icons.person_outline, "Capacity", "${facilityData['capacity'] ?? 0} people"),
                    _buildInfoItem(Icons.access_time, "Duration", "2 hours / slot"),
                    _buildInfoItem(Icons.payments_outlined, "Price", displayPrice),
                  ],
                ),
                const SizedBox(height: 25),

                const Text("Rules & Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(facilityData['rules'] ?? "No rules specified.", style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.6)),
                const SizedBox(height: 10),

                if (facilityData['deposit_required'] == true)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8)
                    ),
                    child: Text(
                        "⚠️ Refundable Deposit Required: ${formatCurrency(facilityData['deposit_amount'] ?? 0)}",
                        style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffF58220),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SelectDateTimePage(unitNo: unitNo, facilityData: facilityData)));
                },
                child: const Text("Check Availability", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11))
              ]
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}

class SelectDateTimePage extends StatefulWidget {
  final String unitNo;
  final Map<String, dynamic> facilityData;

  const SelectDateTimePage({Key? key, required this.unitNo, required this.facilityData}) : super(key: key);

  @override
  State<SelectDateTimePage> createState() => _SelectDateTimePageState();
}

class _SelectDateTimePageState extends State<SelectDateTimePage> {
  DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
  String? selectedSlot;
  int maxBookingDays = 30;

  final List<Map<String, dynamic>> masterSlots = [
    {"time": "08:00 - 10:00"},
    {"time": "10:00 - 12:00"},
    {"time": "14:00 - 16:00"},
    {"time": "16:00 - 18:00"},
    {"time": "18:00 - 20:00"},
    {"time": "20:00 - 22:00"},
  ];

  Future<void> _selectDateWithCalendar(BuildContext context) async {
    DateTime tomorrow = DateTime.now().add(const Duration(days: 1));

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isBefore(tomorrow) ? tomorrow : selectedDate,
      firstDate: tomorrow,
      lastDate: DateTime.now().add(Duration(days: maxBookingDays)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xffF58220),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        selectedSlot = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    String myUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
          backgroundColor: const Color(0xffF8F9FA),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          centerTitle: true,
          title: const Text("Select Date & Time", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('MMMM yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.calendar_month, color: Color(0xffF58220)),
                        onPressed: () => _selectDateWithCalendar(context),
                      )
                    ]
                ),

                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: maxBookingDays,
                    itemBuilder: (context, index) {
                      DateTime date = DateTime.now().add(Duration(days: index + 1));
                      bool isSelected = date.day == selectedDate.day && date.month == selectedDate.month && date.year == selectedDate.year;

                      return GestureDetector(
                        onTap: () => setState(() { selectedDate = date; selectedSlot = null; }),
                        child: Container(
                          width: 45,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                              color: isSelected ? const Color(0xffF58220) : Colors.transparent,
                              borderRadius: BorderRadius.circular(20)
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(DateFormat('EEE').format(date), style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.grey)),
                              const SizedBox(height: 4),
                              Text("${date.day}", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 30),

                const Text("Available Time Slots", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 15),

                StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("FacilityBookings")
                        .where("facility_id", isEqualTo: widget.facilityData['id'])
                        .where("booking_date", isEqualTo: dateStr)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xffF58220)));
                      }

                      Map<String, Map<String, dynamic>> slotStatusMap = {};

                      if (snapshot.hasData) {
                        for (var doc in snapshot.data!.docs) {
                          var bData = doc.data() as Map<String, dynamic>;
                          String tSlot = bData['time_slot'] ?? '';
                          String bStatus = bData['status'] ?? '';
                          Timestamp? ts = bData['timestamp'] as Timestamp?;

                          if (bStatus == 'REQUESTED' && ts != null) {
                            if (DateTime.now().difference(ts.toDate()).inMinutes >= 30) {
                              continue;
                            }
                          }

                          if (['REQUESTED', 'APPROVED', 'CONFIRMED', 'MAINTENANCE'].contains(bStatus)) {
                            slotStatusMap[tSlot] = bData;
                          }
                        }
                      }

                      return Column(
                        children: masterSlots.map((slot) {
                          String timeKey = slot['time'];
                          var existingBooking = slotStatusMap[timeKey];
                          bool isSelected = selectedSlot == timeKey;

                          bool canBook = false;
                          Color bgColor = isSelected ? const Color(0xffF58220) : Colors.white;
                          Color dotColor = Colors.green;
                          String statusText = "Available";

                          if (existingBooking != null) {
                            String bStatus = existingBooking['status'];
                            String bUid = existingBooking['booked_by_uid'] ?? '';

                            if (bStatus == 'MAINTENANCE') {
                              dotColor = Colors.grey;
                              statusText = "Maintenance";
                            }
                            else if (bStatus == 'REQUESTED') {
                              if (bUid == myUid) {
                                dotColor = Colors.orange;
                                statusText = "Pending Approval";
                              } else {
                                dotColor = Colors.grey.shade500;
                                statusText = "Temporarily Reserved";
                              }
                            }
                            else if (bStatus == 'CONFIRMED' || bStatus == 'APPROVED') {
                              if (bUid == myUid) {
                                dotColor = Colors.blue;
                                statusText = "My Booking";
                              } else {
                                dotColor = Colors.red;
                                statusText = "Booked";
                              }
                            }
                          } else {
                            canBook = true;
                            if (isSelected) {
                              dotColor = Colors.white;
                              statusText = "Selected";
                            }
                          }

                          return GestureDetector(
                            onTap: canBook ? () => setState(() => selectedSlot = timeKey) : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                              decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isSelected ? const Color(0xffF58220) : Colors.grey.shade200)
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(timeKey, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (canBook ? Colors.black87 : Colors.grey))),
                                  Row(
                                      children: [
                                        if (statusText == "Temporarily Reserved")
                                          const Icon(Icons.lock_clock, size: 12, color: Colors.grey)
                                        else
                                          Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),

                                        const SizedBox(width: 6),
                                        Text(statusText, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : dotColor, fontWeight: FontWeight.bold))
                                      ]
                                  )
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }
                ),
              ],
            ),
          ),

          if (selectedSlot != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xffF58220),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => BookingSummaryPage(
                            unitNo: widget.unitNo,
                            facilityData: widget.facilityData,
                            selectedDate: selectedDate,
                            selectedSlot: selectedSlot!
                        )
                    ));
                  },
                  child: const Text("Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            )
        ],
      ),
    );
  }
}

class BookingSummaryPage extends StatefulWidget {
  final String unitNo;
  final Map<String, dynamic> facilityData;
  final DateTime selectedDate;
  final String selectedSlot;

  const BookingSummaryPage({Key? key, required this.unitNo, required this.facilityData, required this.selectedDate, required this.selectedSlot}) : super(key: key);

  @override
  State<BookingSummaryPage> createState() => _BookingSummaryPageState();
}

class _BookingSummaryPageState extends State<BookingSummaryPage> {
  int attendees = 2;
  TextEditingController notesCtrl = TextEditingController();
  bool isSubmitting = false;

  Future<void> _submitBooking() async {
    setState(() => isSubmitting = true);
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      var activeBookings = await FirebaseFirestore.instance.collection("FacilityBookings")
          .where("booked_by_uid", isEqualTo: uid)
          .where("status", whereIn: ["REQUESTED", "APPROVED", "CONFIRMED"])
          .get();

      int trueActiveCount = 0;
      for (var doc in activeBookings.docs) {
        var data = doc.data();
        String dateStr = data['booking_date'] ?? "";
        String timeStr = data['time_slot'] ?? "";

        if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
          try {
            String endTimeStr = timeStr.split('-')[1].trim();
            DateTime endTime = DateFormat("yyyy-MM-dd HH:mm").parse("$dateStr $endTimeStr");
            if (DateTime.now().isBefore(endTime)) {
              trueActiveCount++;
            }
          } catch(e) {
            trueActiveCount++;
          }
        } else {
          trueActiveCount++;
        }
      }

      if (trueActiveCount >= 3) {
        Fluttertoast.showToast(msg: "Limit Reached! Max 3 active bookings allowed.", backgroundColor: Colors.red);
        setState(() => isSubmitting = false);
        return;
      }

      String status = "REQUESTED";
      num slotPrice = (widget.facilityData['price_per_hour'] ?? 0) * 2;
      num deposit = widget.facilityData['deposit_amount'] ?? 0;
      num totalToPay = slotPrice + deposit;

      await FirebaseFirestore.instance.collection("FacilityBookings").add({
        "unit_no": widget.unitNo,
        "booked_by_uid": uid,
        "facility_id": widget.facilityData['id'],
        "facility_name": widget.facilityData['name'],
        "facility_type": widget.facilityData['type'] ?? 'Slot-Based',
        "booking_date": DateFormat('yyyy-MM-dd').format(widget.selectedDate),
        "time_slot": widget.selectedSlot,
        "attendees": attendees,
        "notes": notesCtrl.text,
        "slot_price": slotPrice,
        "deposit_amount": deposit,
        "total_price": totalToPay,
        "status": status,
        "timestamp": FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(msg: "Booking Requested! Waiting for Admin.", backgroundColor: Colors.green);

      if (mounted) {
        int count = 0;
        Navigator.of(context).popUntil((_) => count++ >= 2);
      }

    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    num slotPrice = (widget.facilityData['price_per_hour'] ?? 0) * 2;
    num deposit = widget.facilityData['deposit_amount'] ?? 0;
    num total = slotPrice + deposit;

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
          backgroundColor: const Color(0xffF8F9FA),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          centerTitle: true,
          title: const Text("Booking Summary", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200)
                    ),
                    child: Row(
                        children: [
                          Container(
                              height: 50,
                              width: 50,
                              decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)
                              ),
                              child: const Icon(Icons.domain, color: Colors.blue)
                          ),
                          const SizedBox(width: 15),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.facilityData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(widget.facilityData['category'], style: const TextStyle(color: Colors.grey, fontSize: 11))
                              ]
                          )
                        ]
                    )
                ),
                const SizedBox(height: 25),

                _buildRow("Date", DateFormat('dd MMM yyyy (EEEE)').format(widget.selectedDate)),
                _buildRow("Time", widget.selectedSlot),
                _buildRow("Duration", "2 hours"),

                if (widget.facilityData['type'] == 'Capacity-Based')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Attendees", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8)
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.remove, size: 16),
                                  onPressed: attendees > 1 ? () => setState(() => attendees--) : null,
                                  constraints: const BoxConstraints(minWidth: 35, minHeight: 35)
                              ),
                              Text("$attendees", style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                  icon: const Icon(Icons.add, size: 16),
                                  onPressed: () => setState(() => attendees++),
                                  constraints: const BoxConstraints(minWidth: 35, minHeight: 35)
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),

                const SizedBox(height: 10),
                TextField(
                    controller: notesCtrl,
                    decoration: InputDecoration(
                        hintText: "Add notes (Optional)",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))
                    ),
                    maxLines: 2
                ),
                const SizedBox(height: 25),

                const Text("Price Details", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Slot Fee (2 hrs)", style: TextStyle(color: Colors.grey, fontSize: 13)),
                      Text(formatCurrency(slotPrice), style: const TextStyle(fontWeight: FontWeight.bold))
                    ]
                ),

                if (deposit > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Refundable Deposit", style: TextStyle(color: Colors.grey, fontSize: 13)),
                        Text(formatCurrency(deposit), style: const TextStyle(fontWeight: FontWeight.bold))
                      ]
                  ),
                ],

                const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider()),

                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Total Payable", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xffF58220)))
                    ]
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffF58220),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    onPressed: isSubmitting ? null : _submitBooking,
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Confirm Booking", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text(
                        "Requires Admin Approval. Auto-expires in 30 mins.",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                        textAlign: TextAlign.center
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(color: Colors.grey))
            ]
        )
    );
  }
}
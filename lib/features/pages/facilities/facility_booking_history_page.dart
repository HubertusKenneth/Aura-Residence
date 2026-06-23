import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

String formatCurrency(num amount) {
  return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
}

class FacilityBookingHistoryPage extends StatelessWidget {
  final String unitNo;
  const FacilityBookingHistoryPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xffF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white, elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          centerTitle: true,
          title: const Text("My Bookings", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
          bottom: const TabBar(
            labelColor: Color(0xffF58220),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xffF58220),
            indicatorWeight: 3,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Completed"),
              Tab(text: "Cancelled"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(context, "Upcoming"),
            _buildList(context, "Completed"),
            _buildList(context, "Cancelled"),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, String tabType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("FacilityBookings")
          .where("unit_no", isEqualTo: unitNo)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xffF58220)));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No bookings found.", style: TextStyle(color: Colors.grey)));

        List<Map<String, dynamic>> processedDocs = [];

        for (var doc in snapshot.data!.docs) {
          var data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);

          String dbStatus = data['status'] ?? "UNKNOWN";
          String displayStatus = dbStatus;

          Timestamp? ts = data['timestamp'] as Timestamp?;
          if (dbStatus == "REQUESTED" && ts != null) {
            if (DateTime.now().difference(ts.toDate()).inMinutes >= 30) {
              displayStatus = "EXPIRED";
            }
          }

          try {
            String dateStr = data['booking_date'] ?? "";
            String timeStr = data['time_slot'] ?? "";
            if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
              String endTimeStr = timeStr.split('-')[1].trim();
              DateTime endTime = DateFormat("yyyy-MM-dd HH:mm").parse("$dateStr $endTimeStr");

              if (DateTime.now().isAfter(endTime)) {
                if (dbStatus == "CONFIRMED") {
                  displayStatus = "COMPLETED";
                } else if (dbStatus == "REQUESTED" || dbStatus == "APPROVED") {
                  displayStatus = "EXPIRED";
                }
              }
            }
          } catch (e) {
            debugPrint("Time parse error: $e");
          }

          if (displayStatus == "CANCELLED_BY_ADMIN") {
            displayStatus = "Cancelled by Admin";
          }

          bool isUpcoming = ["REQUESTED", "APPROVED", "CONFIRMED"].contains(displayStatus);
          bool isCompleted = ["COMPLETED"].contains(displayStatus);
          bool isCancelled = ["CANCELLED", "REJECTED", "DECLINED", "NO-SHOW", "EXPIRED", "Cancelled by Admin"].contains(displayStatus);

          bool shouldAdd = false;
          if (tabType == "Upcoming" && isUpcoming) shouldAdd = true;
          if (tabType == "Completed" && isCompleted) shouldAdd = true;
          if (tabType == "Cancelled" && isCancelled) shouldAdd = true;

          if (!isUpcoming && !isCompleted && !isCancelled && tabType == "Cancelled") shouldAdd = true;

          if (shouldAdd) {
            data['docId'] = doc.id;
            data['displayStatus'] = displayStatus;
            processedDocs.add(data);
          }
        }

        processedDocs.sort((a, b) {
          Timestamp tA = a['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          Timestamp tB = b['timestamp'] as Timestamp? ?? Timestamp(0, 0);
          return tB.compareTo(tA);
        });

        if (processedDocs.isEmpty) return const Center(child: Text("No bookings found.", style: TextStyle(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: processedDocs.length,
          itemBuilder: (context, index) {
            var data = processedDocs[index];
            String docId = data['docId'];
            String status = data['displayStatus'];

            Color statusColor = Colors.grey;
            Color statusBg = Colors.grey.shade100;

            if (status == 'REQUESTED') { statusColor = Colors.orange; statusBg = Colors.orange.shade50; }
            else if (status == 'APPROVED') { statusColor = Colors.blue; statusBg = Colors.blue.shade50; }
            else if (status == 'CONFIRMED') { statusColor = Colors.green; statusBg = Colors.green.shade50; }
            else if (status == 'COMPLETED') { statusColor = Colors.teal; statusBg = Colors.teal.shade50; }
            else if (status == 'NO-SHOW') { statusColor = Colors.purple; statusBg = Colors.purple.shade50; }
            else { statusColor = Colors.red; statusBg = Colors.red.shade50; }

            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BookingDetailScreen(bookingId: docId, data: data))),
              child: Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 60, width: 60, decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.domain, color: Colors.blueGrey)),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: Text(data['facility_name'] ?? "Facility", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(8)),
                                child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900)),
                              )
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text("${data['booking_date']} • ${data['time_slot']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text("ID: BK-${docId.substring(0,6).toUpperCase()}", style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class BookingDetailScreen extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> data;

  const BookingDetailScreen({Key? key, required this.bookingId, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String status = data['displayStatus'] ?? "UNKNOWN";
    bool isConfirmed = status == 'CONFIRMED';
    bool canCancel = status == 'REQUESTED' || status == 'APPROVED' || status == 'CONFIRMED';

    String bannerMessage = "Booking finalized.";
    if (status == 'REQUESTED') bannerMessage = "Waiting for Admin Approval. Auto-expires in 30 mins.";
    else if (status == 'APPROVED') bannerMessage = "Approved! Please complete payment if required.";
    else if (status == 'NO-SHOW') bannerMessage = "Penalty applied due to no-show.";
    else if (status == 'CANCELLED') bannerMessage = "You have cancelled this booking.";
    else if (status == 'DECLINED') bannerMessage = "Admin declined your request.";
    else if (status == 'EXPIRED') bannerMessage = "Slot expired before confirmation.";
    else if (status == 'COMPLETED') bannerMessage = "Event finished. Hope you enjoyed it!";

    if (status == 'Cancelled by Admin') {
      String reason = data['cancel_reason'] ?? "Operational issues.";
      bannerMessage = "Cancelled by Management.\nReason: $reason";
    }

    Color iconColor = isConfirmed ? Colors.green : (status == 'COMPLETED' ? Colors.teal : Colors.blueGrey);
    if (status == 'Cancelled by Admin' || status == 'DECLINED') iconColor = Colors.red;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black87), centerTitle: true, title: const Text("Booking Detail", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: iconColor == Colors.red ? Colors.red.shade50 : Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(12)
            ),
            child: Row(
              children: [
                Icon(isConfirmed ? Icons.check_circle : (status == 'COMPLETED' ? Icons.stars : (iconColor == Colors.red ? Icons.cancel : Icons.info)), color: iconColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status.toUpperCase(), style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(bannerMessage, style: const TextStyle(fontSize: 12, height: 1.4)),
                    ],
                  ),
                )
              ],
            ),
          ),

          Text(data['facility_name'] ?? "Facility", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _buildDetailRow("Date", data['booking_date'] ?? "-"),
          _buildDetailRow("Time", data['time_slot'] ?? "-"),
          _buildDetailRow("Attendees", "${data['attendees'] ?? 0} people"),
          const Divider(height: 30),
          _buildDetailRow("Slot Price", formatCurrency(data['slot_price'] ?? 0)),
          _buildDetailRow("Deposit", formatCurrency(data['deposit_amount'] ?? 0)),
          _buildDetailRow("Total Payable", formatCurrency(data['total_price'] ?? 0), isBold: true),
          const SizedBox(height: 30),

          if (isConfirmed) ...[
            const Text("Check-in", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 5),
            const Text("Show this QR code to the staff on site.", style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.qr_code_2, size: 100, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 30),
          ],

          if (canCancel)
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: BorderSide(color: Colors.red.shade200), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                FirebaseFirestore.instance.collection("FacilityBookings").doc(bookingId).update({"status": "CANCELLED"});
                Navigator.pop(context);
              },
              child: const Text("Cancel Booking", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)), Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: 14))]));
  }
}
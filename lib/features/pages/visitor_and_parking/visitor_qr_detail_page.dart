import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VisitorQrDetailPage extends StatelessWidget {
  final String passId;
  const VisitorQrDetailPage({Key? key, required this.passId}) : super(key: key);

  final Color _primaryColor = const Color(0xffF9A826);

  bool _isPassExpired(Timestamp? visitDate, String? exitTime) {
    if (visitDate == null || exitTime == null) return false;

    DateTime date = visitDate.toDate();
    try {
      DateTime parsedTime = DateFormat("hh:mm a").parse(exitTime);
      DateTime exactExitTime = DateTime(date.year, date.month, date.day, parsedTime.hour, parsedTime.minute);
      return DateTime.now().isAfter(exactExitTime);
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: const Text("Visitor Pass", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.more_horiz, color: Colors.black87), onPressed: (){})],
      ),
      body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("visitor_passes").doc(passId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: _primaryColor));
            var data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const Center(child: Text("Pass not found"));

            String status = data['status'] ?? 'Expired';

            bool isRealExpired = _isPassExpired(data['visit_date'], data['exit_time']);
            if (isRealExpired && status != 'Cancelled' && status != 'Denied' && status != 'Checked Out') {
              status = 'Expired';
            }

            Color statusColor = status == 'Active' ? Colors.green : (status == 'Upcoming' ? Colors.orange : Colors.red);
            Timestamp? ts = data['visit_date'];
            String dateStr = ts != null ? DateFormat("dd MMM yyyy").format(ts.toDate()) : "";

            String generatedPassId = data['pass_id'] ?? passId;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (status == 'Active' || status == 'Upcoming')
                    Container(
                      width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                      child: const Text("Pass Generated Successfully!\nShare this QR code with your guest", textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))]),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, width: 2),
                              borderRadius: BorderRadius.circular(16)
                          ),
                          child: status == 'Expired' || status == 'Cancelled' || status == 'Denied'
                              ? Stack(
                            alignment: Alignment.center,
                            children: [
                              Opacity(
                                opacity: 0.2,
                                child: QrImageView(
                                  data: generatedPassId,
                                  version: QrVersions.auto,
                                  size: 180,
                                ),
                              ),
                              Transform.rotate(
                                angle: -0.5,
                                child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.red, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 5)),
                              )
                            ],
                          )
                              : QrImageView(
                            data: generatedPassId,
                            version: QrVersions.auto,
                            size: 180,
                          ),
                        ),
                        const SizedBox(height: 20),

                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12))),
                        const SizedBox(height: 15),
                        Text(data['visitor_name'] ?? 'Visitor', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("${data['guest_count']} Guests", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),

                        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1, thickness: 1)),

                        _buildDetailRow(Icons.calendar_today_outlined, "Visit Date", dateStr),
                        _buildDetailRow(Icons.access_time, "Time", "${data['entry_time']} - ${data['exit_time']}"),
                        _buildDetailRow(Icons.meeting_room_outlined, "Unit", data['unit_no']),
                        if (data['bring_vehicle'] == true) _buildDetailRow(Icons.directions_car_outlined, "Vehicle", "${data['vehicle_plate']} (${data['vehicle_type']})"),
                        _buildDetailRow(Icons.numbers, "Pass ID", generatedPassId),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  if (status == 'Active' || status == 'Upcoming') ...[
                    Row(
                      children: [
                        Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: _primaryColor)), onPressed: (){}, icon: Icon(Icons.share, color: _primaryColor, size: 18), label: Text("Share", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)))),
                        const SizedBox(width: 15),
                        Expanded(child: OutlinedButton.icon(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), side: BorderSide(color: _primaryColor)), onPressed: (){}, icon: Icon(Icons.copy, color: _primaryColor, size: 18), label: Text("Copy Link", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)))),
                      ],
                    ),
                    const SizedBox(height: 15),

                    TextButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text("Cancel Visitor Pass?", style: TextStyle(fontWeight: FontWeight.bold)),
                                content: const Text("Are you sure you want to cancel this pass? This action cannot be undone and your guest will not be able to enter."),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text("No, Keep It", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      Navigator.pop(dialogContext);
                                      await FirebaseFirestore.instance.collection("visitor_passes").doc(passId).update({"status": "Cancelled"});
                                    },
                                    child: const Text("Yes, Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        child: const Text("Cancel Pass", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15))
                    )
                  ]
                ],
              ),
            );
          }
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade500, size: 20),
          const SizedBox(width: 15),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13))),
          Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
      ),
    );
  }
}
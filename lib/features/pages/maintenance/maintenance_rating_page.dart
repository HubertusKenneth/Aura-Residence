import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';

class MaintenanceRatingPage extends StatefulWidget {
  final String reportId;
  const MaintenanceRatingPage({Key? key, required this.reportId}) : super(key: key);

  @override
  State<MaintenanceRatingPage> createState() => _MaintenanceRatingPageState();
}

class _MaintenanceRatingPageState extends State<MaintenanceRatingPage> {
  int _rating = 0;
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text("Rate Service", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Skip", style: TextStyle(color: Colors.grey)))
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.assignment_turned_in, size: 100, color: Colors.blue.shade300),
            const SizedBox(height: 20),
            const Text("How was the repair service?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Your feedback helps us improve\nour maintenance service.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(index < _rating ? Icons.star_rounded : Icons.star_border_rounded, size: 45),
                  color: Colors.amber,
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text("Comment (Optional)", style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            TextField(
              controller: _commentController,
              maxLines: 4, maxLength: 300,
              decoration: InputDecoration(
                  hintText: "Technician was quick and fixed the issue...",
                  filled: true, fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200))
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _rating == 0 ? null : () async {
                  await FirebaseFirestore.instance.collection("maintenance_reports").doc(widget.reportId).update({
                    "rating": _rating,
                    "feedback": _commentController.text.trim(),
                    "updated_at": FieldValue.serverTimestamp()
                  });
                  Fluttertoast.showToast(msg: "Thank you! Rating submitted.");
                  if(mounted) Navigator.pop(context);
                },
                child: const Text("Submit Rating", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
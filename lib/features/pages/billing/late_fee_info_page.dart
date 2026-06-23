import 'package:flutter/material.dart';

class LateFeeInfoPage extends StatelessWidget {
  const LateFeeInfoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Late Fee Policy",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.shield_outlined, size: 60, color: Colors.orange.shade600),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text("Understanding Late Fees", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                "To ensure smooth operational and maintenance services for all residents, please settle your invoices on time.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.blueGrey, height: 1.5),
              ),
            ),
            const SizedBox(height: 35),

            _buildPolicyCard(
              icon: Icons.monetization_on_outlined,
              iconColor: Colors.blue,
              title: "Fee Amount",
              content: "A strict penalty of Rp50.000 applies per day for every day the invoice remains unpaid after the due date.",
            ),
            _buildPolicyCard(
              icon: Icons.event_busy,
              iconColor: Colors.red,
              title: "When does it start?",
              content: "The late fee calculation starts immediately on the 2nd day of the month at 00:01 AM (No grace period).",
            ),
            _buildPolicyCard(
              icon: Icons.calculate_outlined,
              iconColor: Colors.teal,
              title: "Calculation Example",
              content: "If your due date is May 1st, and you pay on May 4th:\n\nYou are 3 days late.\nPenalty: 3 x Rp 50.000 = Rp 150.000.",
            ),
            _buildPolicyCard(
              icon: Icons.gavel,
              iconColor: Colors.purple,
              title: "Consequences of Non-Payment",
              content: "If the invoice and accumulated late fees remain unpaid past the 10th of the month:\n\n• Smart Door Lock access will be temporarily suspended.\n• Facility booking access will be disabled.",
              isCritical: true,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("I Understand", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyCard({required IconData icon, required Color iconColor, required String title, required String content, bool isCritical = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCritical ? Colors.red.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isCritical ? Colors.red.shade200 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: isCritical ? Colors.red : iconColor, size: 28),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isCritical ? Colors.red.shade800 : Colors.black87)),
                const SizedBox(height: 6),
                Text(content, style: TextStyle(fontSize: 13, color: isCritical ? Colors.red.shade900 : Colors.blueGrey, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
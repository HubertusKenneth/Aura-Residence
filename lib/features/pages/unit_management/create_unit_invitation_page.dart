import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class CreateUnitInvitationPage extends StatefulWidget {
  final String unitNo;
  const CreateUnitInvitationPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<CreateUnitInvitationPage> createState() => _CreateUnitInvitationPageState();
}

class _CreateUnitInvitationPageState extends State<CreateUnitInvitationPage> {
  final Color _primaryColor = const Color(0xffF9A826);
  String _selectedRole = "Resident Member";
  String _generatedCode = "";
  bool _isLoading = false;

  Map<String, bool> customPermissions = {
    "Can Book Facilities": true,
    "Can Create Visitor Pass": true,
    "Can Submit Maintenance": true,
  };

  void _generateCode() async {
    setState(() => _isLoading = true);
    try {
      String tower = "Unknown Tower";
      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('unit_no', isEqualTo: widget.unitNo).get();
      if(unitQuery.docs.isNotEmpty) tower = unitQuery.docs.first.data()['tower'] ?? "Unknown Tower";

      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      Random rnd = Random();
      String code = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));

      Map<String, bool> finalPermissions = {};
      if (_selectedRole == "Resident Member") {
        finalPermissions = {
          "Can Book Facilities": true,
          "Can Create Visitor Pass": true,
          "Can Submit Maintenance": true,
          "Can View Bills": true,
        };
      } else {
        finalPermissions = customPermissions;
      }

      await FirebaseFirestore.instance.collection("unit_invitations").add({
        "unit_no": widget.unitNo,
        "tower": tower,
        "code": code,
        "role": _selectedRole,
        "permissions": finalPermissions,
        "created_by": FirebaseAuth.instance.currentUser!.uid,
        "status": "Active",
        "created_at": FieldValue.serverTimestamp(),
        "expires_at": Timestamp.fromDate(DateTime.now().add(const Duration(hours: 72))),
      });

      setState(() {
        _generatedCode = code;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Fluttertoast.showToast(msg: "Failed to generate code.");
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _generatedCode));
    Fluttertoast.showToast(msg: "Invitation code copied!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: const Text("Invite Member", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _generatedCode.isEmpty ? _buildForm() : _buildCodeResult(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Access Type", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 15),

        _buildRoleCard(
            "Resident Member",
            "For people who actually live inside the apartment (Spouse, Roommate, Child). Grants standard resident privileges.",
            Icons.family_restroom
        ),
        const SizedBox(height: 12),
        _buildRoleCard(
            "Limited Access",
            "For non-residents or temporary users (Maid, Driver, Caretaker). Access is highly restricted.",
            Icons.badge_outlined
        ),
        const SizedBox(height: 30),

        const Text("Permissions Granted", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),

        if (_selectedRole == "Resident Member")
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReadOnlyPermission("Facility Booking"),
                _buildReadOnlyPermission("Visitor Access Generation"),
                _buildReadOnlyPermission("Maintenance Requests"),

                _buildReadOnlyPermission("View & Pay Monthly Bills"),
                const SizedBox(height: 15),
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.green, size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text("Resident Members have full access to view statements and assist with bill payments.", style: TextStyle(color: Colors.green, fontSize: 12, height: 1.3))
                          )
                        ]
                    )
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: customPermissions.keys.map((key) {
                return CheckboxListTile(
                  title: Text(key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  activeColor: _primaryColor,
                  value: customPermissions[key],
                  onChanged: (val) => setState(() => customPermissions[key] = val!),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 40),

        SizedBox(
          width: double.infinity, height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _isLoading ? null : _generateCode,
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Generate Invitation Code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        )
      ],
    );
  }

  Widget _buildRoleCard(String title, String description, IconData icon) {
    bool isSelected = _selectedRole == title;
    return InkWell(
      onTap: () => setState(() => _selectedRole = title),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: isSelected ? _primaryColor.withOpacity(0.05) : Colors.white,
            border: Border.all(color: isSelected ? _primaryColor : Colors.grey.shade300, width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(16)
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: isSelected ? _primaryColor : Colors.grey.shade100, shape: BoxShape.circle),
              child: Icon(icon, color: isSelected ? Colors.white : Colors.grey, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? _primaryColor : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3)),
                ],
              ),
            ),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? _primaryColor : Colors.grey)
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyPermission(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCodeResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), child: Icon(Icons.mark_email_read, color: Colors.green.shade600, size: 60)),
        const SizedBox(height: 25),
        const Text("Invitation Created!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text("Share this secure code with your trusted member. They must enter it in their app to join your unit.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
        const SizedBox(height: 40),

        Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 35),
          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: _primaryColor.withOpacity(0.5), width: 2), borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _primaryColor.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))]),
          child: Column(
            children: [
              const Text("SECURE CODE", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 12)),
              const SizedBox(height: 15),
              Text(_generatedCode, style: TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: _primaryColor, letterSpacing: 8)),
              const SizedBox(height: 5),
              Text("Expires in 72 hours", style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                  onPressed: _copyCode, icon: const Icon(Icons.copy, color: Colors.white, size: 18), label: const Text("Copy Code", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              ),
            ],
          ),
        ),
      ],
    );
  }
}
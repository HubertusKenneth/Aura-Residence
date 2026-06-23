import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class EditProfilePage extends StatefulWidget {
  final String initialName;
  final String initialEmail;
  final String initialPhone;
  final String? secretaryId;
  final String uid;

  const EditProfilePage({
    Key? key,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
    required this.secretaryId,
    required this.uid,
  }) : super(key: key);

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final Color _primaryColor = const Color(0xffF9A826);

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);

    String cleanPhone = widget.initialPhone;
    if (cleanPhone.startsWith("+62")) cleanPhone = cleanPhone.substring(3);
    else if (cleanPhone.startsWith("0")) cleanPhone = cleanPhone.substring(1);

    _phoneCtrl = TextEditingController(text: cleanPhone);
    _emailCtrl = TextEditingController(text: widget.initialEmail);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.secretaryId == null) {
      Fluttertoast.showToast(msg: "Error: Admin reference not found.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalPhone = "+62${_phoneCtrl.text.trim()}";

      await FirebaseFirestore.instance
          .collection('Secretary')
          .doc(widget.secretaryId)
          .collection('Members')
          .doc(widget.uid)
          .set({
        'Name': _nameCtrl.text.trim(),
        'Phone': finalPhone,
        'Email': _emailCtrl.text.trim(),
        'userUid': widget.uid,
        'AdminUid': widget.secretaryId,
      }, SetOptions(merge: true));

      Fluttertoast.showToast(msg: "Profile Updated Successfully!");

      if (mounted) {
        Navigator.pop(context, {
          'name': _nameCtrl.text.trim(),
          'phone': finalPhone,
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String initial = _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Edit Profile", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 100, height: 100,
                                decoration: BoxDecoration(
                                    color: _primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
                                ),
                                alignment: Alignment.center,
                                child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text("Tap to change photo", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildLabel("Full Name *"),
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: _inputDecoration("Enter your full name"),
                      onChanged: (val) => setState(() {}),
                      validator: (val) => val == null || val.trim().isEmpty ? "Name cannot be empty" : null,
                    ),
                    const SizedBox(height: 25),

                    _buildLabel("Phone Number *"),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 1.5)), // Outline Oranye
                        prefixIcon: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("🇮🇩", style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              const Text("+62", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              const SizedBox(width: 12),
                              Container(width: 1.5, height: 24, color: Colors.grey.shade300),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? "Phone number cannot be empty" : null,
                    ),
                    const SizedBox(height: 25),

                    _buildLabel("Email Address *"),
                    TextFormField(
                      controller: _emailCtrl,
                      readOnly: true,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        suffixIcon: Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
          children: text.split('').map((char) {
            return TextSpan(
              text: char,
              style: TextStyle(color: char == '*' ? Colors.red.shade600 : Colors.black87),
            );
          }).toList(),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryColor, width: 1.5)), // Outline Oranye
    );
  }
}
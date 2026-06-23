import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

class CreateMaintenanceReportPage extends StatefulWidget {
  final String unitNo;
  const CreateMaintenanceReportPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<CreateMaintenanceReportPage> createState() => _CreateMaintenanceReportPageState();
}

class _CreateMaintenanceReportPageState extends State<CreateMaintenanceReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final Color _primaryColor = const Color(0xffF9A826);

  String _selectedCategory = "Air Conditioning";
  String _selectedLocation = "Bedroom";
  String _selectedPriority = "Medium";
  bool _isSubmitting = false;

  List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _categories = [
    {"name": "Air Conditioning", "icon": Icons.ac_unit, "color": Colors.blue.shade400},
    {"name": "Electrical", "icon": Icons.electrical_services, "color": Colors.amber.shade600},
    {"name": "Plumbing", "icon": Icons.water_drop, "color": Colors.cyan.shade600},
    {"name": "Furniture", "icon": Icons.chair, "color": Colors.brown.shade500},
    {"name": "Appliances", "icon": Icons.kitchen, "color": Colors.grey.shade600},
    {"name": "Others", "icon": Icons.more_horiz, "color": Colors.blueGrey.shade500},
  ];

  final List<String> _locations = ["Bedroom", "Bathroom", "Kitchen", "Living Room", "Balcony"];
  final List<String> _priorities = ["Low", "Medium", "High"];

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImages.add(File(pickedFile.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: const Text("Report Issue", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Title *"),
              TextFormField(
                controller: _titleController,
                cursorColor: _primaryColor,
                decoration: _inputStyle("AC leaking in bedroom"),
                validator: (val) => val!.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 20),

              _buildLabel("Category *"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCategory,
                    items: _categories.map((c) => DropdownMenuItem<String>(
                      value: c["name"],
                      child: Row(children: [Icon(c["icon"], size: 20, color: c["color"]), const SizedBox(width: 10), Text(c["name"])]),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel("Location in Unit (Optional)"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedLocation,
                    items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Row(children: [const Icon(Icons.location_on_outlined, size: 20, color: Colors.redAccent), const SizedBox(width: 10), Text(loc)]))).toList(),
                    onChanged: (val) => setState(() => _selectedLocation = val!),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _buildLabel("Priority *"),
              Row(
                children: _priorities.map((prio) {
                  bool isSelected = _selectedPriority == prio;
                  Color activeColor = prio == "High" ? Colors.red.shade600 : (prio == "Medium" ? Colors.orange.shade600 : Colors.green.shade600);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPriority = prio),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                            color: isSelected ? activeColor.withOpacity(0.1) : Colors.white,
                            border: Border.all(color: isSelected ? activeColor : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(30)
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? activeColor : Colors.grey, size: 16),
                            const SizedBox(width: 5),
                            Text(prio, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? activeColor : Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              _buildLabel("Description *"),
              TextFormField(
                controller: _descController,
                cursorColor: _primaryColor,
                maxLines: 4, maxLength: 500,
                decoration: _inputStyle("Describe the problem..."),
                validator: (val) => val!.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 10),

              _buildLabel("Upload Photos * (Min. 1 photo)"),
              Row(
                children: [
                  ..._selectedImages.map((file) => Container(
                    margin: const EdgeInsets.only(right: 10),
                    height: 80, width: 80,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(file), fit: BoxFit.cover)),
                  )).toList(),
                  if (_selectedImages.length < 3)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 80, width: 80,
                        decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _primaryColor.withOpacity(0.4), style: BorderStyle.solid)
                        ),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add, color: _primaryColor),
                              Text("Add", style: TextStyle(color: _primaryColor, fontSize: 12, fontWeight: FontWeight.bold))
                            ]
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Submit Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
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

  InputDecoration _inputStyle(String hint) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _primaryColor, width: 1.5)),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      Fluttertoast.showToast(msg: "Please upload at least 1 photo", backgroundColor: Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      var user = FirebaseAuth.instance.currentUser!;

      // CREATE REPORT
      await FirebaseFirestore.instance.collection("maintenance_reports").add({
        "unit_no": widget.unitNo,
        "tenant_uid": user.uid,
        "title": _titleController.text.trim(),
        "description": _descController.text.trim(),
        "category": _selectedCategory,
        "location": _selectedLocation,
        "priority": _selectedPriority,
        "status": "Submitted",
        "timestamp": FieldValue.serverTimestamp(),
        "updated_at": FieldValue.serverTimestamp(),
        "technician_name": "",
        "rating": 0,
      });

      await FirebaseFirestore.instance.collection("Users").doc(user.uid).collection("Notifications").add({
        "title": "Maintenance Report Submitted",
        "body": "Your maintenance report for '${_titleController.text.trim()}' has been successfully submitted.",
        "isRead": false,
        "timestamp": FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(msg: "Report successfully submitted!", backgroundColor: Colors.green);
      if(mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }
}
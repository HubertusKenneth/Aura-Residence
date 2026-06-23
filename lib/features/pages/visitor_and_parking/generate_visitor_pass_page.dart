import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'visitor_qr_detail_page.dart';

class GenerateVisitorPassPage extends StatefulWidget {
  final String unitNo;
  const GenerateVisitorPassPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<GenerateVisitorPassPage> createState() => _GenerateVisitorPassPageState();
}

class _GenerateVisitorPassPageState extends State<GenerateVisitorPassPage> {
  int _currentStep = 1;
  final int _totalSteps = 4;
  final Color _primaryColor = const Color(0xffF9A826);
  bool _isLoading = false;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _plateCtrl = TextEditingController();
  final TextEditingController _guestCountCtrl = TextEditingController(text: "1");

  int _guestCount = 1;
  DateTime? _visitDate;
  TimeOfDay? _entryTime;
  TimeOfDay? _exitTime;

  bool _bringVehicle = false;
  String _vehicleType = "Car";

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _plateCtrl.dispose();
    _guestCountCtrl.dispose();
    super.dispose();
  }

  void _incrementGuest() {
    setState(() {
      _guestCount++;
      _guestCountCtrl.text = _guestCount.toString();
    });
  }

  void _decrementGuest() {
    if (_guestCount > 1) {
      setState(() {
        _guestCount--;
        _guestCountCtrl.text = _guestCount.toString();
      });
    }
  }

  void _onGuestCountChanged(String val) {
    int? count = int.tryParse(val);
    if (count != null && count > 0) {
      setState(() {
        _guestCount = count;
      });
    }
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Phone are required")));
        return;
      }

      String cleanPhone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanPhone.length < 11 || cleanPhone.length > 15) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Phone number must be between 11 and 15 digits")));
        return;
      }

      int parsedCount = int.tryParse(_guestCountCtrl.text) ?? 0;
      if (parsedCount < 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guest count must be at least 1")));
        return;
      }
      _guestCount = parsedCount;
    }

    if (_currentStep == 2) {
      if (_visitDate == null || _entryTime == null || _exitTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select date and times completely")));
        return;
      }
    }

    if (_currentStep == 3 && _bringVehicle) {
      String plate = _plateCtrl.text.trim();
      if (plate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vehicle plate is required")));
        return;
      }

      RegExp plateRegExp = RegExp(r'^[a-zA-Z]{1,2}\s?\d{1,4}\s?[a-zA-Z0-9]{1,3}$');
      if (!plateRegExp.hasMatch(plate)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid plate format (e.g., B 1234 ABC)")));
        return;
      }
    }

    if (_currentStep < _totalSteps) {
      setState(() => _currentStep++);
    } else {
      _generateQR();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) setState(() => _currentStep--);
  }

  Future<void> _generateQR() async {
    setState(() => _isLoading = true);
    try {
      String unitNo = widget.unitNo;
      DateTime now = DateTime.now();

      String datePart = DateFormat('yyMMdd').format(now);
      String searchPrefix = "VSP-$datePart-";

      QuerySnapshot todayPasses = await FirebaseFirestore.instance
          .collection('visitor_passes')
          .get();

      int countToday = todayPasses.docs.where((doc) {
        var data = doc.data() as Map<String, dynamic>;
        String existingPassId = data['pass_id'] ?? '';
        return existingPassId.startsWith(searchPrefix);
      }).length;

      String sequenceStr = (countToday + 1).toString().padLeft(4, '0');

      String finalPassId = "VSP-$datePart-$unitNo-$sequenceStr";

      var docRef = await FirebaseFirestore.instance.collection("visitor_passes").add({
        "pass_id": finalPassId,
        "unit_no": widget.unitNo,
        "resident_uid": FirebaseAuth.instance.currentUser!.uid,
        "visitor_name": _nameCtrl.text.trim(),
        "phone_number": _phoneCtrl.text.trim(),
        "guest_count": _guestCount,
        "notes": _notesCtrl.text.trim(),
        "visit_date": Timestamp.fromDate(_visitDate!),
        "entry_time": _entryTime!.format(context),
        "exit_time": _exitTime!.format(context),
        "bring_vehicle": _bringVehicle,
        "vehicle_plate": _bringVehicle ? _plateCtrl.text.trim().toUpperCase() : null,
        "vehicle_type": _bringVehicle ? _vehicleType : null,
        "status": "Upcoming",
        "created_at": FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VisitorQrDetailPage(passId: docRef.id)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
        title: const Text("Generate Pass", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStepContent(),
            ),
          ),
          _buildBottomActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalSteps, (index) {
          int stepNum = index + 1;
          bool isPast = stepNum < _currentStep;
          bool isActive = stepNum == _currentStep;
          return Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(color: isActive || isPast ? _primaryColor : Colors.grey.shade200, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(stepNum.toString(), style: TextStyle(color: isActive || isPast ? Colors.white : Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              if (stepNum < _totalSteps) Container(width: 40, height: 2, color: isPast ? _primaryColor : Colors.grey.shade200),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_currentStep == 1) ...[
            const Text("Visitor Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _inputField("Full Name *", _nameCtrl),
            _inputField("Phone Number *", _phoneCtrl, isPhone: true, hint: "e.g., 081234567890"),

            _buildLabel("Number of Guests *"),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 28), onPressed: _decrementGuest),
                Container(
                  width: 60,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _guestCountCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    cursorColor: _primaryColor,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: _onGuestCountChanged,
                  ),
                ),
                IconButton(icon: Icon(Icons.add_circle_outline, color: _primaryColor, size: 28), onPressed: _incrementGuest),
              ],
            ),
            const SizedBox(height: 20),

            _inputField("Notes (Optional)", _notesCtrl, maxLines: 3),
          ] else if (_currentStep == 2) ...[
            const Text("Visit Schedule", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _datePickerField(),
            const SizedBox(height: 15),

            _timePickerField("Entry Time *", _entryTime, isEntryTime: true, onPicked: (t) => setState(() {
              _entryTime = t;
              _exitTime = null;
            })),

            const SizedBox(height: 15),
            _timePickerField("Exit Time *", _exitTime, isEntryTime: false, onPicked: (t) => setState(() => _exitTime = t)),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.info_outline, color: Colors.orange.shade600, size: 20), const SizedBox(width: 10), Expanded(child: Text("Guest can enter starting from 30 minutes before entry time.", style: TextStyle(color: Colors.orange.shade800, fontSize: 12)))])),
          ] else if (_currentStep == 3) ...[
            const Text("Vehicle Information (Optional)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Bringing a vehicle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Switch(value: _bringVehicle, activeColor: _primaryColor, onChanged: (v) => setState(() => _bringVehicle = v)),
              ],
            ),
            if (_bringVehicle) ...[
              const SizedBox(height: 20),
              _inputField("Vehicle Plate Number *", _plateCtrl, hint: "e.g., B 1234 ABC", isUppercase: true),
              _buildLabel("Vehicle Type *"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true, value: _vehicleType,
                    items: ["Car", "Motorcycle"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (v) => setState(() => _vehicleType = v!),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)), child: Row(children: [Icon(Icons.security, color: Colors.orange.shade600, size: 20), const SizedBox(width: 10), Expanded(child: Text("Vehicle information is optional. If provided, it will help security for faster verification at the gate.", style: TextStyle(color: Colors.orange.shade800, fontSize: 12)))])),
          ] else if (_currentStep == 4) ...[
            const Text("Unit Confirmation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const Padding(padding: EdgeInsets.only(bottom: 8), child: Text("Select Unit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15), width: double.infinity, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)), child: Text(widget.unitNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("This pass will grant access to:", style: TextStyle(color: Colors.green.shade800, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text("Unit ${widget.unitNo}", style: TextStyle(color: Colors.green.shade900, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("Main Tower", style: TextStyle(color: Colors.green.shade700, fontSize: 12)),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildBottomActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20), color: Colors.white,
      child: Row(
        children: [
          if (_currentStep > 1) Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), side: BorderSide(color: _primaryColor)), onPressed: _prevStep, child: Text("Back", style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)))),
          if (_currentStep > 1) const SizedBox(width: 15),
          Expanded(flex: 2, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: _isLoading ? null : _nextStep, child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_currentStep == _totalSteps ? "Generate Pass" : "Next", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    if (!text.contains('*')) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
      );
    }

    List<String> parts = text.split('*');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          children: [
            TextSpan(text: parts[0]),
            TextSpan(text: "*", style: TextStyle(color: Colors.red.shade600, fontSize: 15)),
            if (parts.length > 1) TextSpan(text: parts[1]),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, {bool isPhone = false, int maxLines = 1, String? hint, bool isUppercase = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLabel(label),
          TextField(
              controller: controller,
              maxLines: maxLines,
              textCapitalization: isUppercase ? TextCapitalization.characters : TextCapitalization.words,
              cursorColor: _primaryColor,
              keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
              decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _primaryColor, width: 1.5))
              )
          ),
        ],
      ),
    );
  }

  Widget _datePickerField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel("Visit Date *"),
        InkWell(
          onTap: () async {
            DateTime now = DateTime.now();

            DateTime firstAllowed = (now.hour >= 20) ? now.add(const Duration(days: 1)) : now;

            DateTime? picked = await showDatePicker(
                context: context,
                initialDate: firstAllowed,
                firstDate: firstAllowed,
                lastDate: now.add(const Duration(days: 30)),
                builder: (context, child) {
                  return Theme(
                      data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(primary: _primaryColor, onPrimary: Colors.white, onSurface: Colors.black)
                      ),
                      child: child!
                  );
                }
            );
            if (picked != null) {
              setState(() {
                _visitDate = picked;
                _entryTime = null;
                _exitTime = null;
              });
            }
          },
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_visitDate != null ? DateFormat('dd MMM yyyy').format(_visitDate!) : "Select date", style: TextStyle(color: _visitDate != null ? Colors.black87 : Colors.grey.shade500, fontSize: 15)),
                    const Icon(Icons.calendar_today, color: Colors.grey)
                  ]
              )
          ),
        )
      ],
    );
  }

  void _showCustomTimePicker(String label, TimeOfDay? initialTime, bool isEntryTime, Function(TimeOfDay) onPicked) {
    if (_visitDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Visit Date first.")));
      return;
    }

    if (!isEntryTime && _entryTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Entry Time first.")));
      return;
    }

    DateTime now = DateTime.now();
    int startHour24 = 8;
    int startMin = 0;

    if (initialTime != null) {
      startHour24 = initialTime.hour;
      startMin = initialTime.minute;
    } else {
      if (isEntryTime) {
        bool isToday = _visitDate!.year == now.year && _visitDate!.month == now.month && _visitDate!.day == now.day;
        if (isToday) {
          DateTime minTime = now.add(const Duration(hours: 1));
          startHour24 = minTime.hour;
          startMin = minTime.minute;
        } else {
          startHour24 = 8;
          startMin = 0;
        }
      } else {
        if (_entryTime != null) {
          startHour24 = _entryTime!.hour + 1;
          startMin = _entryTime!.minute;
        }
      }
    }

    int maxH = isEntryTime ? 21 : 22;
    if (startHour24 < 8) { startHour24 = 8; startMin = 0; }
    if (startHour24 > maxH) { startHour24 = maxH; startMin = 0; }

    int displayHour = startHour24 > 12 ? startHour24 - 12 : (startHour24 == 0 ? 12 : startHour24);
    String amPm = startHour24 >= 12 ? "PM" : "AM";
    int selectedMinute = startMin;

    List<int> validHours = [8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
    List<String> validAmPm = ["AM", "AM", "AM", "AM", "PM", "PM", "PM", "PM", "PM", "PM", "PM", "PM", "PM", "PM", "PM"];

    int initialHourIndex = 0;
    for (int i = 0; i < validHours.length; i++) {
      if (validHours[i] == displayHour && validAmPm[i] == amPm) {
        initialHourIndex = i;
        break;
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {

            FixedExtentScrollController hourController = FixedExtentScrollController(initialItem: initialHourIndex);
            FixedExtentScrollController minController = FixedExtentScrollController(initialItem: selectedMinute);

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 25),

                    SizedBox(
                      height: 150,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            child: ListWheelScrollView.useDelegate(
                              controller: hourController,
                              itemExtent: 50,
                              perspective: 0.005,
                              diameterRatio: 1.2,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setModalState(() {
                                  displayHour = validHours[index];
                                  amPm = validAmPm[index];
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: validHours.length,
                                builder: (context, index) {
                                  bool isSelected = validHours[index] == displayHour && validAmPm[index] == amPm;
                                  return Center(
                                    child: Text(
                                      validHours[index].toString().padLeft(2, '0'),
                                      style: TextStyle(
                                          fontSize: isSelected ? 30 : 20,
                                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                          color: isSelected ? _primaryColor : Colors.grey.shade400
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(":", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black54)),
                          ),

                          SizedBox(
                            width: 60,
                            child: ListWheelScrollView.useDelegate(
                              controller: minController,
                              itemExtent: 50,
                              perspective: 0.005,
                              diameterRatio: 1.2,
                              physics: const FixedExtentScrollPhysics(),
                              onSelectedItemChanged: (index) {
                                setModalState(() {
                                  selectedMinute = index;
                                });
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 60,
                                builder: (context, index) {
                                  bool isSelected = index == selectedMinute;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                          fontSize: isSelected ? 30 : 20,
                                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                                          color: isSelected ? _primaryColor : Colors.grey.shade400
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(width: 15),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: _primaryColor.withOpacity(0.3))
                            ),
                            child: Text(amPm, style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)))),
                        Expanded(
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: _primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0
                                ),
                                onPressed: () {
                                  if (displayHour == 10 && amPm == "PM" && selectedMinute > 0) {
                                    selectedMinute = 0;
                                  }

                                  int finalHour = amPm == "PM" && displayHour != 12
                                      ? displayHour + 12
                                      : (amPm == "AM" && displayHour == 12 ? 0 : displayHour);

                                  DateTime now = DateTime.now();

                                  DateTime normalizedNow = DateTime(now.year, now.month, now.day, now.hour, now.minute);

                                  DateTime selectedDateTime = DateTime(
                                      _visitDate!.year, _visitDate!.month, _visitDate!.day,
                                      finalHour, selectedMinute
                                  );

                                  if (isEntryTime) {
                                    if (_visitDate!.year == now.year && _visitDate!.month == now.month && _visitDate!.day == now.day) {
                                      DateTime minAllowedTime = normalizedNow.add(const Duration(hours: 1));
                                      if (selectedDateTime.isBefore(minAllowedTime)) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("Entry time must be at least 1 hour from current time."))
                                        );
                                        return;
                                      }
                                    }
                                    DateTime maxEntry = DateTime(_visitDate!.year, _visitDate!.month, _visitDate!.day, 21, 0);
                                    if (selectedDateTime.isAfter(maxEntry)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Maximum Entry Time allowed is 09:00 PM."))
                                      );
                                      return;
                                    }
                                  }
                                  else {
                                    DateTime entryDateTime = DateTime(
                                        _visitDate!.year, _visitDate!.month, _visitDate!.day,
                                        _entryTime!.hour, _entryTime!.minute
                                    );

                                    DateTime minExit = entryDateTime.add(const Duration(hours: 1));

                                    if (selectedDateTime.isBefore(minExit)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Exit time must be at least 1 hour after Entry time."))
                                      );
                                      return;
                                    }

                                    DateTime maxExit = DateTime(_visitDate!.year, _visitDate!.month, _visitDate!.day, 22, 0);
                                    if (selectedDateTime.isAfter(maxExit)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Maximum Exit Time allowed is 10:00 PM."))
                                      );
                                      return;
                                    }
                                  }

                                  onPicked(TimeOfDay(hour: finalHour, minute: selectedMinute));
                                  Navigator.pop(context);
                                },
                                child: const Text("Save", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                            )
                        ),
                      ],
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

  Widget _timePickerField(String label, TimeOfDay? time, {required bool isEntryTime, required Function(TimeOfDay) onPicked}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        InkWell(
          onTap: () => _showCustomTimePicker(label, time, isEntryTime, onPicked),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(time != null ? time.format(context) : "Select time", style: TextStyle(color: time != null ? Colors.black87 : Colors.grey.shade500, fontSize: 15)),
                    const Icon(Icons.access_time, color: Colors.grey)
                  ]
              )
          ),
        )
      ],
    );
  }
}
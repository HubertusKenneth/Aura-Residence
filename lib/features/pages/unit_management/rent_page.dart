import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:my_apart/features/pages/profile/profile_page.dart';

class RentPage extends StatefulWidget {
  const RentPage({Key? key}) : super(key: key);
  @override
  State<RentPage> createState() => _RentPageState();
}

class _RentPageState extends State<RentPage> {
  String selectedType = "All Types";
  String selectedTower = "All Towers";

  String selectedSort = "Recommended";

  List<String> unitTypes = ["All Types", "Studio", "2 Bedroom", "3 Bedroom"];
  List<String> towers = ["All Towers", "Tower A", "Tower B", "Tower C", "Tower D"];
  List<String> sortOptions = [
    "Recommended",
    "Floor (Lowest - Highest)",
    "Floor (Highest - Lowest)",
    "Price (Lowest - Highest)",
    "Price (Highest - Lowest)"
  ];

  String formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  int _extractNumber(dynamic value) {
    if (value == null) return 0;
    String str = value.toString().replaceAll(RegExp(r'[^0-9]'), '');
    if (str.isEmpty) return 0;
    return int.parse(str);
  }

  @override
  Widget build(BuildContext context) {
    final String currentUserUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Find Your Unit', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 15),
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Tower", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: selectedTower, icon: const Icon(Icons.location_city, color: Colors.blueGrey, size: 18), items: towers.map((String tower) => DropdownMenuItem<String>(value: tower, child: Text(tower, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)))).toList(), onChanged: (val) { setState(() { selectedTower = val!; }); }))),])),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Sort By", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(isExpanded: true, value: selectedSort, icon: const Icon(Icons.sort, color: Colors.blueGrey, size: 18), items: sortOptions.map((String sort) => DropdownMenuItem<String>(value: sort, child: Text(sort, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)))).toList(), onChanged: (val) { setState(() { selectedSort = val!; }); }))),])),
                  ],
                ),
                const SizedBox(height: 15),
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: unitTypes.map((type) { bool isSelected = selectedType == type; return Padding(padding: const EdgeInsets.only(right: 10), child: ChoiceChip(label: Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.blueGrey)), selected: isSelected, selectedColor: const Color(0xffF9A826), backgroundColor: Colors.grey.shade200, side: BorderSide.none, onSelected: (selected) { setState(() { selectedType = type; }); })); }).toList())),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('ApartmentUnits').where('status', whereIn: ['Kosong', 'Disewakan', 'Dijual']).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xffF9A826)));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No units available."));

                  List<Map<String, dynamic>> displayedUnits = snapshot.data!.docs.map((doc) {
                    var data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                    if (data['status'] == 'Disewakan') {
                      if (data['custom_price_monthly'] != null) data['price_monthly'] = data['custom_price_monthly'];
                      if (data['custom_price_yearly'] != null) data['price_yearly'] = data['custom_price_yearly'];
                    } else if (data['status'] == 'Dijual') {
                      data['price_sell'] = data['custom_price_sell'] ?? ((data['price_yearly'] ?? 0) * 15);
                    }
                    return {'docId': doc.id, ...data};
                  }).where((unit) {
                    bool matchType = selectedType == "All Types" || unit["type"] == selectedType;
                    bool matchTower = selectedTower == "All Towers" || unit["tower"] == selectedTower;
                    bool notMine = unit["subleaser_uid"] != currentUserUid && unit["ownerUid"] != currentUserUid && unit["residentUid"] != currentUserUid;
                    return matchType && matchTower && notMine;
                  }).toList();

                  displayedUnits.sort((a, b) {
                    if (selectedSort == "Recommended") {
                      return a['docId'].hashCode.compareTo(b['docId'].hashCode);
                    }

                    int floorA = _extractNumber(a["floor"]);
                    int floorB = _extractNumber(b["floor"]);

                    if (floorA == floorB) {
                      int unitA = _extractNumber(a["unit_no"]);
                      int unitB = _extractNumber(b["unit_no"]);

                      if (unitA == unitB) return 0;

                      if (selectedSort.contains("Lowest - Highest")) {
                        return unitA.compareTo(unitB);
                      } else if (selectedSort.contains("Highest - Lowest")) {
                        return unitB.compareTo(unitA);
                      }
                    }

                    int priceA = a['status'] == 'Dijual' ? _extractNumber(a['price_sell']) : _extractNumber(a["price_monthly"]);
                    int priceB = b['status'] == 'Dijual' ? _extractNumber(b['price_sell']) : _extractNumber(b["price_monthly"]);

                    switch (selectedSort) {
                      case "Floor (Lowest - Highest)": return floorA.compareTo(floorB);
                      case "Floor (Highest - Lowest)": return floorB.compareTo(floorA);
                      case "Price (Lowest - Highest)": return priceA.compareTo(priceB);
                      case "Price (Highest - Lowest)": return priceB.compareTo(priceA);
                      default: return 0;
                    }
                  });

                  if (displayedUnits.isEmpty) return const Center(child: Text("No units available for this filter."));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    itemCount: displayedUnits.length,
                    itemBuilder: (context, index) {
                      var unit = displayedUnits[index];
                      bool isSubLeased = unit['status'] == 'Disewakan';
                      bool isForSaleByOwner = unit['status'] == 'Dijual';

                      return GestureDetector(
                        onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => UnitDetailPage(unit: unit))); },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 20), elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), child: Container(height: 160, width: double.infinity, color: Colors.blueGrey.shade100, child: Image.asset(unit["image"] ?? "assets/images/Unit1.jpg", fit: BoxFit.cover))),
                                  Positioned(top: 15, right: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)), child: Text(unit["tower"] ?? "Tower", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)))),

                                  if (isForSaleByOwner)
                                    Positioned(top: 15, left: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.green.shade600, borderRadius: BorderRadius.circular(8)), child: const Text("For Sale by Owner", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))))
                                  else if (isSubLeased)
                                    Positioned(top: 15, left: 15, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.blue.shade600, borderRadius: BorderRadius.circular(8)), child: const Text("Sub-leased by Owner", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white))))
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Unit ${unit["unit_no"]}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)), Text(unit["type"] ?? "Type", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]),
                                    const SizedBox(height: 5),
                                    Row(children: [const Icon(Icons.layers_outlined, size: 14, color: Colors.grey), const SizedBox(width: 5), Text("Floor ${unit["floor"]} • ${unit["view"] ?? "City View"}", style: const TextStyle(color: Colors.grey, fontSize: 13))]),
                                    const SizedBox(height: 15),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (isForSaleByOwner)
                                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Buy for", style: TextStyle(color: Colors.grey, fontSize: 12)), Text(formatCurrency(int.tryParse(unit["price_sell"].toString()) ?? 0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green))])
                                        else
                                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Starts from", style: TextStyle(color: Colors.grey, fontSize: 12)), Text("${formatCurrency(int.tryParse(unit["price_monthly"].toString()) ?? 0)} / mo", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xffF9A826)))]),

                                        ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: isForSaleByOwner ? Colors.green : const Color(0xffF9A826),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                elevation: 0
                                            ),
                                            onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (context) => UnitDetailPage(unit: unit))); },
                                            child: const Text("Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))
                                        )
                                      ],
                                    )
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
              )
          ),
        ],
      ),
    );
  }
}

class UnitDetailPage extends StatefulWidget {
  final Map<String, dynamic> unit;
  const UnitDetailPage({Key? key, required this.unit}) : super(key: key);
  @override
  State<UnitDetailPage> createState() => _UnitDetailPageState();
}

class _UnitDetailPageState extends State<UnitDetailPage> {
  bool isCheckingProfile = false;

  String formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  Future<void> _checkProfileAndProceed(String transactionType) async {
    setState(() { isCheckingProfile = true; });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final querySnapshot = await FirebaseFirestore.instance.collection("Secretary").get();

      Map<String, dynamic>? userData;
      String? secretaryId;

      for (var doc in querySnapshot.docs) {
        final memberDoc = await FirebaseFirestore.instance.collection("Secretary").doc(doc.id).collection("Members").doc(uid).get();
        if (memberDoc.exists && memberDoc.data() != null) {
          userData = memberDoc.data();
          secretaryId = doc.id;
          break;
        }
      }

      setState(() { isCheckingProfile = false; });

      if (userData != null && secretaryId != null) {
        String phone = userData["Phone"] ?? "";
        if (phone.isEmpty) {
          _showIncompleteProfileDialog();
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => BookingPage(unit: widget.unit, secretaryId: secretaryId!, transactionType: transactionType, userData: userData!)));
        }
      } else {
        Fluttertoast.showToast(msg: "Error: User profile not found.");
      }
    } catch (e) {
      setState(() { isCheckingProfile = false; });
      Fluttertoast.showToast(msg: "Error checking profile: $e");
    }
  }

  void _showIncompleteProfileDialog() {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 10), Text("Profile Incomplete")]),
          content: const Text("You need to complete your profile (Phone Number) before proceeding."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826)), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => const profile_page())); }, child: const Text("Complete Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> facilitiesList = widget.unit["facilities"] ?? [];
    List<dynamic> rulesList = widget.unit["rules"] ?? [];

    bool isSubLeased = widget.unit["status"] == "Disewakan";
    bool isForSaleByOwner = widget.unit["status"] == "Dijual";

    int yearlyPrice = int.tryParse(widget.unit["price_yearly"].toString()) ?? 0;
    int buyPrice = isForSaleByOwner ? (int.tryParse(widget.unit["custom_price_sell"].toString()) ?? 0) : yearlyPrice * 15;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    onPressed: () => Navigator.pop(context)
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.asset(widget.unit["image"] ?? "assets/images/Unit1.jpg", fit: BoxFit.cover),
            ),
          ),
          SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Unit ${widget.unit["unit_no"]}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: const Color(0xffF9A826).withOpacity(0.15), borderRadius: BorderRadius.circular(20)), child: Text(widget.unit["type"] ?? "Type", style: const TextStyle(color: Color(0xffF9A826), fontWeight: FontWeight.bold)))]),

                    if (isForSaleByOwner) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.info, color: Colors.green, size: 16), SizedBox(width: 8), Text("This unit is listed for sale by a Private Owner", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]))]
                    else if (isSubLeased) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.info, color: Colors.blue, size: 16), SizedBox(width: 8), Text("This unit is sub-leased by a Private Owner", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))]))],

                    const SizedBox(height: 10),
                    Row(children: [const Icon(Icons.location_city, size: 18, color: Colors.grey), const SizedBox(width: 5), Text("${widget.unit["tower"]} • Floor ${widget.unit["floor"]} • ${widget.unit["view"]}", style: const TextStyle(fontSize: 14, color: Colors.grey))]),
                    const SizedBox(height: 25),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildQuickInfo(Icons.aspect_ratio, widget.unit["size"] ?? "-", "Size"), _buildQuickInfo(Icons.chair_outlined, widget.unit["furnishing"]?.toString().split(" ").first ?? "-", "Furnish"), _buildQuickInfo(Icons.payments_outlined, "Yearly/Monthly", "Payment")]),
                    const Divider(height: 40, thickness: 1),
                    const Text("Rental & Purchase Price", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 15),

                    if (!isForSaleByOwner) ...[
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Rent (Monthly)", style: TextStyle(fontSize: 15, color: Colors.black87)), Text(formatCurrency(int.tryParse(widget.unit["price_monthly"].toString()) ?? 0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 10),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Rent (Yearly)", style: TextStyle(fontSize: 15, color: Colors.black87)), Text(formatCurrency(yearlyPrice), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 15),
                    ],

                    if (!isSubLeased) ...[
                      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.shade100)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(isForSaleByOwner ? "Total Selling Price" : "Buy Permanent (Ownership)", style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold)), Text(formatCurrency(buyPrice), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green))])),
                      const SizedBox(height: 20)
                    ],

                    Container(
                      padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Estimated Additional Costs", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Maintenance Fee / IPL (mo)", style: TextStyle(color: Colors.grey, fontSize: 13)), Text(formatCurrency(int.tryParse(widget.unit["maintenance_fee"].toString()) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
                          if (!isForSaleByOwner) ...[
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Security Deposit (For Rent Only)", style: TextStyle(color: Colors.grey, fontSize: 13)), Text(formatCurrency(int.tryParse(widget.unit["deposit"].toString()) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    const Text("Unit Facilities", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 10),
                    Wrap(spacing: 10, runSpacing: 10, children: facilitiesList.map<Widget>((f) => Chip(label: Text(f.toString(), style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600)), backgroundColor: Colors.grey.shade100, side: BorderSide.none)).toList()),
                    const SizedBox(height: 25),
                    const Text("Unit Rules", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: rulesList.map<Widget>((rule) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [const Icon(Icons.check_circle, size: 18, color: Colors.green), const SizedBox(width: 10), Expanded(child: Text(rule.toString(), style: const TextStyle(color: Colors.black87)))]))).toList()),
                    const SizedBox(height: 40),
                  ],
                ),
              )
          )
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))]),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity, height: 55,
            child: Row(
              children: [
                if (!isForSaleByOwner)
                  Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: const Color(0xffF9A826), side: const BorderSide(color: Color(0xffF9A826), width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 15)), onPressed: isCheckingProfile ? null : () => _checkProfileAndProceed("Rent"), child: const Text("Rent Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),

                if (!isForSaleByOwner && !isSubLeased) const SizedBox(width: 15),

                if (!isSubLeased)
                  Expanded(child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), padding: const EdgeInsets.symmetric(vertical: 15)),
                      onPressed: isCheckingProfile ? null : () => _checkProfileAndProceed("Buy"),
                      child: isCheckingProfile ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text("Buy Now", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInfo(IconData icon, String value, String label) {
    return Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xffF9A826).withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: const Color(0xffF9A826), size: 24)), const SizedBox(height: 8), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), const SizedBox(height: 2), Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey))]);
  }
}

class BookingPage extends StatefulWidget {
  final Map<String, dynamic> unit;
  final String secretaryId;
  final String transactionType;
  final Map<String, dynamic> userData;

  const BookingPage({
    Key? key,
    required this.unit,
    required this.secretaryId,
    required this.transactionType,
    required this.userData
  }) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  String selectedDuration = "Monthly";
  bool isSubmitting = false;

  String formatCurrency(int amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  @override
  void initState() {
    super.initState();
    if (widget.transactionType == "Buy") selectedDuration = "Permanent (Ownership)";
  }

  void _showConfirmationDialog(int total) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Confirm Application", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              widget.transactionType == "Rent"
                  ? "Are you sure you want to proceed with the rental application for Unit ${widget.unit['unit_no']}?"
                  : "Are you sure you want to proceed with the purchase application for Unit ${widget.unit['unit_no']}?",
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: widget.transactionType == "Buy" ? Colors.green.shade600 : const Color(0xffF9A826)
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _submitApplication(total);
                  },
                  child: const Text("Yes, Proceed", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              )
            ]
        )
    );
  }

  Future<void> _submitApplication(int total) async {
    setState(() { isSubmitting = true; });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      DateTime now = DateTime.now();
      String contractStart = now.toIso8601String();
      String contractEnd = "";

      if (widget.transactionType == "Rent") {
        if (selectedDuration == "Monthly") {
          contractEnd = DateTime(now.year, now.month + 1, now.day).toIso8601String();
        } else {
          contractEnd = DateTime(now.year + 1, now.month, now.day).toIso8601String();
        }
      } else {
        contractEnd = "Permanent";
      }

      String sUid = (widget.unit["subleaser_uid"] ?? "").toString().trim();
      String oUid = (widget.unit["ownerUid"] ?? "").toString().trim();
      String targetOwnerUid = "Management";

      if (widget.transactionType == "Buy" && widget.unit["status"] == "Dijual") {
        targetOwnerUid = sUid.isNotEmpty ? sUid : (oUid.isNotEmpty ? oUid : "Management");
      } else if (sUid.isNotEmpty) {
        targetOwnerUid = sUid;
      } else if (oUid.isNotEmpty && oUid != "Management") {
        targetOwnerUid = oUid;
      }

      String targetStatus = "Pending Initial Review";

      if (targetOwnerUid != "Management") {
        targetStatus = "Pending Owner Approval";
      }

      Map<String, dynamic> bookingData = {
        "tenantUid": uid,
        "tenantName": widget.userData["Name"] ?? "Member",
        "tenantPhone": widget.userData["Phone"] ?? "-",
        "ktpNumber": widget.userData["IdentityNo"] ?? "-",
        "unit_no": widget.unit["unit_no"],
        "tower": widget.unit["tower"],
        "ownerUid": targetOwnerUid,
        "duration": selectedDuration,
        "total_payment": total,
        "transaction_type": widget.transactionType,
        "contract_start_date": contractStart,
        "contract_end_date": contractEnd,
        "status": targetStatus,
        "timestamp": FieldValue.serverTimestamp(),
        "image": widget.unit["image"] ?? "assets/images/Unit1.jpg",
      };

      await FirebaseFirestore.instance.collection("RentalApplications").add(bookingData);

      String notifBody = targetStatus == "Pending Owner Approval"
          ? "Your request for Unit ${widget.unit['unit_no']} is waiting for the Owner's approval."
          : "Your request for Unit ${widget.unit['unit_no']} is sent to Admin for initial review.";

      await FirebaseFirestore.instance.collection("Users").doc(uid).collection("Notifications").add({
        "title": "Application Initiated",
        "body": notifBody,
        "timestamp": FieldValue.serverTimestamp(), "isRead": false,
      });

      await FirebaseFirestore.instance.collection("ApartmentUnits").doc(widget.unit["docId"]).update({"status": "Reserved"});

      Fluttertoast.showToast(msg: "Application submitted!");
      if (mounted) { Navigator.pop(context); Navigator.pop(context); }
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: $e");
    } finally {
      if (mounted) setState(() { isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    int monthlyPrice = int.tryParse(widget.unit["price_monthly"].toString()) ?? 0;
    int yearlyPrice = int.tryParse(widget.unit["price_yearly"].toString()) ?? 0;
    int depositAmt = int.tryParse(widget.unit["deposit"].toString()) ?? 0;

    bool isForSaleByOwner = widget.unit["status"] == "Dijual";

    int rentPrice = selectedDuration == "Monthly" ? monthlyPrice : yearlyPrice;
    int deposit = widget.transactionType == "Rent" ? depositAmt : 0;

    int total = widget.transactionType == "Rent"
        ? rentPrice + deposit
        : (isForSaleByOwner ? (int.tryParse(widget.unit["custom_price_sell"].toString()) ?? 0) : yearlyPrice * 15);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: Text(widget.transactionType == "Rent" ? "Rental Details" : "Purchase Details", style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context))
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.transactionType == "Rent" ? "Select Rental Duration" : "Purchase Type", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 15),

            if (widget.transactionType == "Rent")
              Row(
                children: [
                  Expanded(child: _buildDurationOption("Monthly", "${formatCurrency(monthlyPrice)} / mo")),
                  const SizedBox(width: 15),
                  Expanded(child: _buildDurationOption("Yearly", "${formatCurrency(yearlyPrice)} / yr")),
                ],
              )
            else
              _buildDurationOption("Permanent (Ownership)", formatCurrency(total), isBuy: true),

            const SizedBox(height: 35),
            const Text("Payment Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 15),

            Container(
              padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))]),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(widget.transactionType == "Rent" ? "$selectedDuration Rent" : "Unit Price", style: const TextStyle(color: Colors.grey, fontSize: 14)), Text(formatCurrency(widget.transactionType == "Rent" ? rentPrice : total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
                  if (widget.transactionType == "Rent") ...[
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Security Deposit", style: TextStyle(color: Colors.grey, fontSize: 14)), Text(formatCurrency(deposit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
                  ],
                  const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(height: 1)),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Total Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)), Text(formatCurrency(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xffF9A826)))]),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: widget.transactionType == "Buy" ? Colors.green.shade600 : const Color(0xffF9A826), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                onPressed: isSubmitting ? null : () => _showConfirmationDialog(total),
                child: isSubmitting ? const CircularProgressIndicator(color: Colors.white) : Text(widget.transactionType == "Buy" ? "Start Purchase Unit" : "Start Rental Unit", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationOption(String title, String price, {bool isBuy = false}) {
    bool isSelected = selectedDuration == title;
    return GestureDetector(
      onTap: () { if(!isBuy) setState(() { selectedDuration = title; }); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        decoration: BoxDecoration(color: isSelected ? (isBuy ? Colors.green.withOpacity(0.05) : const Color(0xffF9A826).withOpacity(0.05)) : Colors.white, border: Border.all(color: isSelected ? (isBuy ? Colors.green : const Color(0xffF9A826)) : Colors.grey.shade200, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(15), boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 3))]),
        child: Column(
          children: [
            Icon(isBuy ? Icons.verified : (title == "Monthly" ? Icons.calendar_today : Icons.calendar_month), color: isSelected ? (isBuy ? Colors.green : const Color(0xffF9A826)) : Colors.grey.shade400, size: 28),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? (isBuy ? Colors.green : const Color(0xffF9A826)) : Colors.black87, fontSize: 15)),
            const SizedBox(height: 5),
            Text(price, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'facility_detail_page.dart';
import 'facility_booking_history_page.dart';

class FacilitiesPage extends StatefulWidget {
  final String unitNo;
  const FacilitiesPage({Key? key, required this.unitNo}) : super(key: key);

  @override
  State<FacilitiesPage> createState() => _FacilitiesPageState();
}

class _FacilitiesPageState extends State<FacilitiesPage> {
  String selectedCategory = "All";
  String userName = "Loading...";
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  bool isLoadingAccess = true;
  bool hasAccess = true;
  String blockReason = "";

  final List<Map<String, dynamic>> categories = [
    {"name": "All", "icon": Icons.apps, "color": Colors.blueGrey},
    {"name": "Sports", "icon": Icons.sports_tennis, "color": Colors.green},
    {"name": "Event & Social", "icon": Icons.celebration, "color": Colors.orange},
    {"name": "Work & Study", "icon": Icons.laptop_mac, "color": Colors.blue},
    {"name": "Wellness", "icon": Icons.spa, "color": Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _checkFacilityAccess();
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  Future<void> _checkFacilityAccess() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits')
          .where('unit_no', isEqualTo: widget.unitNo)
          .get();

      if (unitQuery.docs.isNotEmpty) {
        var data = unitQuery.docs.first.data();
        String ownerUid = data['ownerUid'] ?? '';
        String tenantUid = data['tenantUid'] ?? '';
        String residentUid = data['residentUid'] ?? '';
        String status = data['status'] ?? '';
        String subleaserUid = data['subleaser_uid'] ?? '';

        if (uid == tenantUid || uid == residentUid) {
          if (mounted) setState(() => isLoadingAccess = false);
          return;
        }

        if (uid == ownerUid) {
          if ((status == 'Terisi' || status == 'Occupied' || status == 'Disewakan' || status == 'Reserved') && (tenantUid.isNotEmpty || residentUid.isNotEmpty || subleaserUid == uid)) {
            if (mounted) {
              setState(() {
                hasAccess = false;
                blockReason = "Unit ${widget.unitNo} is currently rented/occupied by a tenant. Facility privileges are transferred to the active resident.";
                isLoadingAccess = false;
              });
            }
            return;
          }
          if (mounted) setState(() => isLoadingAccess = false);
          return;
        }
      }

      var accessQuery = await FirebaseFirestore.instance.collection('unit_access_members')
          .where('unit_no', isEqualTo: widget.unitNo)
          .where('user_uid', isEqualTo: uid)
          .where('status', isEqualTo: 'Active')
          .get();

      if (accessQuery.docs.isNotEmpty) {
        var accessData = accessQuery.docs.first.data();
        Map<String, dynamic> permissions = accessData['permissions'] ?? {};

        if (permissions['Can Book Facilities'] == true) {
          if (mounted) setState(() => isLoadingAccess = false);
          return;
        } else {
          if (mounted) {
            setState(() {
              hasAccess = false;
              blockReason = "You do not have permission to book facilities. Please ask the Primary Resident to grant you access.";
              isLoadingAccess = false;
            });
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          hasAccess = false;
          blockReason = "You are not an active resident or verified member of Unit ${widget.unitNo}.";
          isLoadingAccess = false;
        });
      }

    } catch (e) {
      debugPrint("Access Check Error: $e");
      if (mounted) setState(() => isLoadingAccess = false);
    }
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning,";
    if (hour < 17) return "Good Afternoon,";
    return "Good Evening,";
  }

  Future<void> _fetchUserName() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => userName = "Resident");
        return;
      }
      var userDoc = await FirebaseFirestore.instance.collection("Users").doc(user.uid).get();
      String finalName = "Resident";
      if (userDoc.exists && userDoc.data() != null) {
        var data = userDoc.data()!;
        String fetchedName = data['Name'] ?? data['name'] ?? data['FullName'] ?? user.displayName ?? "";
        if (fetchedName.trim().isNotEmpty) {
          finalName = fetchedName.trim().split(" ")[0];
        }
      } else if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        finalName = user.displayName!.trim().split(" ")[0];
      }
      if (mounted) setState(() => userName = finalName);
    } catch (e) {
      if (mounted) setState(() => userName = "Resident");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Sports': return Colors.green;
      case 'Event & Social': return Colors.orange;
      case 'Work & Study': return Colors.blue;
      case 'Wellness': return Colors.purple;
      default: return Colors.blueGrey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Sports': return Icons.sports_tennis;
      case 'Event & Social': return Icons.celebration;
      case 'Work & Study': return Icons.laptop_mac;
      case 'Wellness': return Icons.spa;
      default: return Icons.domain;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getGreeting(), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text("$userName 👋", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.receipt_long, color: Colors.black87),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacilityBookingHistoryPage(unitNo: widget.unitNo))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => searchQuery = value),
                      enabled: hasAccess && !isLoadingAccess,
                      decoration: InputDecoration(
                        hintText: "Search facilities...",
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey), onPressed: () { _searchController.clear(); setState(() => searchQuery = ""); })
                            : null,
                        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (isLoadingAccess)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Color(0xffF58220))))

            else if (!hasAccess)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.no_accounts_rounded, size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 15),
                      const Text("Facility Access Disabled", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(blockReason, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5)),
                      ),
                    ],
                  ),
                ),
              )

            else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        bool isSelected = selectedCategory == cat['name'];
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedCategory = cat['name'];
                              searchQuery = "";
                              _searchController.clear();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: cat['color'].withOpacity(0.15), shape: BoxShape.circle, border: Border.all(color: isSelected ? cat['color'] : Colors.transparent, width: 2)),
                                  child: Icon(cat['icon'], color: cat['color']),
                                ),
                                const SizedBox(height: 8),
                                Text(cat['name'], style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.black87 : Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 25),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(searchQuery.isNotEmpty ? "Search Results" : "Available Facilities", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('Facilities').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: Color(0xffF58220)));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 60, color: Colors.grey.shade300), const SizedBox(height: 10), Text("No facilities found", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))]));
                        }

                        List<Map<String, dynamic>> allFacilities = snapshot.data!.docs.map((doc) {
                          var data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
                          String id = data['id'] ?? doc.id;
                          data['id'] = id;
                          data['color'] = _getCategoryColor(data['category'] ?? 'All');
                          data['icon'] = _getCategoryIcon(data['category'] ?? 'All');

                          bool isNew = false;
                          if (id.startsWith("F_")) {
                            try {
                              int epochStr = int.parse(id.substring(2));
                              DateTime createdAt = DateTime.fromMillisecondsSinceEpoch(epochStr);
                              if (DateTime.now().difference(createdAt).inDays <= 14) {
                                isNew = true;
                              }
                            } catch (e) {}
                          }
                          data['isNew'] = isNew;

                          return data;
                        }).toList();

                        List<Map<String, dynamic>> filteredFacilities;
                        if (searchQuery.isNotEmpty) {
                          filteredFacilities = allFacilities.where((f) => f['name'].toString().toLowerCase().contains(searchQuery.toLowerCase())).toList();
                        } else if (selectedCategory == "All") {
                          filteredFacilities = allFacilities;
                        } else {
                          filteredFacilities = allFacilities.where((f) => f['category'] == selectedCategory).toList();
                        }

                        filteredFacilities.sort((a, b) {
                          if (a['isNew'] && !b['isNew']) return -1;
                          if (!a['isNew'] && b['isNew']) return 1;
                          return a['name'].toString().compareTo(b['name'].toString());
                        });

                        if (filteredFacilities.isEmpty) {
                          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 60, color: Colors.grey.shade300), const SizedBox(height: 10), Text("No facilities found", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold))]));
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                          itemCount: filteredFacilities.length,
                          itemBuilder: (context, index) {
                            var fac = filteredFacilities[index];
                            bool isOpenType = fac['type'] == 'Open';
                            bool isNew = fac['isNew'] ?? false;

                            String priceText = "";
                            if (isOpenType) priceText = "Included in IPL";
                            else if (fac['is_paid'] == false) priceText = "Free (Fair Usage)";
                            else priceText = "${formatCurrency((fac['price_per_hour'] ?? 0) * 2)} / slot";

                            return GestureDetector(
                              onTap: () {
                                if (isOpenType) {
                                  showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        title: Row(children: [Icon(fac['icon'], color: fac['color']), const SizedBox(width: 10), Expanded(child: Text(fac['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)))]),
                                        content: Text("This facility is an 'Open Use' type (Free).\n\nNo booking is required. This facility is intended for daily communal use.\n\nRules & Regulations:\n${fac['rules'] ?? '-'}", style: const TextStyle(height: 1.4)),
                                        actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF58220), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), onPressed: () => Navigator.pop(context), child: const Text("Understood", style: TextStyle(color: Colors.white)))],
                                      )
                                  );
                                } else {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => FacilityDetailPage(unitNo: widget.unitNo, facilityData: fac)));
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(height: 80, width: 80, decoration: BoxDecoration(color: fac['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(fac['icon'], color: fac['color'], size: 35)),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(child: Text(fac['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                              if (isNew)
                                                Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                                                  child: const Text("NEW 🔥", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                                )
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(fac['category'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                          const SizedBox(height: 6),
                                          Text("Capacity: ${fac['capacity']} people", style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                                          const SizedBox(height: 2),
                                          Text(priceText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isOpenType ? Colors.green : (fac['is_paid'] == true ? Colors.black87 : Colors.blue))),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                  ),
                )
              ]
          ],
        ),
      ),
    );
  }
}
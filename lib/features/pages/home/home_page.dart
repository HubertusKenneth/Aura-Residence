import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:my_apart/features/pages/unit_management/unit_details_page.dart';
import 'package:my_apart/features/pages/unit_management/unit_contract_extension_page.dart';
import 'package:my_apart/features/pages/unit_management/owner_dashboard_page.dart';
import 'package:my_apart/features/pages/billing/billing_detail_page.dart';
import 'package:my_apart/features/pages/billing/billing_page.dart';
import 'package:my_apart/features/pages/maintenance/maintenance_page.dart';
import 'package:my_apart/features/pages/facilities/facilities_page.dart';
import 'package:my_apart/features/pages/visitor_and_parking/parking_page.dart';
import 'package:my_apart/features/pages/visitor_and_parking/visitor_access_page.dart';
import '../../../core/widgets/home_carousel_banner.dart';

class HomePage extends StatefulWidget {
  final List<QueryDocumentSnapshot> units;
  final String? selectedUnitId;
  final bool isSwitchingUnit;
  final String userName;
  final String uid;
  final int lockoutDay;
  final String? secretaryId;
  final Map<String, String> sharedRolesCache;

  final String Function(num) formatCurrency;
  final Widget greetingWidget;
  final Function(List<QueryDocumentSnapshot>, String) onSwitchUnitTap;
  final Function(String, String, String) onSetPriceTap;
  final Function(String, String, String) onSellPriceTap;
  final Function(String, String, String) onWithdrawTap;
  final VoidCallback onLinkUnitTap;
  final VoidCallback onRentUnitTap;

  const HomePage({
    Key? key,
    required this.units,
    this.selectedUnitId,
    required this.isSwitchingUnit,
    required this.userName,
    required this.uid,
    required this.lockoutDay,
    this.secretaryId,
    required this.sharedRolesCache,
    required this.formatCurrency,
    required this.greetingWidget,
    required this.onSwitchUnitTap,
    required this.onSetPriceTap,
    required this.onSellPriceTap,
    required this.onWithdrawTap,
    required this.onLinkUnitTap,
    required this.onRentUnitTap,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  String _calculateRemainingTime(String? endDateStr) {
    if (endDateStr == null || endDateStr == "Permanent") return "Permanent";
    try {
      DateTime end = DateTime.parse(endDateStr);
      DateTime now = DateTime.now();
      if (end.isBefore(now)) return "Expired";
      int days = end.difference(now).inDays;
      if (days >= 30) {
        int months = days ~/ 30;
        int remainDays = days % 30;
        return remainDays == 0 ? "$months months remaining" : "$months mo $remainDays days remaining";
      } else {
        return "$days days remaining";
      }
    } catch (e) {
      return "Active Tenant";
    }
  }

  Widget _buildUserGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.greetingWidget,
        const SizedBox(height: 2),
        Text(
          widget.userName,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo.shade700, letterSpacing: 0.3),
        ),
      ],
    );
  }

  Widget _buildSmallActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildServiceMenu(IconData icon, String title, Color bgColor, Color iconColor, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 75,
        child: Column(
          children: [
            Container(
              height: 55, width: 55,
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.units.isEmpty) return const SizedBox.shrink();

    Map<String, QueryDocumentSnapshot> uniqueUnits = {};
    for (var doc in widget.units) {
      var data = doc.data() as Map<String, dynamic>;
      String tower = (data['tower'] ?? "").toString().trim();
      String unitNo = (data['unit_no'] ?? "").toString().trim();
      String unitKey = "${tower}_${unitNo}";

      if (!uniqueUnits.containsKey(unitKey)) {
        uniqueUnits[unitKey] = doc;
      } else {
        var existingData = uniqueUnits[unitKey]!.data() as Map<String, dynamic>;
        Timestamp tExisting = existingData['timestamp'] as Timestamp? ?? Timestamp(0, 0);
        Timestamp tNew = data['timestamp'] as Timestamp? ?? Timestamp(0, 0);
        String tExistType = existingData['transaction_type'] ?? "";
        String tNewType = data['transaction_type'] ?? "";

        if (tNewType == "Buy" && tExistType != "Buy") {
          uniqueUnits[unitKey] = doc;
        } else if (tExistType == "Buy" && tNewType != "Buy") {
        } else if (tNew.compareTo(tExisting) > 0) {
          uniqueUnits[unitKey] = doc;
        }
      }
    }

    List<QueryDocumentSnapshot> cleanUnits = uniqueUnits.values.toList();
    cleanUnits.sort((a, b) {
      var dA = a.data() as Map<String, dynamic>;
      var dB = b.data() as Map<String, dynamic>;
      return (dA['unit_no'] ?? "").compareTo(dB['unit_no'] ?? "");
    });

    QueryDocumentSnapshot activeDoc = cleanUnits.first;
    if (widget.selectedUnitId != null) {
      try {
        activeDoc = cleanUnits.firstWhere((doc) => doc.id == widget.selectedUnitId);
      } catch (e) {
        activeDoc = cleanUnits.first;
      }
    }

    Map<String, dynamic> activeUnitData = Map<String, dynamic>.from(activeDoc.data() as Map<String, dynamic>);
    bool isSharedMember = activeDoc.id.startsWith("SHARED_");
    bool isPrimaryResident = !isSharedMember;
    activeUnitData['isSharedMember'] = isSharedMember;

    String currentUnitNo = activeUnitData['unit_no'] ?? "Unknown";
    bool isPermanent = activeUnitData['transaction_type']?.toString().contains('Buy') == true || activeUnitData['duration'] == 'Permanent (Ownership)';
    bool isListed = activeUnitData['is_rented_out'] ?? false;

    String dbStatus = activeUnitData['status'] ?? "Occupied";
    bool isStillPending = (dbStatus.contains("Pending") || dbStatus.contains("Awaiting") || dbStatus.contains("Processing")) && activeUnitData['transaction_type'] != "Lease Extension";

    String remainingTime = _calculateRemainingTime(activeUnitData['contract_end_date']);
    String subtitleText = "${activeUnitData['tower'] ?? 'Tower'}";
    String roleForUnit = isPermanent ? "Owner" : "Tenant";

    if (isPermanent) {
      subtitleText += " • Owned Unit";
      if (dbStatus == "Disewakan") subtitleText += " • Listed for Rent";
      else if (dbStatus == "Dijual") subtitleText += " • Listed for Sale";
    } else if (isStillPending) {
      subtitleText += " • Application Pending";
    } else {
      if (remainingTime != "Permanent" && remainingTime != "Active Tenant" && remainingTime != "Expired") {
        subtitleText += " • Active Tenant • $remainingTime";
      } else {
        subtitleText += " • Active Tenant";
      }
    }

    bool canViewBills = isPrimaryResident || (isSharedMember && widget.sharedRolesCache[currentUnitNo] == 'Resident Member');
    String currentPeriod = DateFormat('MMMM yyyy').format(DateTime.now());

    if (widget.isSwitchingUnit) {
      return const Center(child: CircularProgressIndicator(color: Color(0xffF9A826)));
    }

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("billing_invoices").where("unit_no", isEqualTo: currentUnitNo).snapshots(),
        builder: (context, billSnap) {

          num currentOverdueAmount = 0;
          num currentPendingAmount = 0;
          num currentMonthAmount = 0;
          DocumentSnapshot? firstOverdueDoc;
          DocumentSnapshot? firstPendingDoc;

          if (billSnap.hasData && billSnap.connectionState != ConnectionState.waiting) {
            for (var doc in billSnap.data!.docs) {
              var data = doc.data() as Map<String, dynamic>;
              String period = data['billing_period'] ?? '';
              String status = data['status'] ?? '';
              num amount = data['total_amount'] ?? 0;

              if (period == currentPeriod) {
                currentMonthAmount = amount;
              } else {
                if (status == "UNPAID" || status == "OVERDUE") {
                  currentOverdueAmount += amount;
                  if (firstOverdueDoc == null) firstOverdueDoc = doc;
                } else if (status == "PENDING") {
                  currentPendingAmount += amount;
                  if (firstPendingDoc == null) firstPendingDoc = doc;
                }
              }
            }
          }

          num grandTotal = currentOverdueAmount + currentPendingAmount + currentMonthAmount;
          bool shouldLockout = (roleForUnit == "Tenant") && (currentOverdueAmount > 0 || currentPendingAmount > 0) && (DateTime.now().day > widget.lockoutDay);
          bool isPendingVerification = shouldLockout && currentOverdueAmount == 0 && currentPendingAmount > 0;

          Color balanceColor = currentOverdueAmount > 0 ? Colors.red : (currentPendingAmount > 0 ? Colors.purple : const Color(0xffF9A826));
          IconData balanceIcon = currentOverdueAmount > 0 ? Icons.account_balance_wallet : (currentPendingAmount > 0 ? Icons.hourglass_top : Icons.account_balance_wallet);

          return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ApartmentUnits').where('unit_no', isEqualTo: currentUnitNo).where('tower', isEqualTo: activeUnitData['tower']).snapshots(),
              builder: (context, unitSnap) {

                Map<String, dynamic>? liveUnitData;
                if (unitSnap.hasData && unitSnap.data!.docs.isNotEmpty) {
                  liveUnitData = unitSnap.data!.docs.first.data() as Map<String, dynamic>;
                }

                bool hasActiveTenant = false;
                if (liveUnitData != null) {
                  String currentStatus = liveUnitData['status'] ?? '';
                  String residentUid = liveUnitData['residentUid'] ?? '';
                  hasActiveTenant = (isListed && currentStatus != 'Disewakan' && currentStatus != 'Dijual') || (residentUid.isNotEmpty && residentUid != widget.uid && isListed);
                }

                return Stack(
                  children: [
                    SingleChildScrollView(
                      physics: shouldLockout ? const NeverScrollableScrollPhysics() : null,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              const CarouselBanner(),
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                child: Container(
                                  height: 30,
                                  decoration: const BoxDecoration(
                                    color: Color(0xffF5F6F8),
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            color: const Color(0xffF5F6F8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 5),
                                  _buildUserGreeting(),
                                  const SizedBox(height: 25),

                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isStillPending
                                              ? [Colors.blueGrey.shade400, Colors.blueGrey.shade600]
                                              : [Colors.orange.shade400, Colors.deepOrange.shade500],
                                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [BoxShadow(color: isStillPending ? Colors.blueGrey.withOpacity(0.3) : Colors.orange.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(isStillPending ? Icons.hourglass_top : Icons.check_circle, color: Colors.white, size: 14),
                                                  const SizedBox(width: 5),
                                                  Text(isStillPending ? "Processing" : "Active & Secure", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.apartment_rounded, color: Colors.white54, size: 28)
                                          ],
                                        ),
                                        const SizedBox(height: 15),

                                        GestureDetector(
                                          onTap: cleanUnits.length > 1 ? () => widget.onSwitchUnitTap(cleanUnits, activeDoc.id) : null,
                                          child: Container(
                                            color: Colors.transparent,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text("Unit $currentUnitNo", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1)),
                                                if (cleanUnits.length > 1) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.all(4),
                                                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                                    child: const Icon(Icons.swap_vert_rounded, color: Colors.white, size: 18),
                                                  )
                                                ]
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(subtitleText, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                        const SizedBox(height: 20),

                                        Row(
                                          children: [
                                            Expanded(
                                              child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor: isStillPending ? Colors.blueGrey.shade700 : Colors.deepOrange.shade600,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  elevation: 0,
                                                ),
                                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnitDetailsPage(unitData: activeUnitData))),
                                                icon: const Icon(Icons.info_outline, size: 16),
                                                label: const Text("Unit Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              ),
                                            ),

                                            if (isPrimaryResident && !isPermanent) ...[
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: Colors.white,
                                                    side: const BorderSide(color: Colors.white70),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                  ),
                                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnitContractExtensionPage(unitNo: currentUnitNo))),
                                                  icon: const Icon(Icons.edit_calendar, size: 16),
                                                  label: const Text("Extend Lease", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                ),
                                              )
                                            ]
                                          ],
                                        ),

                                        if (isPrimaryResident && isPermanent) ...[
                                          const SizedBox(height: 10),
                                          if (hasActiveTenant)
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white54),
                                                  backgroundColor: Colors.black26, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                onPressed: null,
                                                child: const Text("Unit is Currently Occupied", style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            )
                                          else if (isListed)
                                            SizedBox(
                                              width: double.infinity,
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70),
                                                  backgroundColor: Colors.red.withOpacity(0.3), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                onPressed: () => widget.onWithdrawTap(currentUnitNo, activeUnitData['tower'], activeDoc.id),
                                                icon: const Icon(Icons.cancel, size: 16),
                                                label: const Text("Withdraw Listing from Catalog", style: TextStyle(fontWeight: FontWeight.bold)),
                                              ),
                                            )
                                          else
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    onPressed: () => widget.onSetPriceTap(currentUnitNo, activeUnitData['tower'], activeDoc.id),
                                                    icon: const Icon(Icons.real_estate_agent, size: 16),
                                                    label: const Text("Rent Out", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70),
                                                      backgroundColor: Colors.green.withOpacity(0.3),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    onPressed: () => widget.onSellPriceTap(currentUnitNo, activeUnitData['tower'], activeDoc.id),
                                                    icon: const Icon(Icons.sell, size: 16),
                                                    label: const Text("Sell Unit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ),
                                                )
                                              ],
                                            )
                                        ],

                                        if (isPermanent && isListed && isPrimaryResident)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 10),
                                            child: SizedBox(
                                              width: double.infinity,
                                              child: TextButton.icon(
                                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboardPage())),
                                                icon: const Icon(Icons.people, color: Colors.white, size: 18),
                                                label: const Text("Manage Tenant / Applicants", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                                style: TextButton.styleFrom(backgroundColor: Colors.white12),
                                              ),
                                            ),
                                          )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 25),

                                  if (canViewBills) ...[
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(color: balanceColor.withOpacity(0.1), shape: BoxShape.circle),
                                                  child: Icon(balanceIcon, color: balanceColor, size: 24),
                                                ),
                                                const SizedBox(width: 15),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text("Total Outstanding Balance", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                                                      Text(widget.formatCurrency(grandTotal), style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.w900)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          _buildSmallActionBtn(Icons.arrow_upward, "Pay", Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillingPage(unitNo: currentUnitNo))).then((_) => setState((){}))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                  ],

                                  const Text("Resident Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  const SizedBox(height: 15),

                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildServiceMenu(Icons.build_circle, "Report\nIssue", Colors.blue.shade50, Colors.blue.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaintenancePage(unitNo: currentUnitNo)))),
                                      _buildServiceMenu(Icons.sports_tennis, "Book\nFacility", Colors.purple.shade50, Colors.purple.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacilitiesPage(unitNo: currentUnitNo)))),
                                      _buildServiceMenu(Icons.local_parking, "Parking\nMember", Colors.teal.shade50, Colors.teal.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParkingPage(unitNo: currentUnitNo)))),
                                      _buildServiceMenu(Icons.qr_code_scanner, "Visitor\nAccess", Colors.red.shade50, Colors.red.shade600, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitorAccessPage(unitNo: currentUnitNo)))),
                                    ],
                                  ),
                                  const SizedBox(height: 35),

                                  const Text("Looking for more space?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                  const SizedBox(height: 15),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.shade200),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.add_home_work, color: Colors.blueGrey, size: 28),
                                        ),
                                        const SizedBox(width: 15),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("Rent Another Unit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                              SizedBox(height: 4),
                                              Text("Explore available units for family or business.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right, color: Colors.grey),
                                          onPressed: widget.onRentUnitTap,
                                        )
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: const Color(0xffF4F8FF),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.blue.shade50, width: 2)
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(12)),
                                          child: Icon(Icons.vpn_key, color: Colors.blue.shade700, size: 28),
                                        ),
                                        const SizedBox(width: 15),
                                        const Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text("Link Another Unit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                              SizedBox(height: 4),
                                              Text("Purchased or rented offline? Link it here.", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right, color: Colors.grey),
                                          onPressed: widget.onLinkUnitTap,
                                        )
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 80),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    if (shouldLockout)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black87.withOpacity(0.85),
                          child: Center(
                            child: Material(
                              color: Colors.transparent,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 30),
                                padding: const EdgeInsets.all(25),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))]
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          isPendingVerification ? Icons.hourglass_top : Icons.gavel,
                                          color: isPendingVerification ? Colors.purple : Colors.red,
                                          size: 50
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                          isPendingVerification ? "Payment Verification" : "Unit Access Suspended",
                                          style: TextStyle(color: isPendingVerification ? Colors.purple : Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                                          textAlign: TextAlign.center
                                      ),
                                      const SizedBox(height: 15),
                                      Text(
                                        isPendingVerification
                                            ? "Your payment of ${widget.formatCurrency(currentPendingAmount)} is currently being verified by the management.\n\nYour access to the unit and facilities remains temporarily restricted until the payment is fully approved."
                                            : "It is past the ${widget.lockoutDay}${widget.lockoutDay == 1 ? 'st' : widget.lockoutDay == 2 ? 'nd' : widget.lockoutDay == 3 ? 'rd' : 'th'} of the month.\n\nYou have an overdue balance of ${widget.formatCurrency(currentOverdueAmount)}.\n\nYour access to the unit and facilities is temporarily restricted. Please settle your overdue bills immediately to restore access.",
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(height: 1.5, fontSize: 13),
                                      ),
                                      const SizedBox(height: 25),

                                      if (canViewBills)
                                        SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: isPendingVerification ? Colors.purple : Colors.red,
                                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                                              ),
                                              icon: Icon(isPendingVerification ? Icons.receipt_long : Icons.payment, color: Colors.white),
                                              label: Text(isPendingVerification ? "View Pending Bill" : "Pay Overdue Bills", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              onPressed: () {
                                                if (isPendingVerification && firstPendingDoc != null) {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) => BillingDetailPage(
                                                              invoiceId: firstPendingDoc!.id,
                                                              invoiceData: firstPendingDoc!.data() as Map<String, dynamic>,
                                                              isViewOnly: true,
                                                              isCurrentMonth: false,
                                                              autoOpenPayment: false
                                                          )
                                                      )
                                                  ).then((_) => setState((){}));
                                                } else if (!isPendingVerification && firstOverdueDoc != null) {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (_) => BillingDetailPage(
                                                              invoiceId: firstOverdueDoc!.id,
                                                              invoiceData: firstOverdueDoc!.data() as Map<String, dynamic>,
                                                              isViewOnly: false,
                                                              isCurrentMonth: false,
                                                              autoOpenPayment: true
                                                          )
                                                      )
                                                  ).then((_) => setState((){}));
                                                } else {
                                                  Navigator.push(context, MaterialPageRoute(builder: (_) => BillingPage(unitNo: currentUnitNo))).then((_) => setState((){}));
                                                }
                                              },
                                            )
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.all(15),
                                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.warning, color: Colors.red),
                                              const SizedBox(width: 10),
                                              const Expanded(child: Text("Please contact the Primary Resident or Owner to settle the overdue bills and restore unit access.", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
                                            ],
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                  ],
                );
              }
          );
        }
    );
  }
}
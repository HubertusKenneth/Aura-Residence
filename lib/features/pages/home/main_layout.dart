import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:my_apart/features/pages/profile/profile_page.dart';
import 'package:my_apart/features/pages/unit_management/rent_page.dart';
import 'package:my_apart/features/pages/unit_management/my_apartment_page.dart';
import 'package:my_apart/features/pages/communications/notifications_page.dart';
import 'package:my_apart/features/pages/communications/chatbot_page.dart';

import '../../../core/widgets/home_navbar.dart';
import 'home_page.dart';
import 'guest_page.dart';

Set<String> _shownPopupIds = {};
Set<String> _globalProcessedAppStatuses = {};
bool _globalIsActionDialogShowing = false;

class MainLayout extends StatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
      ),
      child: const MainLayoutScreen(),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({Key? key}) : super(key: key);

  @override
  _MainLayoutScreenState createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _selectedIndex = 0;
  DateTime? _lastPressedAt;

  late PageController _pageController;

  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _unitsScrollController = ScrollController();
  final ScrollController _inboxScrollController = ScrollController();
  final ScrollController _profileScrollController = ScrollController();

  String? secretaryId;
  String userName = "Resident";
  String userPhone = "";
  bool isLoading = true;
  bool isLandlord = false;
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  String? _selectedUnitId;

  bool _isSwitchingUnit = false;

  List<QueryDocumentSnapshot>? _cachedOccupiedUnits;
  Map<String, String> _sharedRolesCache = {};
  Future<QuerySnapshot>? _cachedUnitsFuture;

  int _lockoutDay = 10;
  int _unreadNotifCount = 0;

  final List<String> activeStatuses = [
    "Occupied", "Approved & Active", "Requesting End Contract",
    "Pending Owner Approval", "Pending Initial Review",
    "Awaiting Payment", "Awaiting Admin Payment Verification", "Processing Move-in",
    "Owned"
  ];

  StreamSubscription<QuerySnapshot>? _broadcastSubscription;
  StreamSubscription<QuerySnapshot>? _unitSubscription;
  StreamSubscription<QuerySnapshot>? _sharedSubscription;
  StreamSubscription<QuerySnapshot>? _notifSubscription;
  StreamSubscription<QuerySnapshot>? _appSubscription;

  Set<String> _userTowers = {};
  Map<String, String> _knownAppStatuses = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);

    _startListeningToImportantBroadcasts();
    _startListeningToNotifications();
    _cachedUnitsFuture = FirebaseFirestore.instance.collection('ApartmentUnits').get();
    _fetchUserData();

    _sharedSubscription = FirebaseFirestore.instance.collection("unit_access_members").where("user_uid", isEqualTo: uid).snapshots().listen((_) {
      if (mounted) _fetchUserData();
    });

    _unitSubscription = FirebaseFirestore.instance.collection("ApartmentUnits").where("ownerUid", isEqualTo: uid).snapshots().listen((_) {
      if (mounted) _fetchUserData();
    });

    _appSubscription = FirebaseFirestore.instance
        .collection("RentalApplications")
        .where("tenantUid", isEqualTo: uid)
        .snapshots()
        .listen((snapshot) {
      bool shouldFetch = false;

      for (var change in snapshot.docChanges) {
        var data = change.doc.data() as Map<String, dynamic>? ?? {};
        String appId = change.doc.id;
        String newStatus = data['status']?.toString().trim() ?? '';
        String oldStatus = _knownAppStatuses[appId] ?? '';

        if (change.type == DocumentChangeType.added) {
          _knownAppStatuses[appId] = newStatus;
          shouldFetch = true;
        } else if (change.type == DocumentChangeType.modified) {
          if (oldStatus != newStatus || data['last_actor'] == 'admin') {
            _knownAppStatuses[appId] = newStatus;
            shouldFetch = true;

            String unitNo = data['unit_no'] ?? 'Unknown';
            String lastActor = data['last_actor'] ?? '';
            String lastAction = data['last_action'] ?? '';

            if (lastActor == 'admin' && mounted) {
              String lockKey = "${appId}_$lastAction";

              if (!_globalProcessedAppStatuses.contains(lockKey)) {
                _globalProcessedAppStatuses.add(lockKey);

                if (lastAction == 'decline_end_contract') {
                  _showActionDialog("Request Declined ❌", "Your termination request for Unit $unitNo was declined. Your contract remains active.", isSuccess: false);
                } else if (lastAction == 'decline_extension') {
                  _showActionDialog("Request Declined ❌", "Your extension request for Unit $unitNo was declined. Your contract remains active.", isSuccess: false);
                } else if (lastAction == 'approve_end_contract') {
                  _showActionDialog("Contract Terminated", "Your request to end the contract for Unit $unitNo has been approved. Thank you for staying with us.", isSuccess: true);
                } else if (lastAction == 'approve_new' || lastAction == 'approve_offline') {
                  _showActionDialog("Request Approved! 🎉", "Your request for Unit $unitNo has been approved by the management. You can now access your unit features.", isSuccess: true);
                } else if (lastAction == 'decline_new') {
                  String reason = data['reject_reason'] ?? data['decline_reason'] ?? 'No specific reason provided.';
                  _showActionDialog("Request Declined ❌", "Your request for Unit $unitNo was declined by the admin.\n\nReason: $reason", isSuccess: false);
                }
              }
            }
          }
        } else if (change.type == DocumentChangeType.removed) {
          _knownAppStatuses.remove(appId);
          shouldFetch = true;
        }
      }

      if (shouldFetch && mounted) {
        _fetchUserData();
      }
    });
  }

  @override
  void dispose() {
    _broadcastSubscription?.cancel();
    _unitSubscription?.cancel();
    _sharedSubscription?.cancel();
    _notifSubscription?.cancel();
    _appSubscription?.cancel();
    _pageController.dispose();

    // --- TAMBAHAN: Bersihkan memori Scroll Controller ---
    _homeScrollController.dispose();
    _unitsScrollController.dispose();
    _inboxScrollController.dispose();
    _profileScrollController.dispose();

    super.dispose();
  }

  Future<void> _runMasterHealer() async {
    try {
      String? secId;
      final secQuery = await FirebaseFirestore.instance.collection("Secretary").get();
      for (var doc in secQuery.docs) {
        final memberDoc = await FirebaseFirestore.instance.collection("Secretary").doc(doc.id).collection("Members").doc(uid).get();
        if (memberDoc.exists) { secId = doc.id; break; }
      }

      if (secId != null) {
        var myBookings = await FirebaseFirestore.instance.collection("Secretary").doc(secId).collection("Members").doc(uid).collection("Bookings").get();

        for (var b in myBookings.docs) {
          var bData = b.data();
          String status = bData['status'] ?? '';
          String tType = bData['transaction_type'] ?? '';
          String uNo = bData['unit_no'] ?? '';
          String uTower = bData['tower'] ?? '';

          if (status == "Occupied" || status == "Approved & Active" || status == "Owned") {
            bool isPerm = tType.contains("Buy") || (bData["duration"] ?? "").toString().contains("Permanent");

            var checkUnit = await FirebaseFirestore.instance.collection("ApartmentUnits")
                .where("tower", isEqualTo: uTower)
                .where("unit_no", isEqualTo: uNo).get();

            if (checkUnit.docs.isNotEmpty) {
              String currentOwner = checkUnit.docs.first.data()['ownerUid'] ?? "";

              if (isPerm && currentOwner.isNotEmpty && currentOwner != uid) {
                await b.reference.update({"status": "Ownership Transferred", "updatedAt": FieldValue.serverTimestamp()});
                var appQuery = await FirebaseFirestore.instance.collection("RentalApplications").where("tenantUid", isEqualTo: uid).where("unit_no", isEqualTo: uNo).where("tower", isEqualTo: uTower).get();
                for (var app in appQuery.docs) {
                  await app.reference.update({"status": "Ownership Transferred", "updatedAt": FieldValue.serverTimestamp()});
                }
              }
            } else {
              await b.reference.delete();
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Master Healer Error: $e");
    }
  }

  String formatCurrency(num amount) {
    return NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(amount);
  }

  void _startListeningToNotifications() {
    _notifSubscription = FirebaseFirestore.instance
        .collection("Users")
        .doc(uid)
        .collection("Notifications")
        .where("isRead", isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadNotifCount = snapshot.docs.length;
        });
      }
    });
  }

  void _startListeningToImportantBroadcasts() {
    DateTime listenerStartTime = DateTime.now();

    _broadcastSubscription = FirebaseFirestore.instance
        .collection("Broadcasts")
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          var data = change.doc.data() as Map<String, dynamic>?;
          if (data == null) continue;

          Timestamp? ts = data['timestamp'] as Timestamp?;
          if (ts != null && ts.toDate().isAfter(listenerStartTime)) {
            String category = data['category'] ?? "Information";
            if (category == "Important" || category == "Penting") {
              if (!_shownPopupIds.contains(change.doc.id)) {
                String target = data['targetName'] ?? "All Towers";
                if (target == "All Towers" || target == "Semua Tower" || _userTowers.contains(target)) {
                  _shownPopupIds.add(change.doc.id);
                  _showImportantAnnouncementPopup(data['content'] ?? "No message content.");
                }
              }
            }
          }
        }
      }
    });
  }

  void _showImportantAnnouncementPopup(String content) {
    if (!mounted) return;
    OverlayState? overlayState = Overlay.of(context);
    if (overlayState == null) return;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 15,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                overlayEntry.remove();
                _pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.easeInOutQuart);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.campaign, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Important Announcement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text(content, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  void _showActionDialog(String title, String message, {bool isSuccess = true}) {
    if (_globalIsActionDialogShowing) return;
    _globalIsActionDialogShowing = true;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(25),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                      isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: isSuccess ? Colors.green : Colors.red,
                      size: 40
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isSuccess ? Colors.green : Colors.red,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12)
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                    },
                    child: const Text("OK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          );
        }
    ).then((_) {
      _globalIsActionDialogShowing = false;
      if (mounted) _fetchUserData();
    });
  }

  Future<void> _fetchUserData() async {
    try {
      await _runMasterHealer();

      var configDoc = await FirebaseFirestore.instance.collection('AppConfig').doc('billing_rates').get();
      if (configDoc.exists) {
        _lockoutDay = configDoc.data()?['due_date'] ?? 10;
      }

      var userBaseDoc = await FirebaseFirestore.instance.collection("Users").doc(uid).get();
      if (userBaseDoc.exists && userBaseDoc.data() != null) {
        var data = userBaseDoc.data()!;
        String fetchedName = data['FullName'] ?? data['fullName'] ?? data['Name'] ?? data['name'] ?? "Resident";
        String fetchedPhone = (data['Phone'] ?? data['phone'] ?? data['phoneNumber'] ?? data['phone_number'] ?? "").toString().trim();

        if ((userName != fetchedName || userPhone != fetchedPhone) && mounted) {
          setState(() {
            userName = fetchedName;
            userPhone = fetchedPhone;
          });
        }
      }

      var ownerCheck = await FirebaseFirestore.instance.collection('ApartmentUnits').where('ownerUid', isEqualTo: uid).get();
      var subleaseCheck = await FirebaseFirestore.instance.collection('ApartmentUnits').where('subleaser_uid', isEqualTo: uid).get();
      var appCheck = await FirebaseFirestore.instance.collection('RentalApplications').where('ownerUid', isEqualTo: uid).get();

      bool landlordStatus = ownerCheck.docs.isNotEmpty || subleaseCheck.docs.isNotEmpty || appCheck.docs.isNotEmpty;

      var rentQuery = await FirebaseFirestore.instance.collection('RentalApplications').where('tenantUid', isEqualTo: uid).get();
      Set<String> myTowers = {};

      for (var doc in rentQuery.docs) {
        var data = doc.data();
        String currentAppStatus = data['status']?.toString() ?? "";

        if (activeStatuses.contains(currentAppStatus)) {
          myTowers.add(data['tower']?.toString().trim() ?? "");
        }
      }
      _userTowers = myTowers;

      final querySnapshot = await FirebaseFirestore.instance.collection("Secretary").get();
      for (var doc in querySnapshot.docs) {
        final memberDoc = await FirebaseFirestore.instance.collection("Secretary").doc(doc.id).collection("Members").doc(uid).get();

        if (memberDoc.exists) {
          String secId = doc.id;
          secretaryId = secId;

          try {
            var validShared = await FirebaseFirestore.instance.collection("unit_access_members").where("user_uid", isEqualTo: uid).get();
            List<String> validUnitNos = [];

            for (var d in validShared.docs) {
              String uNo = d['unit_no'].toString();
              validUnitNos.add(uNo);
              _sharedRolesCache[uNo] = d['role']?.toString() ?? 'Limited Access';
            }

            var myBookings = await FirebaseFirestore.instance.collection("Secretary").doc(secId).collection("Members").doc(uid).collection("Bookings").get();

            var ownedUnits = await FirebaseFirestore.instance.collection('ApartmentUnits').where('ownerUid', isEqualTo: uid).get();
            List<String> validOwnedIds = ownedUnits.docs.map((e) => "OWNED_${e.id}").toList();

            for (var b in myBookings.docs) {
              if (b.id.startsWith("SHARED_")) {
                String bookingUnitNo = b.data()['unit_no'] ?? '';
                if (!validUnitNos.contains(bookingUnitNo)) {
                  await b.reference.delete();
                }
              } else if (b.id.startsWith("OWNED_")) {
                if (!validOwnedIds.contains(b.id)) {
                  await b.reference.delete();
                }
              }
            }
          } catch (e) {
            debugPrint("Self-healing error: $e");
          }

          try {
            var myApps = await FirebaseFirestore.instance
                .collection("RentalApplications")
                .where("tenantUid", isEqualTo: uid)
                .get();

            for (var app in myApps.docs) {
              var appData = app.data();
              var bookingRef = FirebaseFirestore.instance
                  .collection("Secretary").doc(secId)
                  .collection("Members").doc(uid)
                  .collection("Bookings").doc(app.id);

              var existing = await bookingRef.get();
              String appStatus = appData["status"]?.toString().trim() ?? "";
              String tType = appData["transaction_type"] ?? "";
              String eEndDate = appData["contract_end_date"]?.toString() ?? "";

              if (!activeStatuses.contains(appStatus)) {
                if (existing.exists) {
                  Map<String, dynamic>? eData = existing.data() as Map<String, dynamic>?;
                  if (eData?["status"] != appStatus) {
                    await bookingRef.update({
                      "status": appStatus,
                      "reject_reason": appData["reject_reason"] ?? appData["decline_reason"] ?? ""
                    });
                  }
                }
              } else {
                if (!existing.exists) {
                  await bookingRef.set({
                    "unit_no": appData["unit_no"] ?? "Unknown",
                    "tower": appData["tower"] ?? "Unknown",
                    "transaction_type": appData["transaction_type"] ?? "Rent",
                    "duration": appData["duration"] ?? "Monthly",
                    "contract_end_date": appData["contract_end_date"] ?? "Permanent",
                    "is_rented_out": false,
                    "status": appStatus,
                    "timestamp": appData["timestamp"] ?? FieldValue.serverTimestamp(),
                  });
                } else {
                  Map<String, dynamic>? eData = existing.data() as Map<String, dynamic>?;
                  String eStatus = eData?["status"]?.toString() ?? "";
                  String eTransType = eData?["transaction_type"]?.toString() ?? "";
                  String currentEEndDate = eData?["contract_end_date"]?.toString() ?? "";

                  String newTransType = appData["transaction_type"] ?? eTransType;
                  if (newTransType.isEmpty) newTransType = "Rent";

                  String newEndDate = appData["contract_end_date"] ?? currentEEndDate;
                  if (newEndDate.isEmpty) newEndDate = "Permanent";

                  if (eStatus != appStatus || eTransType != newTransType || currentEEndDate != newEndDate) {
                    await bookingRef.update({
                      "status": appStatus,
                      "transaction_type": newTransType,
                      "contract_end_date": newEndDate
                    });
                  }
                }
              }
            }

            var ownedUnits = await FirebaseFirestore.instance.collection('ApartmentUnits').where('ownerUid', isEqualTo: uid).get();
            for (var unit in ownedUnits.docs) {
              var uData = unit.data();
              String bId = "OWNED_${unit.id}";
              var bRef = FirebaseFirestore.instance.collection("Secretary").doc(secId).collection("Members").doc(uid).collection("Bookings").doc(bId);

              var bExist = await bRef.get();

              String resUid = (uData['residentUid'] ?? "").toString().trim();

              bool isRented = uData['status'] == "Disewakan" || uData['status'] == "Dijual" || uData['status'] == "Reserved" || (uData['status'] == "Terisi" && resUid.isNotEmpty && resUid != uid);

              if (!bExist.exists) {
                await bRef.set({
                  "unit_no": uData["unit_no"] ?? "Unknown",
                  "tower": uData["tower"] ?? "Unknown",
                  "transaction_type": "Buy",
                  "duration": "Permanent (Ownership)",
                  "contract_end_date": "Permanent",
                  "is_rented_out": isRented,
                  "status": "Occupied",
                  "timestamp": FieldValue.serverTimestamp(),
                });
              } else {
                Map<String, dynamic>? bData = bExist.data() as Map<String, dynamic>?;
                if (bData?["is_rented_out"] != isRented || bData?["status"] != "Occupied") {
                  await bRef.update({
                    "is_rented_out": isRented,
                    "status": "Occupied",
                  });
                }
              }
            }
          } catch (syncError) {
            debugPrint("Sync Error: $syncError");
          }

          if (mounted) {
            bool shouldUpdate = false;
            if (secretaryId != secId) { secretaryId = secId; shouldUpdate = true; }
            if (isLandlord != landlordStatus) { isLandlord = landlordStatus; shouldUpdate = true; }
            if (isLoading) { isLoading = false; shouldUpdate = true; }

            var mData = memberDoc.data();
            if (mData != null) {
              String mName = mData['FullName'] ?? mData['fullName'] ?? mData['Name'] ?? mData['name'] ?? userName;
              String mPhone = (mData['Phone'] ?? mData['phone'] ?? mData['phoneNumber'] ?? mData['phone_number'] ?? userPhone).toString().trim();

              if (userName != mName || userPhone != mPhone) {
                userName = mName;
                userPhone = mPhone;
                shouldUpdate = true;
              }
            }

            if (shouldUpdate) setState(() {});
          }
          break;
        }
      }

      var pendingApps = await FirebaseFirestore.instance.collection("RentalApplications")
          .where("tenantUid", isEqualTo: uid)
          .where("status", isEqualTo: "Pending Initial Review")
          .get();

      if (pendingApps.docs.isNotEmpty) {
        _cachedOccupiedUnits = pendingApps.docs;
      } else {
        _cachedOccupiedUnits = [];
      }

      if (mounted) {
        setState(() {
          isLandlord = landlordStatus;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  void _checkProfileAndExecute(VoidCallback onSuccess) {
    if (userName.isEmpty || userName == "Resident" || userPhone.isEmpty) {
      _showIncompleteProfileDialog();
    } else {
      onSuccess();
    }
  }

  void _showIncompleteProfileDialog() {
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red),
              const SizedBox(width: 10),
              Text("Profile Incomplete", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            ],
          ),
          content: const Text("You must complete your personal data (Name and Phone Number) in your profile before requesting or linking a unit.", style: TextStyle(fontSize: 13, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(dialogContext);
                _pageController.animateToPage(3, duration: const Duration(milliseconds: 300), curve: Curves.easeInOutQuart);
              },
              child: const Text("Complete Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        )
    );
  }

  void _showLinkUnitBottomSheet() {
    String? selectedTower;
    String? selectedFloor;
    String? selectedUnit;
    String claimRole = 'Tenant';
    bool isSubmitting = false;

    String getFloor(String unitNo) {
      String numPart = unitNo.replaceAll(RegExp(r'[^0-9]'), '');
      if (numPart.length >= 3) {
        return numPart.substring(0, numPart.length - 2);
      }
      return '1';
    }

    _cachedUnitsFuture ??= FirebaseFirestore.instance.collection('ApartmentUnits').get();

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (BuildContext context) {
          return FutureBuilder<QuerySnapshot>(
              future: _cachedUnitsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator(color: Color(0xffF9A826)))
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox(
                      height: 300,
                      child: Center(child: Text("No units available.", style: TextStyle(color: Colors.grey)))
                  );
                }

                var docs = snapshot.data!.docs;

                return StatefulBuilder(
                    builder: (BuildContext context, StateSetter setModalState) {

                      Set<String> towers = {};
                      for (var doc in docs) {
                        var data = doc.data() as Map<String, dynamic>?;
                        if (data != null && data['tower'] != null) {
                          towers.add(data['tower'].toString());
                        }
                      }
                      List<String> towerList = towers.toList()..sort();

                      Set<int> floors = {};
                      List<String> availableUnits = [];

                      if (selectedTower != null) {
                        for (var doc in docs) {
                          var data = doc.data() as Map<String, dynamic>?;
                          if (data != null && data['tower'] == selectedTower && data['unit_no'] != null) {
                            String status = (data['status'] ?? '').toString();
                            String residentUid = (data['residentUid'] ?? '').toString();

                            if (status != 'Terisi' && status != 'Occupied' && status != 'Dijual' && status != 'Disewakan' && status != 'Reserved' && residentUid.isEmpty) {
                              String u = data['unit_no'].toString();
                              int f = int.tryParse(getFloor(u)) ?? 1;
                              floors.add(f);

                              if (selectedFloor != null && getFloor(u) == selectedFloor) {
                                availableUnits.add(u);
                              }
                            }
                          }
                        }
                        availableUnits.sort((a, b) {
                          int numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          int numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                          return numA.compareTo(numB);
                        });
                      }
                      List<int> floorList = floors.toList()..sort();

                      return Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                            top: 25, left: 25, right: 25
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Link Your Unit", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                              ],
                            ),
                            const Text("Submit a request to link your purchased or rented unit. Admin will verify your data.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
                            const SizedBox(height: 25),

                            const Text("I am the:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                    child: RadioListTile<String>(
                                      title: const Text("Owner", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      value: "Owner",
                                      activeColor: const Color(0xffF9A826),
                                      groupValue: claimRole,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      onChanged: (val) => setModalState(() => claimRole = val!),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                    child: RadioListTile<String>(
                                      title: const Text("Tenant", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                      value: "Tenant",
                                      activeColor: const Color(0xffF9A826),
                                      groupValue: claimRole,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      onChanged: (val) => setModalState(() => claimRole = val!),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            const Text("Select Tower:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: selectedTower,
                              hint: const Text("Choose Tower"),
                              icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.grey),
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                                  filled: true, fillColor: Colors.grey.shade50
                              ),
                              items: towerList.map((t) {
                                String displayT = t.toLowerCase().startsWith('tower') ? t : "Tower $t";
                                return DropdownMenuItem(value: t, child: Text(displayT, style: const TextStyle(fontWeight: FontWeight.bold)));
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() {
                                  selectedTower = val;
                                  selectedFloor = null;
                                  selectedUnit = null;
                                });
                              },
                            ),
                            const SizedBox(height: 20),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Select Floor:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: selectedFloor,
                                        hint: const Text("Floor"),
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                        decoration: InputDecoration(
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                                            filled: true, fillColor: Colors.grey.shade50
                                        ),
                                        items: floorList.map((f) => DropdownMenuItem(value: f.toString(), child: Text("Floor $f", style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                                        onChanged: selectedTower == null ? null : (val) {
                                          setModalState(() {
                                            selectedFloor = val;
                                            selectedUnit = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Select Unit:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: selectedUnit,
                                        hint: const Text("Choose Unit"),
                                        icon: const Icon(Icons.arrow_drop_down_circle, color: Colors.grey),
                                        decoration: InputDecoration(
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                                            filled: true, fillColor: Colors.grey.shade50
                                        ),
                                        items: availableUnits.map((u) => DropdownMenuItem(value: u, child: Text("Unit $u", style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                                        onChanged: selectedFloor == null ? null : (val) {
                                          setModalState(() => selectedUnit = val);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),

                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xffF9A826),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0
                                ),
                                onPressed: isSubmitting ? null : () async {
                                  if (selectedTower == null || selectedFloor == null || selectedUnit == null) {
                                    Fluttertoast.showToast(msg: "Please select Tower, Floor, and Unit", backgroundColor: Colors.red);
                                    return;
                                  }
                                  setModalState(() => isSubmitting = true);

                                  try {
                                    var existingReq = await FirebaseFirestore.instance.collection("RentalApplications")
                                        .where("tenantUid", isEqualTo: uid)
                                        .where("unit_no", isEqualTo: selectedUnit)
                                        .where("tower", isEqualTo: selectedTower)
                                        .get();

                                    bool hasActiveRequest = existingReq.docs.any((doc) {
                                      String status = (doc.data() as Map<String, dynamic>)['status']?.toString().trim() ?? '';
                                      return activeStatuses.contains(status);
                                    });

                                    if (hasActiveRequest) {
                                      Fluttertoast.showToast(msg: "Request already exists and is pending/active!", backgroundColor: Colors.orange);
                                      setModalState(() => isSubmitting = false);
                                      return;
                                    }

                                    String assignedDuration = claimRole == "Owner" ? "Permanent (Ownership)" : "1 Month";
                                    String assignedEndDate = claimRole == "Owner"
                                        ? "Permanent"
                                        : DateTime.now().add(const Duration(days: 30)).toIso8601String();

                                    var newAppRef = FirebaseFirestore.instance.collection("RentalApplications").doc();

                                    newAppRef.set({
                                      "tenantUid": uid,
                                      "tenantName": userName,
                                      "tower": selectedTower,
                                      "unit_no": selectedUnit,
                                      "transaction_type": claimRole == "Owner" ? "Buy (Offline Claim)" : "Rent (Offline Claim)",
                                      "duration": assignedDuration,
                                      "contract_end_date": assignedEndDate,
                                      "status": "Pending Initial Review",
                                      "timestamp": FieldValue.serverTimestamp(),
                                    });

                                    if (secretaryId != null) {
                                      FirebaseFirestore.instance.collection("Secretary").doc(secretaryId).collection("Members").doc(uid).collection("Bookings").doc(newAppRef.id).set({
                                        "unit_no": selectedUnit,
                                        "tower": selectedTower,
                                        "transaction_type": claimRole == "Owner" ? "Buy (Offline Claim)" : "Rent (Offline Claim)",
                                        "duration": assignedDuration,
                                        "contract_end_date": assignedEndDate,
                                        "is_rented_out": false,
                                        "status": "Pending Initial Review",
                                        "timestamp": FieldValue.serverTimestamp(),
                                      });
                                    }

                                    if (mounted) {
                                      Navigator.pop(context);
                                      _showActionDialog(
                                          "Request Submitted!",
                                          "Your request to link Unit $selectedUnit has been sent successfully. Please wait for management's approval."
                                      );
                                    }
                                  } catch (e) {
                                    Fluttertoast.showToast(msg: "Error: $e", backgroundColor: Colors.red);
                                    setModalState(() => isSubmitting = false);
                                  }
                                },
                                child: isSubmitting
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text("Submit Request", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            )
                          ],
                        ),
                      );
                    }
                );
              }
          );
        }
    );
  }

  void _showSetPriceDialog(String unitNo, String tower, String bookingId) {
    TextEditingController monthlyCtrl = TextEditingController();
    TextEditingController yearlyCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: const Text("Set Rental Price", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Enter the custom rental price for your unit before publishing it to the catalog.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: monthlyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: "Monthly Price", prefixText: "Rp", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: yearlyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: "Yearly Price", prefixText: "Rp", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826)),
                      onPressed: isSubmitting ? null : () async {
                        if (monthlyCtrl.text.isEmpty || yearlyCtrl.text.isEmpty) {
                          Fluttertoast.showToast(msg: "Please fill in all prices");
                          return;
                        }
                        if (secretaryId == null) return;

                        setDialogState(() { isSubmitting = true; });
                        try {
                          int customMonthly = int.parse(monthlyCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
                          int customYearly = int.parse(yearlyCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

                          var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();

                          if(unitQuery.docs.isNotEmpty) {
                            await unitQuery.docs.first.reference.update({
                              'status': 'Disewakan',
                              'custom_price_monthly': customMonthly,
                              'custom_price_yearly': customYearly,
                              'subleaser_uid': uid,
                              'residentName': ''
                            });

                            await FirebaseFirestore.instance.collection("Secretary").doc(secretaryId).collection("Members").doc(uid).collection("Bookings").doc(bookingId).update({
                              "is_rented_out": true
                            });

                            Navigator.pop(context);
                            _showActionDialog("Success", "Unit successfully published to rental catalog!");
                          }
                        } catch (e) {
                          setDialogState(() { isSubmitting = false; });
                          Navigator.pop(context);
                          _showActionDialog("Error", "Failed to publish unit: $e", isSuccess: false);
                        }
                      },
                      child: isSubmitting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Publish Unit", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  void _showSellPriceDialog(String unitNo, String tower, String bookingId) {
    TextEditingController sellCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  title: const Text("Set Selling Price", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Enter the selling price for your unit before publishing it to the catalog.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 15),
                      TextField(
                        controller: sellCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: "Total Selling Price", prefixText: "Rp ", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: isSubmitting ? null : () async {
                        if (sellCtrl.text.isEmpty) {
                          Fluttertoast.showToast(msg: "Please fill in the selling price");
                          return;
                        }
                        if (secretaryId == null) return;

                        setDialogState(() { isSubmitting = true; });
                        try {
                          int customSell = int.parse(sellCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

                          var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();

                          if(unitQuery.docs.isNotEmpty) {
                            await unitQuery.docs.first.reference.update({
                              'status': 'Dijual',
                              'custom_price_sell': customSell,
                              'subleaser_uid': uid,
                              'residentName': ''
                            });

                            await FirebaseFirestore.instance.collection("Secretary").doc(secretaryId).collection("Members").doc(uid).collection("Bookings").doc(bookingId).update({
                              "is_rented_out": true
                            });

                            Navigator.pop(context);
                            _showActionDialog("Success", "Unit successfully published for sale in catalog!");
                          }
                        } catch (e) {
                          setDialogState(() { isSubmitting = false; });
                          Navigator.pop(context);
                          _showActionDialog("Error", "Failed to list unit for sale: $e", isSuccess: false);
                        }
                      },
                      child: isSubmitting ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Publish for Sale", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    )
                  ],
                );
              }
          );
        }
    );
  }

  void _showWithdrawConfirmation(String unitNo, String tower, String bookingId) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Withdraw Listing?"),
          content: const Text("Are you sure you want to remove this unit from the catalog?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                _withdrawUnit(unitNo, tower, bookingId);
              },
              child: const Text("Yes, Withdraw", style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  Future<void> _withdrawUnit(String unitNo, String tower, String bookingId) async {
    try {
      if (secretaryId == null) return;
      var unitQuery = await FirebaseFirestore.instance.collection('ApartmentUnits').where('tower', isEqualTo: tower).where('unit_no', isEqualTo: unitNo).get();
      if(unitQuery.docs.isNotEmpty) {
        var unitData = unitQuery.docs.first.data();
        await unitQuery.docs.first.reference.update({
          'status': 'Terisi',
          'custom_price_monthly': FieldValue.delete(),
          'custom_price_yearly': FieldValue.delete(),
          'custom_price_sell': FieldValue.delete(),
          'subleaser_uid': FieldValue.delete(),
          'residentName': unitData['ownerName'] ?? "Owner"
        });

        await FirebaseFirestore.instance.collection("Secretary").doc(secretaryId).collection("Members").doc(uid).collection("Bookings").doc(bookingId).update({
          "is_rented_out": false
        });

        _showActionDialog("Success", "Unit successfully unlisted from catalog.");
      }
    } catch (e) {
      _showActionDialog("Error", "Failed to withdraw unit: $e", isSuccess: false);
    }
  }

  Future<void> _cancelRequest(String docId) async {
    try {
      FirebaseFirestore.instance.collection('RentalApplications').doc(docId).update({
        'status': 'Cancel',
        'last_actor': 'user',
        'last_action': 'cancel_new',
        'canceled_at': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp()
      });

      if (secretaryId != null) {
        FirebaseFirestore.instance.collection('Secretary').doc(secretaryId!).collection('Members').doc(uid).collection('Bookings').doc(docId).update({'status': 'Cancel'});
      }

      _showActionDialog("Request Cancelled", "Your request has been cancelled successfully.", isSuccess: false);
    } catch (e) {
      _showActionDialog("Error", "Failed to cancel request: $e", isSuccess: false);
    }
  }

  void _showCancelRequestDialog(String docId) {
    showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text("Cancel Request?"),
          content: const Text("Are you sure you want to cancel your pending request? This action cannot be undone."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Keep Request", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(dialogContext);
                _cancelRequest(docId);
              },
              child: const Text("Yes, Cancel", style: TextStyle(color: Colors.white)),
            )
          ],
        )
    );
  }

  void _showUnitSwitcherBottomSheet(List<QueryDocumentSnapshot> units, String currentId) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return Container(
            padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                      width: 40, height: 5,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Switch Unit", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 5),
                const Text("Select which apartment unit you want to manage.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 20),

                ...units.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String uNo = data['unit_no']?.toString() ?? "Unknown";
                  String twr = data['tower']?.toString() ?? "Tower";
                  bool isSelected = doc.id == currentId;

                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      if (!isSelected) {
                        setState(() {
                          _isSwitchingUnit = true;
                          _selectedUnitId = doc.id;
                        });

                        Future.delayed(const Duration(milliseconds: 800), () {
                          if(mounted) setState(() => _isSwitchingUnit = false);
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xffF9A826).withOpacity(0.08) : Colors.white,
                        border: Border.all(color: isSelected ? const Color(0xffF9A826) : Colors.grey.shade200, width: 1.5),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: isSelected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xffF9A826) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.apartment_rounded, color: isSelected ? Colors.white : Colors.grey.shade600, size: 22),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Unit $uNo", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isSelected ? const Color(0xffF9A826) : Colors.black87)),
                                const SizedBox(height: 3),
                                Text(twr, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Color(0xffF9A826), size: 24),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }
    );
  }

  Widget _buildMainHomeScaffold(Widget bodyContent) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,

        title: Transform.translate(
          offset: const Offset(-15.0, 0.0),
          child: SizedBox(
            width: 170,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(
                'assets/images/logo2trans.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        centerTitle: false,

        actions: [
          Container(
            margin: const EdgeInsets.only(right: 15, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xffF9A826).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.support_agent_rounded, color: Color(0xffF9A826)),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotPage()));
              },
            ),
          ),
        ],
      ),
      body: bodyContent,
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Color(0xffF9A826))))
        : StreamBuilder<QuerySnapshot>(
      stream: secretaryId != null
          ? FirebaseFirestore.instance.collection("Secretary").doc(secretaryId).collection("Members").doc(uid).collection("Bookings").snapshots()
          : FirebaseFirestore.instance.collection("RentalApplications").where("tenantUid", isEqualTo: uid).snapshots(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting && _cachedOccupiedUnits == null) {
          return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Color(0xffF9A826))));
        }

        bool hasActive = false;
        bool hasPending = false;
        QueryDocumentSnapshot? pendingDoc;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          var activeDocs = snapshot.data!.docs.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            String s = d['status'] ?? "";
            String tt = d['transaction_type'] ?? "";
            return s == "Occupied" || s == "Approved & Active" || s == "Owned" || s == "Requesting End Contract" || tt == "Lease Extension";
          }).toList();

          var pendingDocs = snapshot.data!.docs.where((doc) {
            var d = doc.data() as Map<String, dynamic>;
            String s = d['status'] ?? "";
            String tt = d['transaction_type'] ?? "";
            return tt != "Lease Extension" && (s == "Pending Initial Review" || s == "Awaiting Admin Payment Verification" || s == "Processing Move-in" || s.contains("Pending"));
          }).toList();

          if (activeDocs.isNotEmpty) {
            hasActive = true;
            _cachedOccupiedUnits = activeDocs;
          }

          if (pendingDocs.isNotEmpty) {
            pendingDocs.sort((a, b) {
              Timestamp tA = (a.data() as Map)['timestamp'] ?? Timestamp(0, 0);
              Timestamp tB = (b.data() as Map)['timestamp'] ?? Timestamp(0, 0);
              return tB.compareTo(tA);
            });
            hasPending = true;
            pendingDoc = pendingDocs.first;
          }
        }

        Widget currentBody;
        if (hasActive) {
          currentBody = HomePage(
            units: _cachedOccupiedUnits ?? [],
            selectedUnitId: _selectedUnitId,
            isSwitchingUnit: _isSwitchingUnit,
            userName: userName,
            uid: uid,
            lockoutDay: _lockoutDay,
            secretaryId: secretaryId,
            sharedRolesCache: _sharedRolesCache,
            formatCurrency: formatCurrency,

            greetingWidget: const TypewriterGreeting(),

            onSwitchUnitTap: _showUnitSwitcherBottomSheet,
            onSetPriceTap: _showSetPriceDialog,
            onSellPriceTap: _showSellPriceDialog,
            onWithdrawTap: _showWithdrawConfirmation,
            onLinkUnitTap: () => _checkProfileAndExecute(_showLinkUnitBottomSheet),
            onRentUnitTap: () => _checkProfileAndExecute(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const RentPage()))),
          );
        } else {
          currentBody = GuestPage(
            userName: userName,
            hasPending: hasPending,
            pendingDoc: pendingDoc,

            greetingWidget: const TypewriterGreeting(),

            onRentUnitTap: () => _checkProfileAndExecute(() => Navigator.push(context, MaterialPageRoute(builder: (_) => const RentPage()))),
            onLinkUnitTap: () => _checkProfileAndExecute(_showLinkUnitBottomSheet),
            onCancelRequestTap: _showCancelRequestDialog,
          );
        }

        return PopScope(
          canPop: false,
          onPopInvoked: (bool didPop) async {
            if (didPop) return;

            if (_selectedIndex != 0) {
              setState(() => _selectedIndex = 0);
              _pageController.jumpToPage(0);
            } else {
              final now = DateTime.now();
              if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
                _lastPressedAt = now;
                Fluttertoast.showToast(msg: "Press back again to minimize app", toastLength: Toast.LENGTH_SHORT);
              } else {
                await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
              }
            }
          },
          child: Scaffold(
            body: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() { _selectedIndex = index; });
              },
              children: [
                PrimaryScrollController(
                  controller: _homeScrollController,
                  child: _buildMainHomeScaffold(currentBody),
                ),
                PrimaryScrollController(
                  controller: _unitsScrollController,
                  child: const MyApartmentPage(),
                ),
                PrimaryScrollController(
                  controller: _inboxScrollController,
                  child: const NotificationsPage(),
                ),
                PrimaryScrollController(
                  controller: _profileScrollController,
                  child: const profile_page(),
                ),
              ],
            ),
            bottomNavigationBar: CustomBottomNavbar(
              selectedIndex: _selectedIndex,
              unreadNotifCount: _unreadNotifCount,
              onItemTapped: (index) {
                if (_selectedIndex == index) {
                  if (index == 0 && _homeScrollController.hasClients) {
                    _homeScrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
                  } else if (index == 1 && _unitsScrollController.hasClients) {
                    _unitsScrollController.jumpTo(0);
                  } else if (index == 2 && _inboxScrollController.hasClients) {
                    _inboxScrollController.jumpTo(0);
                  } else if (index == 3 && _profileScrollController.hasClients) {
                    _profileScrollController.jumpTo(0);
                  }
                } else {
                  setState(() => _selectedIndex = index);
                  _pageController.jumpToPage(index);
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class TypewriterGreeting extends StatefulWidget {
  const TypewriterGreeting({Key? key}) : super(key: key);

  @override
  State<TypewriterGreeting> createState() => _TypewriterGreetingState();
}

class _TypewriterGreetingState extends State<TypewriterGreeting> {
  Timer? _timer;
  Timer? _cursorTimer;
  String _displayedText = "";
  int _messageIndex = 0;
  int _charIndex = 0;
  bool _isDeleting = false;
  bool _showCursor = true;
  List<String> _greetings = [];

  @override
  void initState() {
    super.initState();
    _updateGreetingsBasedOnTime();
    _startTyping();

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _showCursor = !_showCursor;
        });
      }
    });
  }

  void _updateGreetingsBasedOnTime() {
    int hour = DateTime.now().hour;
    if (hour < 12) {
      _greetings = ["Good Morning,", "おはよう,", "Bonjour,", "早上好,", "Selamat Pagi,", "좋은 아침,"];
    } else if (hour < 17) {
      _greetings = ["Good Afternoon,", "こんにちは,", "Bonne Après-midi,", "下午好,", "Selamat Siang,", "좋은 오후,"];
    } else {
      _greetings = ["Good Evening,", "こんばんは,", "Bonsoir,", "晚上好,", "Selamat Malam,", "좋은 저녁,"];
    }
  }

  void _startTyping() {
    int speed = _isDeleting ? 50 : 100;

    _timer = Timer(Duration(milliseconds: speed), () {
      if (!mounted) return;

      String currentMessage = _greetings[_messageIndex];

      if (!_isDeleting) {
        if (_charIndex < currentMessage.length) {
          setState(() {
            _charIndex++;
            _displayedText = currentMessage.substring(0, _charIndex);
          });
          _startTyping();
        } else {
          _timer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isDeleting = true;
              });
              _startTyping();
            }
          });
        }
      } else {
        if (_charIndex > 0) {
          setState(() {
            _charIndex--;
            _displayedText = currentMessage.substring(0, _charIndex);
          });
          _startTyping();
        } else {
          _isDeleting = false;
          _messageIndex = (_messageIndex + 1) % _greetings.length;

          if (_messageIndex == 0) {
            _updateGreetingsBasedOnTime();
          }

          _timer = Timer(const Duration(milliseconds: 500), () {
            if (mounted) _startTyping();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: _displayedText),
          TextSpan(
            text: "|",
            style: TextStyle(color: _showCursor ? Colors.black87 : Colors.transparent),
          ),
        ],
      ),
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 0.3),
    );
  }
}
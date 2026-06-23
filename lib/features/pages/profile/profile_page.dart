import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../unit_management/unit_access_page.dart';
import 'edit_profile_page.dart';
import '../unit_management/owner_dashboard_page.dart';
import '../unit_management/join_unit_page.dart';
import '../../Auth/login_page.dart';

class profile_page extends StatefulWidget {
  const profile_page({super.key});

  @override
  State<profile_page> createState() => _profile_pageState();
}

class _profile_pageState extends State<profile_page> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final Color _primaryColor = const Color(0xffF9A826);

  String name = "";
  String email = "";
  String phone = "";
  String photoUrl = "";

  String activeUnitNo = "Loading...";
  String activeTower = "Loading...";
  bool isPrimaryResident = true;
  bool isLandlord = false;

  String? secretaryId;
  bool isLoading = true;

  bool _notifications = true;
  bool _systemAlerts = true;
  bool _privacyMode = false;

  @override
  void initState() {
    super.initState();
    _loadTogglePreferences();
    _fetchProfileAndUnitData();
  }

  Future<void> _loadTogglePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _privacyMode = prefs.getBool('privacyMode') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
      _systemAlerts = prefs.getBool('systemAlerts') ?? true;
    });
  }

  Future<void> _saveTogglePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _updateFirebasePreference(String field, bool value) async {
    try {
      await FirebaseFirestore.instance.collection("Users").doc(_uid).set({
        field: value,
      }, SetOptions(merge: true));

      if (secretaryId != null) {
        await FirebaseFirestore.instance
            .collection("Secretary")
            .doc(secretaryId)
            .collection("Members")
            .doc(_uid)
            .set({
          field: value,
        }, SetOptions(merge: true));
      }

      Fluttertoast.showToast(
        msg: "Preferences updated on server!",
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 12.0,
      );
    } catch (e) {
      debugPrint("Gagal update preference ke Firebase: $e");
    }
  }

  Future<void> _fetchProfileAndUnitData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      email = currentUser.email ?? "";

      final querySnapshot = await FirebaseFirestore.instance.collection("Secretary").get();
      bool isDataFound = false;

      for (var doc in querySnapshot.docs) {
        final memberDoc = await FirebaseFirestore.instance
            .collection("Secretary")
            .doc(doc.id)
            .collection("Members")
            .doc(_uid)
            .get();

        if (memberDoc.exists && memberDoc.data() != null) {
          secretaryId = doc.id;
          name = memberDoc.data()!["Name"] ?? "";
          String dbEmail = memberDoc.data()!["Email"] ?? "";
          email = dbEmail.isNotEmpty ? dbEmail : email;
          phone = memberDoc.data()!["Phone"] ?? "";
          photoUrl = memberDoc.data()!["PhotoUrl"] ?? "";

          if (mounted) {
            setState(() {
              if (memberDoc.data()!.containsKey('privacyMode')) _privacyMode = memberDoc.data()!['privacyMode'];
              // PERBAIKAN: Key database server diganti menjadi 'notifications'
              if (memberDoc.data()!.containsKey('notifications')) _notifications = memberDoc.data()!['notifications'];
              if (memberDoc.data()!.containsKey('systemAlerts')) _systemAlerts = memberDoc.data()!['systemAlerts'];
            });
          }

          isDataFound = true;
          break;
        }
      }

      if (!isDataFound && querySnapshot.docs.isNotEmpty) {
        secretaryId = querySnapshot.docs.first.id;
      }

      var ownerCheck = await FirebaseFirestore.instance.collection('ApartmentUnits').where('ownerUid', isEqualTo: _uid).get();
      var subleaseCheck = await FirebaseFirestore.instance.collection('ApartmentUnits').where('subleaser_uid', isEqualTo: _uid).get();
      var appCheck = await FirebaseFirestore.instance.collection('RentalApplications').where('ownerUid', isEqualTo: _uid).get();

      bool landlordStatus = ownerCheck.docs.isNotEmpty || subleaseCheck.docs.isNotEmpty || appCheck.docs.isNotEmpty;

      var unitQuery = await FirebaseFirestore.instance.collection("ApartmentUnits").where("residentUid", isEqualTo: _uid).get();
      if (unitQuery.docs.isNotEmpty) {
        var unitData = unitQuery.docs.first.data();
        activeUnitNo = unitData['unit_no'] ?? "Unknown";
        activeTower = unitData['tower'] ?? "Main Tower";
        isPrimaryResident = (unitData['ownerUid'] == _uid) || (unitData['tenantUid'] == _uid);
      } else {
        if (ownerCheck.docs.isNotEmpty) {
          var unitData = ownerCheck.docs.first.data();
          activeUnitNo = unitData['unit_no'] ?? "Unknown";
          activeTower = unitData['tower'] ?? "Main Tower";
          isPrimaryResident = true;
        } else {
          activeUnitNo = "No Unit";
          activeTower = "Not Connected";
        }
      }

      if (mounted) {
        setState(() {
          isLandlord = landlordStatus;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _navToEditProfile() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfilePage(initialName: name, initialEmail: email, initialPhone: phone, secretaryId: secretaryId, uid: _uid)));
    if (result != null && result is Map) {
      setState(() { name = result['name']; phone = result['phone']; });
    }
  }

  void _logout() async {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Log Out", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to log out of your account?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, elevation: 0),
                onPressed: () async {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(child: CircularProgressIndicator(color: _primaryColor)),
                  );

                  await FirebaseAuth.instance.signOut();
                  await Future.delayed(const Duration(milliseconds: 400));

                  if (!mounted) return;

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const login_page()),
                        (Route<dynamic> route) => false,
                  );
                },
                child: Text("Log Out", style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold))
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isProfileIncomplete = name.isEmpty || phone.isEmpty;

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xffF8F9FA), elevation: 0, toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("My Profile", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22)),
            SizedBox(height: 4),
            Text("Manage your account and preferences", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isProfileIncomplete)
              Container(
                margin: const EdgeInsets.only(bottom: 20), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                child: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red.shade700), const SizedBox(width: 10), const Expanded(child: Text("Your profile is incomplete. Please tap the edit icon to update.", style: TextStyle(color: Colors.red, fontSize: 13)))]),
              ),

            _buildAccountInfoCard(),
            const SizedBox(height: 30),

            _buildSectionHeader("Apartment & Units"),
            _buildSettingsGroup(
                children: [
                  _buildMenuItem(
                      icon: Icons.people_outline, title: "Unit Access", subtitle: "Manage who can access your unit",
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UnitAccessPage(unitNo: activeUnitNo, isPrimaryResident: isPrimaryResident)))
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                      icon: Icons.vpn_key_outlined, title: "Join Unit", subtitle: "Enter invitation code to join a unit", isHighlight: false,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const JoinUnitPage()))
                  ),

                  if (isLandlord) ...[
                    _buildDivider(),
                    _buildMenuItem(icon: Icons.dashboard_customize, title: "Landlord Dashboard", subtitle: "Manage your tenants and rental properties", onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const OwnerDashboardPage())); }),
                  ],
                ]
            ),
            const SizedBox(height: 30),

            _buildSectionHeader("Account & Security"),
            _buildSettingsGroup(
                children: [
                  _buildMenuItem(
                      icon: Icons.lock_outline,
                      title: "Change Password",
                      subtitle: "Update your login password",
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            title: const Text("Change Password", style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text("We will send a password reset link to your registered email. Do you want to proceed?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffF9A826)),
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  try {
                                    String userEmail = FirebaseAuth.instance.currentUser!.email!;
                                    await FirebaseAuth.instance.sendPasswordResetEmail(email: userEmail);
                                    Fluttertoast.showToast(
                                      msg: "Password reset link sent to your email!",
                                      backgroundColor: Colors.green,
                                      textColor: Colors.white,
                                    );
                                  } catch (e) {
                                    Fluttertoast.showToast(
                                      msg: "Error: ${e.toString()}",
                                      backgroundColor: Colors.red,
                                      textColor: Colors.white,
                                    );
                                  }
                                },
                                child: const Text("Send Link", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              )
                            ],
                          ),
                        );
                      }
                  ),
                  _buildDivider(),
                  _buildToggleItem(
                      icon: Icons.privacy_tip_outlined,
                      title: "Privacy Mode",
                      subtitle: "Hide contact details from regular members",
                      value: _privacyMode,
                      onChanged: (val) {
                        setState(() => _privacyMode = val);
                        _saveTogglePreference('privacyMode', val);
                        _updateFirebasePreference('privacyMode', val);
                      }
                  )
                ]
            ),
            const SizedBox(height: 30),

            _buildSectionHeader("Notifications"),
            _buildSettingsGroup(
                children: [
                  _buildToggleItem(
                      icon: Icons.notifications_active_outlined,
                      title: "Notifications",
                      subtitle: "Receive general app activity alerts",
                      value: _notifications,
                      onChanged: (val) {
                        setState(() => _notifications = val);
                        _saveTogglePreference('notifications', val);
                        _updateFirebasePreference('notifications', val);
                      }
                  ),
                  _buildDivider(),
                  _buildToggleItem(
                      icon: Icons.campaign_outlined,
                      title: "System Alerts",
                      subtitle: "Important updates and announcements",
                      value: _systemAlerts,
                      onChanged: (val) {
                        setState(() => _systemAlerts = val);
                        _saveTogglePreference('systemAlerts', val);
                        _updateFirebasePreference('systemAlerts', val);
                      }
                  )
                ]
            ),
            const SizedBox(height: 30),

            _buildSectionHeader("App Appearance"),
            _buildSettingsGroup(
                children: [
                  _buildMenuItem(
                      icon: Icons.dark_mode_outlined,
                      title: "Theme Mode",
                      subtitle: "Light Mode",
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Fluttertoast.showToast(msg: "Dark Mode is coming soon in the next update!", backgroundColor: Colors.black87, textColor: Colors.white);
                      }
                  ),
                  _buildDivider(),
                  _buildMenuItem(
                      icon: Icons.language_outlined,
                      title: "Language",
                      subtitle: "English",
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Fluttertoast.showToast(msg: "Language settings will be available soon!", backgroundColor: Colors.black87, textColor: Colors.white);
                      }
                  )
                ]
            ),
            const SizedBox(height: 30),

            SizedBox(
                width: double.infinity, height: 55,
                child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade200, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        backgroundColor: Colors.white
                    ),
                    icon: Icon(Icons.logout, color: Colors.red.shade600, size: 20),
                    label: Text("Log Out", style: TextStyle(color: Colors.red.shade600, fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: _logout
                )
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountInfoCard() {
    String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))], border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Container(width: 70, height: 70, decoration: BoxDecoration(color: _primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]), alignment: Alignment.center, child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.isEmpty ? "Unknown User" : name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(email, style: TextStyle(fontSize: 14, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(phone.isEmpty ? "No phone number" : phone, style: TextStyle(fontSize: 14, color: Colors.grey.shade600))])),
          IconButton(icon: const Icon(Icons.edit, color: Colors.black54), onPressed: _navToEditProfile)
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) { return Padding(padding: const EdgeInsets.only(left: 10, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2))); }
  Widget _buildSettingsGroup({required List<Widget> children}) { return Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)), child: Column(children: children)); }
  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, bool isHighlight = false, Widget? trailing, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isHighlight ? _primaryColor.withOpacity(0.2) : _primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: _primaryColor, size: 22)),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isHighlight ? _primaryColor : Colors.black87)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
              trailing ?? const Icon(Icons.chevron_right, color: Colors.grey, size: 20)
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildToggleItem({required IconData icon, required String title, required String subtitle, required bool value, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: _primaryColor, size: 22)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))])),
          Switch(value: value, activeColor: _primaryColor, onChanged: onChanged)
        ],
      ),
    );
  }
  Widget _buildDivider() { return Divider(height: 1, thickness: 1, color: Colors.grey.shade100, indent: 70, endIndent: 20); }
}
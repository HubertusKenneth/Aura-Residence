import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:my_apart/features/pages/home/main_layout.dart';
import 'package:my_apart/features/Auth/login_page.dart';

class page1 extends StatefulWidget {
  const page1({Key? key}) : super(key: key);

  @override
  State<page1> createState() => _page1State();
}

class _page1State extends State<page1> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkUser();
    });
  }

  Future<void> checkUser() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const login_page(),
          ),
        );
        return;
      }

      final String uid = user.uid;

      // ==========================
      // Cek apakah Member (User)
      // ==========================
      final secretaries = await FirebaseFirestore.instance
          .collection('Secretary')
          .get();

      for (final sec in secretaries.docs) {
        final memberDoc = await FirebaseFirestore.instance
            .collection('Secretary')
            .doc(sec.id)
            .collection('Members')
            .doc(uid)
            .get();

        if (memberDoc.exists) {
          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const MainLayout(),
            ),
          );
          return;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User data not found. Please log in again."),
        ),
      );

      await FirebaseAuth.instance.signOut();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const login_page(),
        ),
      );
    } catch (e) {
      debugPrint("CHECK USER ERROR: $e");

      if (!mounted) return;

      // Jika ada error sistem -> Langsung ke User Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const login_page(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Color(0xffF9A826)),
      ),
    );
  }
}
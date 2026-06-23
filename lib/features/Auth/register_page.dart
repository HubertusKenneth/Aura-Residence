import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_apart/features/pages/home/main_layout.dart';

class register_page extends StatefulWidget {
  const register_page({Key? key}) : super(key: key);

  @override
  State<register_page> createState() => _register_pageState();
}

class _register_pageState extends State<register_page> {
  final form_key = GlobalKey<FormState>();

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  TextEditingController confirmPassController = TextEditingController();

  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("User Sign Up", style: TextStyle(color: Colors.deepOrangeAccent)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.deepOrangeAccent),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: form_key,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Create an Account",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 30),

                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    filled: true,
                    labelText: "Full Name",
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    fillColor: Colors.grey.shade100,
                  ),
                  validator: (value) => value!.isEmpty ? "Name cannot be empty" : null,
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    filled: true,
                    labelText: "Email Address",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    fillColor: Colors.grey.shade100,
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return "Email cannot be empty";
                    if (!value.contains('@')) return "Enter a valid email";
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: passController,
                  obscureText: true,
                  decoration: InputDecoration(
                    filled: true,
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    fillColor: Colors.grey.shade100,
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return "Password cannot be empty";
                    if (value.length < 8) return "Password length must be 8 or more";
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                TextFormField(
                  controller: confirmPassController,
                  obscureText: true,
                  decoration: InputDecoration(
                    filled: true,
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    fillColor: Colors.grey.shade100,
                  ),
                  validator: (value) {
                    if (value!.isEmpty) return "Please confirm your password";
                    if (value != passController.text) return "Passwords do not match";
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrangeAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                    onPressed: isLoading ? null : () async {
                      if (form_key.currentState!.validate()) {
                        setState(() { isLoading = true; });
                        try {
                          UserCredential userCredential = await FirebaseAuth.instance
                              .createUserWithEmailAndPassword(
                              email: emailController.text.trim(),
                              password: passController.text.trim());

                          await userCredential.user!.updateDisplayName(nameController.text.trim());

                          final secSnapshot = await FirebaseFirestore.instance.collection("Secretary").get();
                          if (secSnapshot.docs.isNotEmpty) {
                            String secretaryId = secSnapshot.docs.first.id;

                            await FirebaseFirestore.instance
                                .collection("Secretary")
                                .doc(secretaryId)
                                .collection("Members")
                                .doc(userCredential.user!.uid)
                                .set({
                              'Name': nameController.text.trim(),
                              'FullName': nameController.text.trim(),
                              'Email': emailController.text.trim(),
                              'Password': passController.text.trim(),
                              'Phone': '',
                              'Occupation': '',
                              'groups': [],
                              'userUid': userCredential.user!.uid,
                              'AdminUid': secretaryId,
                            });
                          }

                          await FirebaseFirestore.instance
                              .collection("Users")
                              .doc(userCredential.user!.uid)
                              .set({
                            'Name': nameController.text.trim(),
                            'FullName': nameController.text.trim(),
                            'Email': emailController.text.trim(),
                            'Phone': '',
                            'Occupation': '',
                            'userUid': userCredential.user!.uid,
                            'role': 'Tenant',
                          });

                          Fluttertoast.showToast(msg: "Registration Successful");

                          if(mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => MainLayout()),
                                  (Route<dynamic> route) => false,
                            );
                          }

                        } on FirebaseAuthException catch (e) {
                          Fluttertoast.showToast(msg: e.message ?? "Registration Failed", backgroundColor: Colors.red);
                        } finally {
                          if (mounted) setState(() { isLoading = false; });
                        }
                      }
                    },
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Register", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
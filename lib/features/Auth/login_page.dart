import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_apart/features/Auth/forget_password_page.dart';
import 'package:my_apart/features/pages/home/main_layout.dart';
import 'package:my_apart/features/Auth/register_page.dart';

class login_page extends StatefulWidget {
  const login_page({Key? key}) : super(key: key);

  @override
  State<login_page> createState() => _login_pageState();
}

class _login_pageState extends State<login_page> {
  final form_key = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();

  String? emailError;
  String? passwordError;
  bool isLoading = false;

  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    if (form_key.currentState!.validate()) {
      setState(() {
        isLoading = true;
        emailError = null;
        passwordError = null;
      });

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passController.text.trim(),
        );

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout()),
                (Route<dynamic> route) => false,
          );
          Fluttertoast.showToast(msg: "Login Successful");
        }
      } on FirebaseAuthException catch (e) {
        setState(() {
          if (e.code == 'user-not-found') {
            emailError = "Email is not registered";
          } else if (e.code == 'wrong-password') {
            passwordError = "Wrong password";
          } else if (e.code == 'invalid-email') {
            emailError = "Invalid email format";
          } else if (e.code == 'invalid-credential') {
            emailError = "Invalid email or password";
            passwordError = "Invalid email or password";
          } else {
            Fluttertoast.showToast(msg: e.message ?? "Login failed");
          }
        });
      } catch (e) {
        Fluttertoast.showToast(msg: "An error occurred. Please try again.");
      } finally {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        // PERBAIKAN: Stack dan Tombol Back dihapus, karena ini adalah rute awal (root)
        body: Form(
          key: form_key,
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset("assets/images/login.png", fit: BoxFit.cover),
                const SizedBox(
                  height: 30,
                ),
                const Text(
                  "Good to see you again!",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                const SizedBox(
                  height: 10.0,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 40.0, horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                          controller: emailController,
                          onChanged: (value) {
                            if (emailError != null) {
                              setState(() {
                                emailError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                              label: const Text("Enter Email"),
                              errorText: emailError,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: Color(0xffF9A826),
                              ),
                              border: const OutlineInputBorder(),
                              labelStyle: const TextStyle(color: Colors.blueGrey),
                              focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                      width: 3.0, color: Colors.blueGrey))),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Email cannot be empty";
                            }
                            return null;
                          }),
                      const SizedBox(height: 10.0, width: 10.0),
                      TextFormField(
                          controller: passController,
                          obscureText: _obscurePassword,
                          onChanged: (value) {
                            if (passwordError != null) {
                              setState(() {
                                passwordError = null;
                              });
                            }
                          },
                          decoration: InputDecoration(
                              label: const Text("Enter Password"),
                              errorText: passwordError,
                              prefixIcon: const Icon(
                                Icons.fingerprint_outlined,
                                color: Color(0xffF9A826),
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              border: const OutlineInputBorder(),
                              labelStyle: const TextStyle(color: Colors.blueGrey),
                              focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(
                                      width: 3.0, color: Colors.blueGrey))),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Password cannot be empty";
                            } else if (value.length < 8) {
                              return "Password length must be 8 or more";
                            }
                            return null;
                          }),
                      const SizedBox(
                        height: 30.0,
                      ),
                      TextButton(
                          onPressed: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                    const forgot_password_page()));
                          },
                          child: const Text('Forgot Password?')),
                      SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 241, 175, 68),
                            ),
                            onPressed: isLoading ? null : _handleLogin,
                            child: isLoading
                                ? const SizedBox(
                                height: 25,
                                width: 25,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                            )
                                : const Text(
                              'Login',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold),
                            ),
                          )),

                      const SizedBox(height: 20.0),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: Colors.blueGrey, fontSize: 15),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const register_page(),
                                ),
                              );
                            },
                            child: const Text(
                              'Register here',
                              style: TextStyle(
                                color: Color(0xffF9A826),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        )
    );
  }
}
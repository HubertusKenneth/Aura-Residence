import 'package:email_auth/email_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:my_apart/features/Auth/verify_otp_page.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final TextEditingController _emailcontroller = TextEditingController();

  Future<void> sendOtp() async {
    EmailAuth emailAuth = EmailAuth(sessionName: "My Apart");
    bool result = await emailAuth.sendOtp(
        recipientMail: _emailcontroller.value.text, otpLength: 6);

    if (result) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: ((context) => VerifyOtpPage(email: _emailcontroller.text))));
    } else {
      Fluttertoast.showToast(msg: "Please Resend OTP");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: Form(
          child: SingleChildScrollView(
            child: Container(
              child: Column(
                children: [
                  Image.asset("assets/images/Email1.png", fit: BoxFit.cover),
                  const SizedBox(height: 30),
                  const Text(
                    "Good to see you again!",
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 40.0, horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                            controller: _emailcontroller,
                            decoration: const InputDecoration(
                                label: Text("Enter Email"),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Color(0xffF9A826),
                                ),
                                labelStyle: TextStyle(color: Colors.blueGrey),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                        width: 3.0, color: Colors.blueGrey))),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Email cannot be empty";
                              }
                              return null;
                            }),
                        const SizedBox(height: 30.0),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                                onPressed: () => sendOtp(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                  const Color.fromARGB(255, 241, 175, 68),
                                ),
                                child: const Text(
                                  'Send OTP',
                                  style: TextStyle(
                                      color: Colors.blueGrey,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold),
                                ))),
                        const SizedBox(height: 30.0),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ));
  }
}
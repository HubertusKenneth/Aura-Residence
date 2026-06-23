import 'package:flutter/material.dart';
import 'package:email_auth/email_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:fluttertoast/fluttertoast.dart';

// DIUBAH MENJADI STATEFUL WIDGET
class VerifyOtpPage extends StatefulWidget {
  final String email;

  const VerifyOtpPage({Key? key, required this.email}) : super(key: key);

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  EmailAuth emailAuth = EmailAuth(sessionName: "My Apart");
  final OtpFieldController _otpcontroller = OtpFieldController();

  String _enteredOTP = "";

  void verifyOTP() async {
    if (_enteredOTP.length < 6) {
      Fluttertoast.showToast(msg: "Please enter 6 digit OTP");
      return;
    }

    // Menggunakan nilai _enteredOTP, BUKAN _otpcontroller.toString()
    var res = emailAuth.validateOtp(
        recipientMail: widget.email,
        userOtp: _enteredOTP);

    if (res) {
      Fluttertoast.showToast(msg: "OTP Verified Successfully!");
      // TODO: Tambahkan Navigasi ke halaman selanjutnya di sini
      // Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HalamanSelanjutnya()));
    } else {
      Fluttertoast.showToast(msg: "Invalid OTP");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // DIBUNGKUS DENGAN SCROLL VIEW AGAR TIDAK OVERFLOW SAAT KEYBOARD MUNCUL
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 80.0), // Margin atas
              Text("CO",
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 80.0,
                      color: const Color(0xffF9A826))),
              Text("DE",
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.bold,
                      fontSize: 80.0,
                      color: const Color(0xffF9A826))),
              Text(
                "VERIFICATION",
                style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                    fontSize: 16.0),
              ),
              const SizedBox(height: 40.0),

              // PERBAIKAN: Menggunakan variabel email dari konstruktor
              Text(
                "Enter the verification code sent at\n${widget.email}",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20.0, color: Colors.grey),
              ),
              const SizedBox(height: 20.0),

              SizedBox(
                height: 100,
                // PERBAIKAN PADA OTPTextField AGAR RESPONSIVE
                child: OTPTextField(
                  controller: _otpcontroller,
                  length: 6,
                  width: MediaQuery.of(context).size.width, // Lebar dinamis
                  fieldWidth: 40,
                  style: const TextStyle(fontSize: 17, color: Colors.black),
                  textFieldAlignment: MainAxisAlignment.spaceAround,
                  fieldStyle: FieldStyle.box,
                  otpFieldStyle: OtpFieldStyle(backgroundColor: Colors.black12),
                  onChanged: (pin) {
                    _enteredOTP = pin; // Menyimpan OTP saat diketik
                  },
                  onCompleted: (pin) {
                    _enteredOTP = pin;
                    // verifyOTP(); // (Opsional) Buka komen ini jika ingin otomatis lanjut saat 6 digit terisi penuh
                  },
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  // PERBAIKAN: Menyambungkan fungsi verifyOTP ke tombol
                  onPressed: verifyOTP,
                  style: ElevatedButton.styleFrom(
                    // PERBAIKAN: primary menjadi backgroundColor
                    backgroundColor: const Color.fromARGB(255, 241, 175, 68),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    "Next",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.0,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 160.0)
            ],
          ),
        ),
      ),
    );
  }
}
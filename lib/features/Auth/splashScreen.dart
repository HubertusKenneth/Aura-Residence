import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_apart/features/Auth/email_verification_page.dart';
import 'package:my_apart/features/Auth/verify_otp_page.dart';
import 'package:my_apart/features/Auth/page1.dart';
import 'package:my_apart/features/Auth/login_page.dart';


class SplashScreen extends StatefulWidget
{
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
        super.initState();
        Timer(Duration(seconds: 1), ()
        {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: ((context) => page1() )));
        });

  }
  @override
  Widget build(BuildContext context) {
     return Scaffold(
        body:  Center(
          child: Container(
            color:  Color(0xffffff),
            height: 300,
            width : 300,
            child: Image(
              image: AssetImage('assets/images/s1.png'),
            ),
          ),
        ),

     );
  }

}


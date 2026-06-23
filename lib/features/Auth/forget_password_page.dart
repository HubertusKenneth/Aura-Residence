import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:my_apart/features/Auth/login_page.dart';


class forgot_password_page extends StatefulWidget {
  const forgot_password_page({Key? key}) : super(key: key);

  @override
  State<forgot_password_page> createState() => _forgot_password_pageState();
}

class _forgot_password_pageState extends State<forgot_password_page> {
  final emailController = TextEditingController();
  final form_key = GlobalKey<FormState>();

  Future passwordReset() async
  {

      
      await FirebaseAuth.instance.sendPasswordResetEmail(
          email: emailController.text.trim()).then((value) {
        showDialog(context: context,
            builder: (context) {
              return AlertDialog(
                  content: Text("Password reset link sent to your email, check")
              );
            }
        );
      }).catchError((e) {
        print(e);
        showDialog(context: context,
            builder: (context) {
              return AlertDialog(
                  content: Text(e.message.toString())
              );
            }
        );
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0,title: Text("Reset Password",style: TextStyle(color: Colors.white),),
        leading: IconButton(icon: Icon(Icons.arrow_back,color: Colors.white,),onPressed: (){Navigator.push(context, MaterialPageRoute(builder: (context) => login_page()));},),
      ),
      body: Form
        (
          key: form_key,
          child:Column(
            children: [
              SizedBox(height: 10,),
              Padding(padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text("Enter your email and after you will ger password reset link",style: TextStyle(color: Colors.deepOrangeAccent,
                    fontWeight:FontWeight.bold ,fontSize: 20),),
              ),

              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.symmetric(horizontal: 30),
                child:TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                        filled: true,
                        hintText: "Email",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        fillColor: Colors.grey.shade100
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return "Email cannot be empty";
                      }
                    }
                ),
              ),
              SizedBox(height: 20,),
              MaterialButton(onPressed: (){
                if(form_key.currentState!.validate())
                {
                  passwordReset();
                }
              },
                child: Text("Reset Password"),
                color: Colors.lightBlue,
              ),

            ],

          )
      )

    );
  }
}

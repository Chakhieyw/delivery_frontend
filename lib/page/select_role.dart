import 'package:flutter/material.dart';
import 'package:delivery_frontend/page/login_user.dart';
class SelectRolePage extends StatelessWidget {
  const SelectRolePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: Column(
        children: [
          // Header
          Container(
            height: 80,
            width: double.infinity,
            color: Colors.green,
            alignment: Alignment.center,
            child: const Text(
              "Delivery AppT&K",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 40),

          const Text(
            "โปรดเลือกประเภท",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 30),

          // ปุ่ม User
          SizedBox(
            width: 200,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginUserPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text("User", style: TextStyle(color: Colors.white)),
            ),
          ),

          const SizedBox(height: 20),

          // ปุ่ม Rider
          // SizedBox(
          //   width: 200,
          //   height: 50,
          //   child: ElevatedButton(
          //     // onPressed: () {
          //     //   Navigator.push(
          //     //     context,
          //     //     MaterialPageRoute(builder: (context) => const ),
          //     //   );
          //     // },
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.green,
          //       shape: RoundedRectangleBorder(
          //         borderRadius: BorderRadius.circular(30),
          //       ),
          //     ),
          //     child: const Text("Rider", style: TextStyle(color: Colors.white)),
          //   ),
          // ),

          const Spacer(),

          // Footer
          Container(
            height: 40,
            width: double.infinity,
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}

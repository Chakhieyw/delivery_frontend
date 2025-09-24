import 'package:delivery_frontend/page/registeruser.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final _phoneCtl = TextEditingController();
  final _passwordCtl = TextEditingController();

  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      final email = "${_phoneCtl.text}@delivery.com"; // แปลงเบอร์ → email
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordCtl.text,
      );

      // ถ้า login สำเร็จ
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("เข้าสู่ระบบสำเร็จ ✅")));

      // TODO: ไปหน้า Dashboard
      // Navigator.pushReplacement(context,
      //   MaterialPageRoute(builder: (_) => const UserDashboardPage()));
    } on FirebaseAuthException catch (e) {
      String message = "เข้าสู่ระบบไม่สำเร็จ";
      if (e.code == 'user-not-found') {
        message = "ไม่พบบัญชีผู้ใช้";
      } else if (e.code == 'wrong-password') {
        message = "รหัสผ่านไม่ถูกต้อง";
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _loading = false);
  }

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

          const SizedBox(height: 30),

          const Text(
            "เข้าสู่ระบบ",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 30),

          // เบอร์โทรศัพท์
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: TextField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone, color: Colors.green),
                hintText: "เบอร์โทรศัพท์",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // รหัสผ่าน
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: TextField(
              controller: _passwordCtl,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock, color: Colors.green),
                hintText: "รหัสผ่าน",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ปุ่มเข้าสู่ระบบ
          SizedBox(
            width: 200,
            height: 45,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("เข้าสู่ระบบ"),
            ),
          ),

          const SizedBox(height: 20),

          // ลิงก์ไปสมัครสมาชิก
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("หากยังไม่มีบัญชี "),
              GestureDetector(
                onTap: () {
              
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterUserPage()));
                },
                child: const Text(
                  "สมัครสมาชิก",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          Container(height: 40, width: double.infinity, color: Colors.green),
        ],
      ),
    );
  }
}

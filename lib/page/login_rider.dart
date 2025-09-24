import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_rider.dart';

class LoginRiderPage extends StatefulWidget {
  const LoginRiderPage({super.key});

  @override
  State<LoginRiderPage> createState() => _LoginRiderPageState();
}

class _LoginRiderPageState extends State<LoginRiderPage> {
  final _nameCtl = TextEditingController(); // 👉 ชื่อผู้ใช้
  final _passwordCtl = TextEditingController(); // 👉 รหัสผ่าน
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      // ใช้ username สร้าง email ไว้ login
      final email = "${_nameCtl.text.trim()}@delivery.com";
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordCtl.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("เข้าสู่ระบบ Rider สำเร็จ ✅")),
      );

      // TODO: ไปหน้า Dashboard
    } on FirebaseAuthException catch (e) {
      String message = "เข้าสู่ระบบไม่สำเร็จ";
      if (e.code == 'user-not-found') {
        message = "ไม่พบบัญชี Rider";
      } else if (e.code == 'wrong-password') {
        message = "รหัสผ่านไม่ถูกต้อง";
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
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
            "เข้าสู่ระบบ Rider",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 30),

          // ช่องกรอกชื่อผู้ใช้
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: TextField(
              controller: _nameCtl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person, color: Colors.green),
                hintText: "ชื่อผู้ใช้",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.green),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),

          // ช่องกรอกรหัสผ่าน
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: TextField(
              controller: _passwordCtl,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock, color: Colors.green),
                hintText: "รหัสผ่าน",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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

          // ลิงก์ไปสมัคร
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("หากยังไม่มีบัญชี Rider "),
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RegisterRiderPage()),
                  );
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

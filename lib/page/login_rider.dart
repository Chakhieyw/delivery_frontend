import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_rider.dart';
import 'dashboard_rider.dart';

class LoginRiderPage extends StatefulWidget {
  const LoginRiderPage({super.key});

  @override
  State<LoginRiderPage> createState() => _LoginRiderPageState();
}

class _LoginRiderPageState extends State<LoginRiderPage> {
  final _nameCtl = TextEditingController(); // 👉 ใช้ name
  final _passwordCtl = TextEditingController(); // 👉 ใช้ password
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      // 🔹 หา user จาก Firestore ด้วย name
      final snapshot = await FirebaseFirestore.instance
          .collection("riders")
          .where("name", isEqualTo: _nameCtl.text.trim())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ ไม่พบบัญชี Rider นี้")),
        );
        setState(() => _loading = false);
        return;
      }

      final riderData = snapshot.docs.first.data();
      final email = riderData["email"]; // เอา email ที่เก็บไว้

      // 🔹 login ด้วย email + password ที่ user กรอก
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordCtl.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ เข้าสู่ระบบสำเร็จ: ${riderData["name"]}")),
      );

      // 👉 ไปหน้า Dashboard พร้อมส่ง name
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardRiderPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String message = "เข้าสู่ระบบไม่สำเร็จ";
      if (e.code == 'wrong-password') message = "❌ รหัสผ่านไม่ถูกต้อง";
      if (e.code == 'user-not-found') message = "❌ ไม่พบผู้ใช้";
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

          // ชื่อผู้ใช้
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
            child: TextField(
              controller: _nameCtl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person, color: Colors.green),
                hintText: "ชื่อผู้ใช้",
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

          // ไปสมัคร
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

import 'package:delivery_frontend/page/dashboard_user.dart';
import 'package:delivery_frontend/page/registeruser.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginUserPage extends StatefulWidget {
  const LoginUserPage({super.key});

  @override
  State<LoginUserPage> createState() => _LoginUserPageState();
}

class _LoginUserPageState extends State<LoginUserPage> {
  final _nameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      final name = _nameCtl.text.trim();
      final password = _passwordCtl.text.trim();

      // 🔎 ค้นหา email จาก Firestore
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("name", isEqualTo: name)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ ไม่พบบัญชีนี้ในระบบ")),
        );
        setState(() => _loading = false);
        return;
      }

      final userData = query.docs.first.data();
      final email = userData["email"];

      // ✅ Login FirebaseAuth
      UserCredential userCred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCred.user!.uid;

      final doc =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();

      if (doc.exists) {
        final data = doc.data()!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ ยินดีต้อนรับ ${data['name']}")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardUserPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = "เกิดข้อผิดพลาด";
      if (e.code == 'user-not-found') {
        msg = "❌ ไม่พบบัญชีผู้ใช้นี้";
      } else if (e.code == 'wrong-password') {
        msg = "❌ รหัสผ่านไม่ถูกต้อง";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
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
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    const Text(
                      "เข้าสู่ระบบ",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(_nameCtl, Icons.person, "ชื่อผู้ใช้", false),
                    _buildTextField(_passwordCtl, Icons.lock, "รหัสผ่าน", true),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: 200,
                      height: 45,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("เข้าสู่ระบบ"),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ลิงก์สมัครสมาชิก
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("ยังไม่มีบัญชี ? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterUserPage()),
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
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              height: 40,
              width: double.infinity,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctl, IconData icon, String hint, bool obscure) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 6),
      child: TextField(
        controller: ctl,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green),
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.green),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}

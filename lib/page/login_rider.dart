import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
<<<<<<< Updated upstream
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_rider.dart';
import 'dashboard_rider.dart';
import 'select_role.dart'; // ✅ เพิ่ม import
=======
>>>>>>> Stashed changes

class LoginRiderPage extends StatefulWidget {
  const LoginRiderPage({super.key});

  @override
  State<LoginRiderPage> createState() => _LoginRiderPageState();
}

class _LoginRiderPageState extends State<LoginRiderPage> {
  final _nameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _loading = false;

  Future<void> _login() async {
    setState(() => _loading = true);
    try {
<<<<<<< Updated upstream
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
      final email = riderData["email"];

=======
      final email = "${_nameCtl.text.trim()}@delivery.com";
>>>>>>> Stashed changes
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordCtl.text,
      );

      if (!mounted) return;
<<<<<<< Updated upstream

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ เข้าสู่ระบบสำเร็จ: ${riderData["name"]}")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardRiderPage()),
      );
    } on FirebaseAuthException catch (e) {
      String message = "เข้าสู่ระบบไม่สำเร็จ";
      if (e.code == 'wrong-password') message = "❌ รหัสผ่านไม่ถูกต้อง";
      if (e.code == 'user-not-found') message = "❌ ไม่พบผู้ใช้";
=======
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("เข้าสู่ระบบสำเร็จ ✅")),
      );

      // ไปหน้า Dashboard ของ Rider (ตั้ง route ไว้ใน MaterialApp)
      Navigator.pushReplacementNamed(context, "/riderDashboard");
    } on FirebaseAuthException catch (e) {
      String message = "เข้าสู่ระบบไม่สำเร็จ";
      if (e.code == 'user-not-found') message = "ไม่พบบัญชีผู้ใช้";
      if (e.code == 'wrong-password') message = "รหัสผ่านไม่ถูกต้อง";
      if (!mounted) return;
>>>>>>> Stashed changes
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
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

<<<<<<< Updated upstream
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
=======
          _buildTextField(_nameCtl, Icons.person, "ชื่อผู้ใช้", false),
          _buildTextField(_passwordCtl, Icons.lock, "รหัสผ่าน", true),
>>>>>>> Stashed changes

          const SizedBox(height: 20),

          // ปุ่มเข้าสู่ระบบ
          SizedBox(
            width: 200,
            height: 45,
            child: ElevatedButton(
              onPressed: _loading ? null : _login,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
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
              const Text("หากยังไม่มีบัญชี "),
              GestureDetector(
                onTap: () =>
                    Navigator.pushReplacementNamed(context, "/registerRider"),
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

<<<<<<< Updated upstream
          const SizedBox(height: 15),

          // ✅ ปุ่มกลับไป select_role
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const SelectRolePage()),
              );
            },
            child: const Text(
              "⬅️ กลับไปหน้าเลือกบทบาท",
              style: TextStyle(color: Colors.green),
            ),
          ),

=======
>>>>>>> Stashed changes
          const Spacer(),
          Container(height: 40, width: double.infinity, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctl,
    IconData icon,
    String hint,
    bool obscure,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: TextField(
        controller: ctl,
        obscureText: obscure,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.green),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

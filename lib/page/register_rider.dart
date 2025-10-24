import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import 'login_rider.dart';

class RegisterRiderPage extends StatefulWidget {
  const RegisterRiderPage({super.key});

  @override
  State<RegisterRiderPage> createState() => _RegisterRiderPageState();
}

class _RegisterRiderPageState extends State<RegisterRiderPage> {
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _plateCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  File? _imageFile;
  bool _loading = false;

  /// ✅ เลือกรูปโปรไฟล์จาก Gallery
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  /// ✅ สมัคร Rider
  Future<void> _register() async {
    // ✅ ตรวจว่ากรอกครบทุกช่องก่อน
    if (_nameCtl.text.trim().isEmpty ||
        _emailCtl.text.trim().isEmpty ||
        _phoneCtl.text.trim().isEmpty ||
        _plateCtl.text.trim().isEmpty ||
        _passwordCtl.text.trim().isEmpty ||
        _confirmCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ กรุณากรอกข้อมูลให้ครบทุกช่อง")),
      );
      return;
    }

    // ✅ ตรวจว่ารหัสผ่านตรงกันไหม
    if (_passwordCtl.text != _confirmCtl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ รหัสผ่านไม่ตรงกัน")),
      );
      return;
    }

    // ✅ ตรวจเบอร์โทร (10 หลัก)
    if (_phoneCtl.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ กรุณากรอกเบอร์โทรให้ครบ 10 หลัก")),
      );
      return;
    }

    // ✅ ตรวจว่ามีเลือกรูปหรือยัง
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ กรุณาเลือกรูปโปรไฟล์ก่อนสมัคร")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailCtl.text.trim();
      final password = _passwordCtl.text.trim();

      // ✅ สร้างบัญชี Firebase Auth
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // ✅ อัปโหลดรูปไป Cloudinary
      String imageUrl = "";
      if (_imageFile != null) {
        imageUrl = await CloudinaryService.uploadImage(
              fromCamera: false,
              file: _imageFile, // ส่งไฟล์ที่เลือกไป
              folder: "profiles",
            ) ??
            "";
      }

      // ✅ บันทึกข้อมูล Rider ลง Firestore
      await FirebaseFirestore.instance
          .collection("riders")
          .doc(user.user!.uid)
          .set({
        "uid": user.user!.uid,
        "name": _nameCtl.text.trim(),
        "email": email,
        "phone": _phoneCtl.text.trim(),
        "plate": _plateCtl.text.trim(),
        "imageUrl": imageUrl,
        "role": "rider",
        "lat": 0.0,
        "lng": 0.0,
        "status": "offline",
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สมัคร Rider สำเร็จ")),
      );

      // ✅ ไปหน้า Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginRiderPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ สมัครไม่สำเร็จ: $e")),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("สมัคร Rider")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.green.shade100,
                backgroundImage:
                    _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? const Icon(Icons.person, color: Colors.green, size: 55)
                    : null,
              ),
            ),
            const SizedBox(height: 15),
            _buildField(_nameCtl, "ชื่อ Rider", Icons.person),
            _buildField(_emailCtl, "อีเมล", Icons.email),
            _buildField(_phoneCtl, "เบอร์โทรศัพท์", Icons.phone),
            _buildField(_plateCtl, "ทะเบียนรถ", Icons.directions_bike),
            _buildField(_passwordCtl, "รหัสผ่าน", Icons.lock, isPassword: true),
            _buildField(_confirmCtl, "ยืนยันรหัสผ่าน", Icons.lock_outline,
                isPassword: true),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _register,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("สมัคร Rider"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctl, String hint, IconData icon,
      {bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: ctl,
        obscureText: isPassword,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.green),
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green, width: 2),
          ),
        ),
      ),
    );
  }
}

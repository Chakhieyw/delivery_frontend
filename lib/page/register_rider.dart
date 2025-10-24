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
    if (_passwordCtl.text != _confirmCtl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ รหัสผ่านไม่ตรงกัน")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailCtl.text.trim();
      final password = _passwordCtl.text.trim();

      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await CloudinaryService.uploadImage(
          fromCamera: false,
          folder: "profiles",
        );
      }

      await FirebaseFirestore.instance
          .collection("riders")
          .doc(user.user!.uid)
          .set({
        "name": _nameCtl.text.trim(),
        "email": email,
        "phone": _phoneCtl.text.trim(),
        "plate": _plateCtl.text.trim(),
        "imageUrl": imageUrl ?? "",
        "role": "rider",
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สมัคร Rider สำเร็จ")),
      );

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

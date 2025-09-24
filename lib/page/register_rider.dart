import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'login_rider.dart';

class RegisterRiderPage extends StatefulWidget {
  const RegisterRiderPage({super.key});

  @override
  State<RegisterRiderPage> createState() => _RegisterRiderPageState();
}

class _RegisterRiderPageState extends State<RegisterRiderPage> {
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _plateCtl = TextEditingController();

  File? _imageFile;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _register() async {
    if (_passwordCtl.text != _confirmCtl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("❌ รหัสผ่านไม่ตรงกัน")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      UserCredential user =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtl.text.trim(),
        password: _passwordCtl.text,
      );

      String? imageUrl;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("rider_images")
            .child("${user.user!.uid}.jpg");
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance
          .collection("riders")
          .doc(user.user!.uid)
          .set({
        "phone": _phoneCtl.text,
        "email": _emailCtl.text,
        "name": _nameCtl.text,
        "plate": _plateCtl.text,
        "role": "rider",
        "imageUrl": imageUrl ?? "",
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สมัคร Rider สำเร็จ")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginRiderPage()),
      );
    } catch (e) {
      if (!mounted) return;
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 20),
          const Text(
            "สมัครสมาชิก Rider",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 20),

          _buildTextField(_phoneCtl, Icons.phone, "เบอร์โทรศัพท์", false),
          _buildTextField(_emailCtl, Icons.email, "อีเมล", false),
          _buildTextField(_nameCtl, Icons.person, "ชื่อผู้ใช้", false),
          _buildTextField(_passwordCtl, Icons.lock, "รหัสผ่าน", true),
          _buildTextField(
              _confirmCtl, Icons.lock_outline, "ยืนยันรหัสผ่าน", true),
          _buildTextField(_plateCtl, Icons.credit_card, "ทะเบียนรถ", false),

          const SizedBox(height: 15),

          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(_imageFile!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person, size: 50, color: Colors.green),
                        Text("เลือกรูปภาพ",
                            style: TextStyle(color: Colors.green)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 25),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 140,
                height: 45,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("สมัครสมาชิก"),
                ),
              ),
              const SizedBox(width: 15),
              SizedBox(
                width: 120,
                height: 45,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginRiderPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text("ยกเลิก"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("หากเป็นสมาชิกอยู่แล้วกลับไปที่หน้า "),
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginRiderPage()),
                ),
                child: const Text(
                  "เข้าสู่ระบบ",
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.green),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

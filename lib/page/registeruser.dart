import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RegisterUserPage extends StatefulWidget {
  const RegisterUserPage({super.key});

  @override
  State<RegisterUserPage> createState() => _RegisterUserPageState();
}

class _RegisterUserPageState extends State<RegisterUserPage> {
  final _phoneCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _addressCtl = TextEditingController();

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
      final email = "${_phoneCtl.text}@delivery.com";

      // สมัคร Firebase Auth
      UserCredential user = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: _passwordCtl.text,
      );

      String? imageUrl;
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child("user_images")
            .child("${user.user!.uid}.jpg");
        await ref.putFile(_imageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      // เก็บข้อมูลใน Firestore
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.user!.uid)
          .set({
        "phone": _phoneCtl.text,
        "address": _addressCtl.text,
        "role": "user",
        "imageUrl": imageUrl ?? "",
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ สมัครสมาชิกสำเร็จ")),
      );

      Navigator.pop(context);
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
            "สมัครสมาชิก",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),

          const SizedBox(height: 20),

          // ช่องกรอกข้อมูล
          _buildTextField(_phoneCtl, Icons.phone, "เบอร์โทรศัพท์", false),
          _buildTextField(_passwordCtl, Icons.lock, "รหัสผ่าน", true),
          _buildTextField(_confirmCtl, Icons.lock_outline, "ยืนยันรหัสผ่าน", true),
          _buildTextField(_addressCtl, Icons.location_on, "ที่อยู่ (เพิ่มที่อยู่)", false),

          const SizedBox(height: 10),

          // ปุ่มเลือกรูปภาพ
          OutlinedButton(
            onPressed: _pickImage,
            child: const Text("เลือกรูปภาพ"),
          ),

          if (_imageFile != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 40,
                backgroundImage: FileImage(_imageFile!),
              ),
            ),

          const SizedBox(height: 20),

          // ปุ่มสมัคร + ยกเลิก
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
                  onPressed: () => Navigator.pop(context),
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

          // ลิงก์เข้าสู่ระบบ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("หากเป็นสมาชิกอยู่แล้วกลับไปที่หน้า "),
              GestureDetector(
                onTap: () => Navigator.pop(context),
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

  Widget _buildTextField(TextEditingController ctl, IconData icon, String hint, bool obscure) {
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

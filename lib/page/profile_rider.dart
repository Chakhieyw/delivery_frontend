import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RiderProfilePage extends StatefulWidget {
  const RiderProfilePage({super.key});

  @override
  State<RiderProfilePage> createState() => _RiderProfilePageState();
}

class _RiderProfilePageState extends State<RiderProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? name;
  String? phone;
  String? plate;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    fetchRiderData();
  }

  Future<void> fetchRiderData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final doc = await _firestore.collection('riders').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          name = doc['name'];
          phone = doc['phone'];
          plate = doc['plate'];
          imageUrl = doc['imageUrl'];
        });
      }
    } catch (e) {
      print("Error fetching rider data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        child: Center(
          child: Column(
            children: [
              // 🔹 Card หลักของข้อมูล
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 🔹 รูปโปรไฟล์
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF4CAF50),
                      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                          ? NetworkImage(imageUrl!)
                          : null,
                      child: imageUrl == null || imageUrl!.isEmpty
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 15),
                    // 🔹 ชื่อ
                    Text(
                      name ?? 'กำลังโหลด...',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 🔹 เส้นคั่น
                    Container(
                      width: 60,
                      height: 2,
                      color: const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 15),
                    // 🔹 เบอร์โทร
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.phone, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          phone ?? '-',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // 🔹 ทะเบียนรถ
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.motorcycle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          plate ?? '-',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    // 🔹 ปุ่มแก้ไขข้อมูล
                    TextButton.icon(
                      onPressed: () {
                        // TODO: ไปหน้าแก้ไขโปรไฟล์
                      },
                      icon: const Icon(Icons.edit, color: Colors.green),
                      label: const Text(
                        "แก้ไขข้อมูล",
                        style: TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // 🔹 Footer Text
              const Text(
                "Delivery AppT&K © 2025",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

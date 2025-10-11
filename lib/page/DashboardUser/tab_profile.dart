import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:delivery_frontend/page/EditUserProfile.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text("กรุณาเข้าสู่ระบบ"));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? '-';
        final email = data['email'] ?? '-';
        final phone = data['phone'] ?? '-';
        final address = data['address'] ?? '-';
        final imageUrl = data['imageUrl'] ?? '';

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.green.shade100,
                  backgroundImage:
                      (imageUrl.isNotEmpty) ? NetworkImage(imageUrl) : null,
                  child: imageUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.green, size: 70)
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
                const SizedBox(height: 10),
                _buildInfo(Icons.email, "อีเมล", email),
                _buildInfo(Icons.phone, "เบอร์โทรศัพท์", phone),
                _buildInfo(Icons.home, "ที่อยู่", address),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const EditProfileUserPage()),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text("แก้ไขข้อมูล"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfo(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                Text(value,
                    style:
                        const TextStyle(color: Colors.black87, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

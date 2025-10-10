import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery_frontend/firebase_options.dart';
import 'package:delivery_frontend/page/select_role.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// ✅ เพิ่ม import สำหรับ dotenv
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ โหลดค่าจากไฟล์ .env (ก่อน init Firebase)
  await dotenv.load(fileName: ".env");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase initialized successfully");
  } catch (e) {
    debugPrint("❌ Firebase init error: $e");
  }

  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Delivery AppT&K",
      theme: ThemeData(primarySwatch: Colors.green),
      home: const SelectRolePage(),
    );
  }
}

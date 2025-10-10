import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  late final CloudinaryPublic _cloud;

  CloudinaryService() {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME']!;
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET']!;
    _cloud = CloudinaryPublic(cloudName, preset, cache: false);
  }

  Future<String> uploadFile(File file, {String folder = 'delivery_app'}) async {
    final res = await _cloud.uploadFile(
      CloudinaryFile.fromFile(file.path, folder: folder),
    );
    return res.secureUrl;
  }
}

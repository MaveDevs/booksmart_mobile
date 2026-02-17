import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

/// Servicio para manejar fotos de perfil guardadas localmente
///
/// Las fotos se guardan en el directorio de documentos de la aplicación
/// con el nombre "profile_photo_{userId}.jpg"
///
class ProfilePhotoService {
  static final ImagePicker _picker = ImagePicker();

  /// Obtiene el directorio donde se guardan las fotos
  static Future<Directory> get _photoDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final photoDir = Directory('${appDir.path}/profile_photos');
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }
    return photoDir;
  }

  /// Genera el path para la foto de perfil de un usuario
  static Future<String> _getPhotoPath(int userId) async {
    final dir = await _photoDirectory;
    return '${dir.path}/profile_photo_$userId.jpg';
  }

  /// Verifica si existe una foto de perfil para el usuario
  static Future<bool> hasProfilePhoto(int userId) async {
    final path = await _getPhotoPath(userId);
    return File(path).exists();
  }

  /// Obtiene la foto de perfil del usuario
  /// Retorna null si no existe
  static Future<File?> getProfilePhoto(int userId) async {
    final path = await _getPhotoPath(userId);
    final file = File(path);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Selecciona una foto de la galería y la guarda
  static Future<File?> pickFromGallery(int userId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        return await _savePhoto(userId, File(image.path));
      }
    } catch (e) {
      print('Error picking image from gallery: $e');
    }
    return null;
  }

  /// Toma una foto con la cámara y la guarda
  static Future<File?> pickFromCamera(int userId) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        return await _savePhoto(userId, File(image.path));
      }
    } catch (e) {
      print('Error taking photo: $e');
    }
    return null;
  }

  /// Guarda una foto como foto de perfil del usuario
  static Future<File> _savePhoto(int userId, File sourceFile) async {
    final path = await _getPhotoPath(userId);
    final savedFile = await sourceFile.copy(path);
    return savedFile;
  }

  /// Elimina la foto de perfil del usuario
  static Future<void> deleteProfilePhoto(int userId) async {
    final path = await _getPhotoPath(userId);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Limpia todas las fotos de perfil (útil al cerrar sesión)
  static Future<void> clearAllPhotos() async {
    try {
      final dir = await _photoDirectory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing photos: $e');
    }
  }
}

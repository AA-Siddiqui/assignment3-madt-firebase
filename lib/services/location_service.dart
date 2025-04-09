import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/location_note.dart';

class LocationService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<LocationNote> _locations = [];

  List<LocationNote> get locations => _locations;

  Future<void> loadLocations(int userId) async {
    try {
      // Convert userId to string for Firestore
      final userIdStr = userId.toString();

      // Query locations for this user
      final snapshot = await _firestore
          .collection('locations')
          .where('userId', isEqualTo: userIdStr)
          .get();

      _locations = snapshot.docs.map((doc) {
        final data = doc.data();
        return LocationNote(
          id: int.tryParse(doc.id) ?? 0, // Use document ID as location ID
          userId: int.parse(data['userId']),
          name: data['name'],
          description: data['description'],
          imagePath: data['imagePath'],
        );
      }).toList();

      notifyListeners();
    } catch (e) {
      print('Error loading locations: $e');
    }
  }

  Future<bool> addLocation({
    required int userId,
    required String name,
    String? description,
    XFile? imageFile,
  }) async {
    try {
      String? imagePath;

      if (imageFile != null) {
        imagePath = await _saveImage(imageFile);
      }

      // Create document in Firestore
      final docRef = await _firestore.collection('locations').add({
        'userId': userId.toString(),
        'name': name,
        'description': description,
        'imagePath': imagePath,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final newLocation = LocationNote(
        id: int.tryParse(docRef.id) ?? 0,
        userId: userId,
        name: name,
        description: description,
        imagePath: imagePath,
      );

      _locations.add(newLocation);
      notifyListeners();
      return true;
    } catch (e) {
      print('Add location error: $e');
      return false;
    }
  }

  Future<bool> updateLocation({
    required LocationNote location,
    String? name,
    String? description,
    XFile? newImageFile,
    bool deleteImage = false,
  }) async {
    try {
      String? imagePath = location.imagePath;

      // Handle the image
      if (deleteImage) {
        if (imagePath != null) {
          await _deleteImage(imagePath);
          imagePath = null;
        }
      } else if (newImageFile != null) {
        // Delete old image if exists
        if (imagePath != null) {
          await _deleteImage(imagePath);
        }
        // Save new image
        imagePath = await _saveImage(newImageFile);
      }

      // Update in Firestore
      await _firestore
          .collection('locations')
          .doc(location.id.toString())
          .update({
        'name': name ?? location.name,
        'description': description ?? location.description,
        'imagePath': imagePath,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final updatedLocation = LocationNote(
        id: location.id,
        userId: location.userId,
        name: name ?? location.name,
        description: description ?? location.description,
        imagePath: imagePath,
      );

      final index = _locations.indexWhere((loc) => loc.id == location.id);
      if (index != -1) {
        _locations[index] = updatedLocation;
        notifyListeners();
      }
      return true;
    } catch (e) {
      print('Update location error: $e');
      return false;
    }
  }

  Future<bool> deleteLocation(LocationNote location) async {
    try {
      // Delete from Firestore
      await _firestore
          .collection('locations')
          .doc(location.id.toString())
          .delete();

      // Delete the associated image if exists
      if (location.imagePath != null) {
        await _deleteImage(location.imagePath!);
      }

      _locations.removeWhere((loc) => loc.id == location.id);
      notifyListeners();
      return true;
    } catch (e) {
      print('Delete location error: $e');
      return false;
    }
  }

  Future<String> _saveImage(XFile image) async {
    final directory = await getApplicationDocumentsDirectory();
    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '${directory.path}/$filename';

    await File(image.path).copy(path);
    return path;
  }

  Future<void> _deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}

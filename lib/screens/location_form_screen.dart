import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/location_note.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';

class LocationFormScreen extends StatefulWidget {
  final LocationNote? location;

  const LocationFormScreen({super.key, this.location});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  XFile? _imageFile;
  String? _existingImagePath;
  bool _deleteImage = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.location != null) {
      _nameController.text = widget.location!.name;
      if (widget.location!.description != null) {
        _descriptionController.text = widget.location!.description!;
      }

      if (widget.location!.imagePath != null) {
        _existingImagePath = widget.location!.imagePath;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.location != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Location' : 'Add Location'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name for this location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _buildImageSection(),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveLocation,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          isEditing ? 'Update Location' : 'Save Location',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    bool hasImage =
        _imageFile != null || (_existingImagePath != null && !_deleteImage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location Image',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imageFile != null
                        ? Image.file(
                            File(_imageFile!.path),
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_existingImagePath!),
                            fit: BoxFit.cover,
                          ),
                  )
                : Icon(
                    Icons.image,
                    size: 80,
                    color: Colors.grey[400],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_camera),
              label: const Text('Camera'),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            if (hasImage)
              ElevatedButton.icon(
                icon: const Icon(Icons.delete),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () {
                  setState(() {
                    _imageFile = null;
                    _deleteImage = true;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
        _deleteImage = false;
      });
    }
  }

  Future<void> _saveLocation() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authService = Provider.of<AuthService>(context, listen: false);
      final locationService =
          Provider.of<LocationService>(context, listen: false);

      bool success;

      if (widget.location == null) {
        // Add new location
        success = await locationService.addLocation(
          userId: authService.currentUser!.id!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          imageFile: _imageFile,
        );
      } else {
        // Update existing location
        success = await locationService.updateLocation(
          location: widget.location!,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          newImageFile: _imageFile,
          deleteImage: _deleteImage,
        );
      }

      setState(() => _isLoading = false);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to save location. Please try again.')),
          );
        }
      }
    }
  }
}

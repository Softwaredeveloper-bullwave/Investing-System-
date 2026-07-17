import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/kyc_flow_provider.dart';

class _PickedPhoto {
  final XFile file;
  final Uint8List bytes;

  const _PickedPhoto({required this.file, required this.bytes});
}

class KycSubmitScreen extends StatefulWidget {
  const KycSubmitScreen({super.key});

  @override
  State<KycSubmitScreen> createState() => _KycSubmitScreenState();
}

class _KycSubmitScreenState extends State<KycSubmitScreen> {
  static const _maxPhotos = 5;

  final _formKey = GlobalKey<FormState>();
  final _panController = TextEditingController();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final List<_PickedPhoto> _photos = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _panController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  bool get _canAddMore => _photos.length < _maxPhotos;

  Future<void> _addPhotos(List<XFile> files) async {
    if (files.isEmpty) return;
    final remaining = _maxPhotos - _photos.length;
    if (remaining <= 0) {
      _showSnack('You can upload up to $_maxPhotos photos.');
      return;
    }

    final toAdd = files.take(remaining).toList();
    if (files.length > remaining) {
      _showSnack('Only $remaining more photo(s) added (max $_maxPhotos).');
    }

    for (final file in toAdd) {
      final bytes = await file.readAsBytes();
      _photos.add(_PickedPhoto(file: file, bytes: bytes));
    }
    setState(() {});
  }

  Future<void> _pickFromCamera() async {
    if (!_canAddMore) {
      _showSnack('Maximum $_maxPhotos photos reached.');
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file != null) await _addPhotos([file]);
    } catch (e) {
      _showSnack('Could not open camera. ($e)');
    }
  }

  Future<void> _pickFromGallery() async {
    if (!_canAddMore) {
      _showSnack('Maximum $_maxPhotos photos reached.');
      return;
    }
    try {
      final files = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
      );
      await _addPhotos(files);
    } catch (e) {
      _showSnack('Could not open gallery. ($e)');
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: now,
    );
    if (picked != null) {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photos.isEmpty) {
      _showSnack('Please upload at least one PAN card photo.');
      return;
    }

    final kyc = context.read<KycFlowProvider>();
    final ok = await kyc.submitManualKyc(
      panNumber: _panController.text,
      fullName: _nameController.text,
      dob: _dobController.text,
      panImages: _photos.map((p) => p.file).toList(),
    );
    if (!mounted) return;
    if (ok) {
      context.go(AppRoutes.kycPending);
    } else if (kyc.error != null) {
      _showSnack(kyc.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycFlowProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Verify PAN'),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Submit your PAN for manual verification',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload clear photos of your PAN card (front/back). You can select multiple images.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _panController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'PAN number',
                  hintText: 'ABCDE1234F',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final pan = (v ?? '').toUpperCase().trim();
                  if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
                    return 'Enter a valid 10-character PAN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name (as per PAN)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().length < 2 ? 'Enter your name as on PAN' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: _pickDob,
                decoration: const InputDecoration(
                  labelText: 'Date of birth',
                  hintText: 'YYYY-MM-DD',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) => (v ?? '').isEmpty ? 'Select date of birth' : null,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('PAN card photos', style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${_photos.length}/$_maxPhotos',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_photos.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final photo = _photos[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              photo.bytes,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Material(
                              color: Colors.black54,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: () => _removePhoto(index),
                                customBorder: const CircleBorder(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canAddMore ? _pickFromCamera : null,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _canAddMore ? _pickFromGallery : null,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Gallery: select multiple photos at once',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: kyc.isLoading ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.brandOrange),
                  child: kyc.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit for verification', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityController;
  late final TextEditingController _bioController;

  DateTime? _dateOfBirth;
  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _removeAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _cityController = TextEditingController(text: user?.city ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _dateOfBirth = user?.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = file.name;
      _removeAvatar = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1995, 1, 1),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    if (_pickedImageBytes != null) {
      final uploaded = await auth.uploadAvatar(_pickedImageBytes!, _pickedImageName ?? 'avatar.jpg');
      if (!uploaded && mounted) {
        AppSnackbar.error(context, auth.error ?? 'Photo upload failed');
        return;
      }
    } else if (_removeAvatar) {
      await auth.removeAvatar();
    }

    final success = await auth.updateProfile(
      name: _nameController.text,
      email: _emailController.text,
      city: _cityController.text,
      bio: _bioController.text,
      dateOfBirth: _dateOfBirth,
    );

    if (!mounted) return;
    if (success) {
      AppSnackbar.success(context, 'Profile saved');
      context.pop();
    } else {
      AppSnackbar.error(context, auth.error ?? 'Failed to save profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final avatarUrl = user?.avatarUrl ?? '';
    final resolvedUrl = ApiConfig.resolveMediaUrl(avatarUrl);

    ImageProvider? avatarImage;
    if (_pickedImageBytes != null) {
      avatarImage = MemoryImage(_pickedImageBytes!);
    } else if (!_removeAvatar && resolvedUrl.isNotEmpty) {
      avatarImage = NetworkImage(resolvedUrl);
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Edit Profile'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.green.withValues(alpha: 0.12),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(Icons.person, size: 48, color: AppColors.green)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: AppColors.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showPhotoOptions(),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                user?.phone ?? '',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppDimensions.paddingLg),
              AppTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your name',
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().length < 2 ? 'Enter your name' : null,
              ),
              const SizedBox(height: AppDimensions.paddingMd),
              AppTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'you@email.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.paddingMd),
              AppTextField(
                controller: _cityController,
                label: 'City',
                hint: 'Mumbai',
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppDimensions.paddingMd),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dateOfBirth != null
                            ? DateFormat('dd MMM yyyy').format(_dateOfBirth!)
                            : 'Select date',
                        style: TextStyle(
                          color: _dateOfBirth != null ? null : Colors.grey,
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingMd),
              AppTextField(
                controller: _bioController,
                label: 'Bio',
                hint: 'Short intro about you',
                maxLines: 3,
              ),
              const SizedBox(height: AppDimensions.paddingXl),
              PrimaryButton(
                label: 'Save Profile',
                isLoading: auth.isLoading,
                onPressed: auth.isLoading ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_pickedImageBytes != null || (context.read<AuthProvider>().user?.avatarUrl.isNotEmpty ?? false))
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Remove photo', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _pickedImageBytes = null;
                    _pickedImageName = null;
                    _removeAvatar = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_config.dart';
import '../../../../core/api/refresh_providers.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _cityController;
  late final TextEditingController _referralCodeController;

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
    _referralCodeController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageName = file.name.isNotEmpty ? file.name : 'avatar.jpg';
      _removeAvatar = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();

    if (_pickedImageBytes != null) {
      final uploaded = await auth.uploadAvatar(
        _pickedImageBytes!,
        _pickedImageName ?? 'avatar.jpg',
      );
      if (!uploaded && mounted) {
        AppSnackbar.error(context, auth.error ?? 'Photo upload failed');
        return;
      }
    } else if (_removeAvatar) {
      await auth.removeAvatar();
    }

    final success = await auth.completeProfileSetup(
      name: _nameController.text,
      email: _emailController.text,
      city: _cityController.text,
      referralCode: _referralCodeController.text,
    );

    if (!mounted) return;

    if (success) {
      unawaited(refreshAllProviders(context));
      if (!mounted) return;
      context.go(AppRoutes.home);
    } else {
      AppSnackbar.error(context, auth.error ?? 'Could not save profile');
    }
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
            if (_pickedImageBytes != null ||
                (context.read<AuthProvider>().user?.avatarUrl.isNotEmpty ?? false))
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final resolvedUrl = ApiConfig.resolveMediaUrl(user?.avatarUrl ?? '');

    ImageProvider? avatarImage;
    if (_pickedImageBytes != null) {
      avatarImage = MemoryImage(_pickedImageBytes!);
    } else if (!_removeAvatar && resolvedUrl.isNotEmpty) {
      avatarImage = NetworkImage(resolvedUrl);
    }

    final colors = context.appColors;

    return PopScope(
      canPop: false,
      child: PremiumAuthShell(
        matchAppTheme: true,
        glowPrimary: AppColors.brandPink,
        glowSecondary: AppColors.brandPrimary,
        topBar: const PremiumBrandHeader(),
        bottomBar: PremiumAuthBottomBar(
          showBack: false,
          onNext: auth.isLoading ? () {} : _submit,
          isLoading: auth.isLoading,
          nextIcon: Icons.check_rounded,
          isLast: true,
          onStart: auth.isLoading ? null : _submit,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const PremiumPillTag(label: 'Profile'),
                const SizedBox(height: 20),
                const PremiumAuthHeadline(text: 'COMPLETE\nYOUR PROFILE'),
                const SizedBox(height: 12),
                PremiumAuthBody(
                  text: user?.phone.isNotEmpty == true
                      ? 'Verified +91 ${user!.phone}. Add your details to unlock live markets.'
                      : 'Add your details to unlock live markets and portfolio.',
                ),
                const SizedBox(height: 28),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: colors.textPrimary.withValues(alpha: 0.06),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Icon(Icons.person, size: 44, color: colors.textMuted)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: auth.isLoading ? null : _showPhotoOptions,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colors.primary,
                            ),
                            child: Icon(Icons.camera_alt_rounded, color: colors.onPrimary, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  hint: 'Your name',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      v == null || v.trim().length < 2 ? 'Enter your full name' : null,
                ),
                const SizedBox(height: AppDimensions.paddingMd),
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'you@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
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
                AppTextField(
                  controller: _referralCodeController,
                  label: 'Referral Code (optional)',
                  hint: 'Friend\'s code e.g. BW1234AB',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

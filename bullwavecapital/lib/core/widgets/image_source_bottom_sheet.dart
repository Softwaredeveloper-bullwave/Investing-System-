import 'package:flutter/material.dart';
import '../constants/dimensions.dart';
import '../theme/app_theme_extension.dart';
import '../theme/colors.dart';
import 'custom_dialog.dart';

enum ImageSource { gallery, camera, files }

class ImageSourceBottomSheet {
  ImageSourceBottomSheet._();

  static Future<void> show(
    BuildContext context, {
    required String documentName,
    required VoidCallback onUploaded,
    bool showFilesOption = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final colors = sheetContext.appColors;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.paddingLg,
            AppDimensions.paddingSm,
            AppDimensions.paddingLg,
            AppDimensions.paddingLg + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose Image Source',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                documentName,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingLg),
              _SourceTile(
                icon: Icons.photo_library_rounded,
                iconColor: AppColors.primary,
                iconBackground: AppColors.primary.withValues(alpha: 0.1),
                title: 'Gallery',
                subtitle: 'Pick from photo library',
                onTap: () => _handleSelection(
                  sheetContext,
                  context,
                  documentName: documentName,
                  source: ImageSource.gallery,
                  onUploaded: onUploaded,
                ),
              ),
              const SizedBox(height: 10),
              _SourceTile(
                icon: Icons.photo_camera_rounded,
                iconColor: AppColors.accent,
                iconBackground: AppColors.accent.withValues(alpha: 0.12),
                title: 'Camera',
                subtitle: 'Take a new photo',
                onTap: () => _handleSelection(
                  sheetContext,
                  context,
                  documentName: documentName,
                  source: ImageSource.camera,
                  onUploaded: onUploaded,
                ),
              ),
              if (showFilesOption) ...[
                const SizedBox(height: 10),
                _SourceTile(
                  icon: Icons.folder_open_rounded,
                  iconColor: AppColors.secondary,
                  iconBackground: AppColors.secondary.withValues(alpha: 0.1),
                  title: 'Files',
                  subtitle: 'Browse device storage',
                  onTap: () => _handleSelection(
                    sheetContext,
                    context,
                    documentName: documentName,
                    source: ImageSource.files,
                    onUploaded: onUploaded,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.paddingMd),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  static void _handleSelection(
    BuildContext sheetContext,
    BuildContext parentContext, {
    required String documentName,
    required ImageSource source,
    required VoidCallback onUploaded,
  }) {
    Navigator.pop(sheetContext);
    onUploaded();
    final label = switch (source) {
      ImageSource.gallery => 'Gallery',
      ImageSource.camera => 'Camera',
      ImageSource.files => 'Files',
    };
    AppSnackbar.success(
      parentContext,
      '$documentName uploaded from $label',
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingMd,
              vertical: 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

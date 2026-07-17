import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/dimensions.dart';
import '../theme/app_theme_extension.dart';
import '../theme/colors.dart';

class ModernOtpInput extends StatefulWidget {
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const ModernOtpInput({
    super.key,
    this.onCompleted,
    this.onChanged,
    this.enabled = true,
  });

  @override
  State<ModernOtpInput> createState() => ModernOtpInputState();
}

class ModernOtpInputState extends State<ModernOtpInput> {
  static const int _length = 6;

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String get otp => _controller.text;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clear() {
    _controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
    setState(() {});
  }

  void _handleChange(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits != value) {
      _controller.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }

    setState(() {});
    widget.onChanged?.call(digits);

    if (digits.length == _length) {
      widget.onCompleted?.call(digits);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final code = _controller.text;

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: List.generate(_length, (index) {
              final filled = index < code.length;
              final active = index == code.length && _focusNode.hasFocus;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == _length - 1 ? 0 : 4,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      border: Border.all(
                        color: active
                            ? AppColors.green
                            : filled
                                ? colors.border
                                : colors.border.withValues(alpha: 0.7),
                        width: active ? 2 : 1,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: AppColors.green.withValues(alpha: 0.15),
                                blurRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      filled ? code[index] : '',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Opacity(
            opacity: 0,
            child: SizedBox(
              height: 58,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_length),
                ],
                maxLength: _length,
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
                onChanged: _handleChange,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

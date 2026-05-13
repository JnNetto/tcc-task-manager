import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ParticipantOnboardingScreen extends StatefulWidget {
  final Future<void> Function(String number3Digits) onSubmit;

  const ParticipantOnboardingScreen({
    super.key,
    required this.onSubmit,
  });

  @override
  State<ParticipantOnboardingScreen> createState() =>
      _ParticipantOnboardingScreenState();
}

class _ParticipantOnboardingScreenState extends State<ParticipantOnboardingScreen> {
  final _controllers = List.generate(3, (_) => TextEditingController());
  final _focusNodes = List.generate(3, (_) => FocusNode());
  bool _submitting = false;

  String get _digits => _controllers.map((c) => c.text).join();
  bool get _isValid => RegExp(r'^\d{3}$').hasMatch(_digits);

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_digits);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 2) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 40),
                  const SizedBox(height: 16),
                  const Text(
                    'Informe seu numero de participante',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use 3 digitos (ex.: 001, 023, 123)',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: SizedBox(
                          width: 58,
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            autofocus: i == 0,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            textInputAction:
                                i == 2 ? TextInputAction.done : TextInputAction.next,
                            maxLength: 1,
                            decoration: const InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            onChanged: (v) => _onDigitChanged(i, v),
                            onSubmitted: (_) {
                              if (i == 2) _submit();
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ID gerado: P${_digits.padRight(3, '_')}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isValid && !_submitting ? _submit : null,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continuar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

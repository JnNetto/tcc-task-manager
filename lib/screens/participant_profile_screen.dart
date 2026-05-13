import 'package:flutter/material.dart';

import '../domain/models/profile_questionnaire.dart';

/// Questionário básico após o código (nome, idade, género, escolaridade).
class ParticipantProfileScreen extends StatefulWidget {
  const ParticipantProfileScreen({
    super.key,
    required this.onSubmit,
  });

  final Future<void> Function(ProfileQuestionnaire answers) onSubmit;

  @override
  State<ParticipantProfileScreen> createState() => _ParticipantProfileScreenState();
}

class _ParticipantProfileScreenState extends State<ParticipantProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String? _gender;
  String? _education;
  bool _submitting = false;

  static const _genderOptions = [
    ('female', 'Feminino'),
    ('male', 'Masculino'),
    ('non_binary', 'Não-binário'),
    ('prefer_not', 'Prefiro não informar'),
    ('other', 'Outro'),
  ];

  static const _educationLevels = [
    ('fund_inc', 'Fundamental incompleto'),
    ('fund_comp', 'Fundamental completo'),
    ('med_inc', 'Médio incompleto'),
    ('med_comp', 'Médio completo'),
    ('sup_inc', 'Superior incompleto'),
    ('sup_comp', 'Superior completo'),
    ('pos', 'Pós-graduação'),
    ('edu_skip', 'Prefiro não informar'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null || _education == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione género e escolaridade.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final age = int.parse(_ageCtrl.text.trim());
      await widget.onSubmit(
        ProfileQuestionnaire(
          name: _nameCtrl.text.trim(),
          age: age,
          gender: _gender!,
          education: _education!,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre si')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Responda ao questionário para continuar. Os dados são usados apenas no âmbito do estudo.',
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome ou pseudónimo',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obrigatório';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageCtrl,
                decoration: const InputDecoration(
                  labelText: 'Idade',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Obrigatório';
                  final n = int.tryParse(v.trim());
                  if (n == null || n < 10 || n > 120) return 'Idade inválida';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('gender_${_gender ?? 'none'}'),
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: 'Género',
                  border: OutlineInputBorder(),
                ),
                items: _genderOptions
                    .map(
                      (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _gender = v),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey<String?>('edu_${_education ?? 'none'}'),
                initialValue: _education,
                decoration: const InputDecoration(
                  labelText: 'Escolaridade',
                  border: OutlineInputBorder(),
                ),
                items: _educationLevels
                    .map(
                      (e) => DropdownMenuItem(value: e.$1, child: Text(e.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _education = v),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

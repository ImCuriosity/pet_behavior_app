// lib/features/dog_profile/screens/edit_dog_profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dognal1/core/providers/dog_provider.dart';
import 'package:dognal1/core/providers/auth_provider.dart';

class EditDogProfileScreen extends ConsumerStatefulWidget {
  final String dogId;
  const EditDogProfileScreen({super.key, required this.dogId});

  @override
  ConsumerState<EditDogProfileScreen> createState() =>
      _EditDogProfileScreenState();
}

class _EditDogProfileScreenState extends ConsumerState<EditDogProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _breedController;
  late TextEditingController _ageController;
  late TextEditingController _notesController;
  String? _gender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _breedController = TextEditingController();
    _ageController = TextEditingController();
    _notesController = TextEditingController();

    // Provider를 통해 초기 데이터를 불러와 컨트롤러에 설정
    ref.read(dogProfileProvider(widget.dogId).future).then((profile) {
      if (mounted) {
        setState(() {
          _nameController.text = profile.name;
          _breedController.text = profile.breed ?? '';
          _ageController.text = profile.age?.toString() ?? '';
          _notesController.text = profile.notes ?? '';
          _gender = profile.gender;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // --- [추가] 로그아웃 함수 ---
  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // 앱의 가장 첫 화면(AuthChecker가 있는)으로 이동시킵니다.
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그아웃 실패: $e')),
        );
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.from('dogs').update({
        'name': _nameController.text,
        'breed': _breedController.text,
        'age': int.tryParse(_ageController.text),
        'gender': _gender,
        'notes': _notesController.text,
      }).eq('id', widget.dogId);

      // 데이터 갱신 후 Provider들을 초기화하여 다른 화면에 변경사항 반영
      ref.invalidate(dogProfileProvider(widget.dogId));
      ref.invalidate(dogIdProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('프로필이 성공적으로 수정되었습니다!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('프로필 수정 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dogProfileAsync = ref.watch(dogProfileProvider(widget.dogId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('반려견 프로필 수정'),
        // --- [추가] 로그아웃 버튼 ---
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: dogProfileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('프로필 로딩 실패: $err')),
        data: (profile) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: '이름'),
                    validator: (value) =>
                    value!.isEmpty ? '이름을 입력해주세요.' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _breedController,
                    decoration: const InputDecoration(labelText: '견종'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ageController,
                    decoration: const InputDecoration(labelText: '나이'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(labelText: '성별'),
                    items: ['수컷', '암컷', '미정']
                        .map((label) => DropdownMenuItem(
                      value: label,
                      child: Text(label),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _gender = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(labelText: '특이사항'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text('수정 완료'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

/// 拍照打卡页 — 从相册选图后确认打卡
class PhotoCheckinPage extends ConsumerStatefulWidget {
  const PhotoCheckinPage({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<PhotoCheckinPage> createState() => _PhotoCheckinPageState();
}

class _PhotoCheckinPageState extends ConsumerState<PhotoCheckinPage> {
  File? _imageFile;
  final _notesController = TextEditingController();
  var _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (_imageFile == null) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(checkinRepositoryProvider);
      final session = ref.read(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return;

      final now = DateTime.now();
      final record = await repo.createRecord(
        CheckinRecordDraft(
          planId: widget.planId,
          recordDate: now,
          completedAt: now,
          count: 1,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        ),
        userId,
      );

      await repo.addPhoto(
        recordId: record.id,
        userId: userId,
        localPath: _imageFile!.path,
        takenAt: now,
      );

      ref.invalidate(todayProgressProvider);
      ref.invalidate(recordsByDateProvider);

      if (mounted) {
        context.pop();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('拍照打卡')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: 280,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 280,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '点击选择照片',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新选择'),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _imageFile == null || _isSaving ? null : _save,
              icon: const Icon(Icons.check),
              label: const Text('确认打卡'),
            ),
          ],
        ),
      ),
    );
  }
}

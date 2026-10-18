import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';

enum DeltaConflictSide { local, remote }

class DeltaConflictFieldChoice {
  const DeltaConflictFieldChoice({required this.group, required this.side});

  final TransactionConflictFieldGroup group;
  final DeltaConflictSide side;
}

class DeltaConflictResolutionDraft {
  const DeltaConflictResolutionDraft({
    required this.conflict,
    required this.choices,
  });

  final DeltaDetectedConflict conflict;
  final List<DeltaConflictFieldChoice> choices;

  DeltaConflictSide choiceFor(TransactionConflictFieldGroup group) {
    for (final choice in choices) {
      if (choice.group == group) {
        return choice.side;
      }
    }
    return DeltaConflictSide.local;
  }
}

class DeltaConflictResolver {
  const DeltaConflictResolver();

  Map<String, Object?> mergeTransactionFields(
    DeltaConflictResolutionDraft draft,
  ) {
    final merged = <String, Object?>{...?draft.conflict.localRecord?.snapshot};
    final remoteFields = draft.conflict.remoteChange.changedFields;

    for (final group in draft.conflict.fieldGroups) {
      if (draft.choiceFor(group) != DeltaConflictSide.remote) {
        continue;
      }

      for (final entry in remoteFields.entries) {
        if (const TransactionConflictFieldClassifier()
            .classify([entry.key])
            .contains(group)) {
          merged[entry.key] = entry.value;
        }
      }
    }

    return merged;
  }
}

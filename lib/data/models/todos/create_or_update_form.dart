import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_or_update_form.freezed.dart';

@freezed
class CreateOrUpdateForm with _$CreateOrUpdateForm {
  const factory CreateOrUpdateForm({
    String? serialNum,
    String? name,
    String? description,
  }) = _CreateOrUpdateForm;

  factory CreateOrUpdateForm.fromJson(Map<String, dynamic> json) =>
      _$CreateOrUpdateFormFromJson(json);

  String? validate() {
    if (serialNum != null &&
        (serialNum!.length < 32 || serialNum!.length > 38)) {
      return 'serial_num must be between 32 and 38 characters';
    }
    if (name != null && name!.length > 100) {
      return 'name must be between 0 and 100 characters';
    }
    if (description != null && description!.length > 1000) {
      return 'description must be at most 1000 characters';
    }
    return null;
  }
}
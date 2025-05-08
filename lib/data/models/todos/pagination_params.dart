import 'package:freezed_annotation/freezed_annotation.dart';

part 'pagination_params.freezed.dart';

@freezed
class PaginationParams with _$PaginationParams {
  const factory PaginationParams({required int? page, required int? pageSize}) =
      _PaginationParams;

  factory PaginationParams.fromJson(Map<String, dynamic> json) =>
      _$PaginationParamsFromJson(json);

  String? validate() {
    if (page == null) return 'page is required';
    if (page! < 1) return 'page must be greater than or equal to 1';
    if (pageSize == null) return 'page_size is required';
    if (pageSize! < 1) return 'page_size must be greater than or equal to 1';
    return null;
  }
}
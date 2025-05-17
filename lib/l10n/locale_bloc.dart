import 'package:flutter/material.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

// Define the LocaleState class
class LocaleState {
  final Locale locale;

  LocaleState(this.locale);

  // Optional: Add copyWith for easier state updates
  LocaleState copyWith({Locale? locale}) {
    return LocaleState(locale ?? this.locale);
  }
}

// Define the LocaleEvent class
abstract class LocaleEvent {}

class ChangeLocale extends LocaleEvent {
  final Locale locale;

  ChangeLocale(this.locale);
}

// LocaleBloc extending HydratedBloc for persistence
class LocaleBloc extends HydratedBloc<LocaleEvent, LocaleState> {
  LocaleBloc() : super(LocaleState(const Locale('en', ''))) {
    on<ChangeLocale>((event, emit) {
      emit(LocaleState(event.locale));
    });
  }

  // Deserialize the state from JSON
  @override
  LocaleState? fromJson(Map<String, dynamic> json) {
    try {
      final languageCode = json['languageCode'] as String?;
      final countryCode = json['countryCode'] as String?;
      if (languageCode != null) {
        return LocaleState(Locale(languageCode, countryCode ?? ''));
      }
      return null; // Return null if deserialization fails
    } catch (_) {
      return null; // Handle any errors by returning null
    }
  }

  // Serialize the state to JSON
  @override
  Map<String, dynamic>? toJson(LocaleState state) {
    try {
      return {
        'languageCode': state.locale.languageCode,
        'countryCode': state.locale.countryCode ?? '',
      };
    } catch (_) {
      return null; // Handle any errors by returning null
    }
  }
}

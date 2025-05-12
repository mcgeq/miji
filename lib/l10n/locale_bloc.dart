import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocaleState {
  final Locale locale;

  LocaleState(this.locale);
}

abstract class LocaleEvent {}

class ChangeLocale extends LocaleEvent {
  final Locale locale;

  ChangeLocale(this.locale);
}

class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  LocaleBloc() : super(LocaleState(const Locale('en', ''))) {
    on<ChangeLocale>((event, emit) {
      emit(LocaleState(event.locale));
    });
  }
}
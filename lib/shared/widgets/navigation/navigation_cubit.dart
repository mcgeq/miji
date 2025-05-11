import 'package:flutter_bloc/flutter_bloc.dart';

class NavigationState {
  final int index;

  NavigationState(this.index);
}

class NavigationCubit extends Cubit<NavigationState> {
  NavigationCubit() : super(NavigationState(0));

  void setIndex(int index) {
    emit(NavigationState(index));
  }
}
import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeLoadRequested extends HomeEvent {
  final bool forceRefresh;
  final String? mood;
  const HomeLoadRequested({this.forceRefresh = false, this.mood});
  
  @override
  List<Object?> get props => [forceRefresh, mood];
}

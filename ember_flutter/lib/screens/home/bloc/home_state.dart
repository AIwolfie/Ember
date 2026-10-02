import 'package:equatable/equatable.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeLoading extends HomeState {}

class HomeAILoading extends HomeState {
  final String targetMood;
  const HomeAILoading(this.targetMood);

  @override
  List<Object?> get props => [targetMood];
}

class HomeLoaded extends HomeState {
  final List<Map<String, dynamic>> sections;
  final String? activeMood;
  final bool isColdStart;
  const HomeLoaded(this.sections, {this.activeMood, this.isColdStart = false});

  @override
  List<Object?> get props => [sections, activeMood, isColdStart];
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}

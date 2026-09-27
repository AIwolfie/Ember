import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/python_service.dart';
import '../../services/database_service.dart';
import '../../utils/result.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeLoading()) {
    on<HomeLoadRequested>(_onLoadRequested);
  }

  Future<void> _onLoadRequested(HomeLoadRequested event, Emitter<HomeState> emit) async {
    if (state is! HomeLoaded) {
      emit(HomeLoading());
    }
    
    try {
      if (event.mood != null) {
        final result = await PythonService.search("${event.mood} music");
        switch (result) {
          case Success():
            if (result.data.isEmpty) {
              emit(const HomeError("No tracks found for this mood."));
            } else {
              final section = {
                "title": "${event.mood} Picks",
                "tracks": result.data,
              };
              emit(HomeLoaded([section], activeMood: event.mood));
            }
          case Failure():
            emit(HomeError(result.message));
        }
      } else {
        final recentPlays = await DatabaseService.instance.getPlayHistory();
        final recentIds = recentPlays.take(3).map((e) => e['videoId'] ?? '').where((id) => id.isNotEmpty).toList();
        
        final result = await PythonService.getHome(forceRefresh: event.forceRefresh, recentIds: recentIds);
        switch (result) {
          case Success():
            if (result.data.isEmpty) {
              emit(const HomeError("Home feed is empty."));
            } else {
              emit(HomeLoaded(result.data, activeMood: null));
            }
          case Failure():
            emit(HomeError(result.message));
        }
      }
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}

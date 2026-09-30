import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';

import 'package:ember_flutter/blocs/audio/audio_bloc.dart';
import 'package:ember_flutter/theme.dart';

void showEqualizerSheet(BuildContext context) {
  final audioBloc = context.read<AudioBloc>();
  final equalizer = audioBloc.equalizer;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: YTColors.surface.withValues(alpha: 0.85), // Glassmorphism backdrop usually applied beneath, but translucent base works
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Audio Equalizer',
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 24),
            FutureBuilder<AndroidEqualizerParameters>(
              future: equalizer.parameters,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return CircularProgressIndicator(color: YTColors.primary);

                final params = snapshot.data!;
                return StreamBuilder<bool>(
                  stream: equalizer.enabledStream,
                  builder: (context, enabledSnapshot) {
                    final isEnabled = enabledSnapshot.data ?? false;
                    return Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Enable EQ',
                            style: TextStyle(color: Colors.white),
                          ),
                          value: isEnabled,
                          activeTrackColor: YTColors.primary,
                          onChanged: (val) {
                            equalizer.setEnabled(val);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (isEnabled)
                          SizedBox(
                            height: 200,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: params.bands.map((band) {
                                return Expanded(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        child: RotatedBox(
                                          quarterTurns: 3,
                                          child: Slider(
                                            min: params.minDecibels,
                                            max: params.maxDecibels,
                                            value: band.gain,
                                            onChanged: (val) {
                                              if (isEnabled) {
                                                band.setGain(val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${(band.centerFrequency / 1000).round()}kHz',
                                        style: const TextStyle(
                                          color: YTColors.secondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        if (!isEnabled)
                          const SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                'Equalizer disabled',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

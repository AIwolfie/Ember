import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:ember_flutter/blocs/storage/storage_bloc.dart';
import 'package:ember_flutter/blocs/storage/storage_event.dart';
import 'package:ember_flutter/blocs/storage/storage_state.dart';
import 'package:ember_flutter/theme.dart';

void showPlaylistSheet(BuildContext context, {Map<String, String>? track}) {
  final storageBloc = context.read<StorageBloc>();
  final ctrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    backgroundColor: YTColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 24,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              track == null ? 'Create Playlist' : 'Add to Playlist',
              style: TextStyle(
                color: YTColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    style: TextStyle(color: YTColors.primary),
                    decoration: InputDecoration(
                      hintText: 'New playlist...',
                      hintStyle: const TextStyle(color: YTColors.secondary),
                      filled: true,
                      fillColor: YTColors.surfaceLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (name) {
                      if (name.trim().isNotEmpty) {
                        storageBloc.add(StorageCreatePlaylist(name.trim()));
                        if (track != null) {
                          storageBloc.add(
                            StorageAddToPlaylist(
                              name: name.trim(),
                              track: track,
                            ),
                          );
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Created playlist "${name.trim()}"',
                              style: TextStyle(color: YTColors.primary),
                            ),
                            backgroundColor: YTColors.surfaceLight,
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.add_circle,
                    color: YTColors.primary,
                    size: 36,
                  ),
                  onPressed: () {
                    final name = ctrl.text.trim();
                    if (name.isNotEmpty) {
                      storageBloc.add(StorageCreatePlaylist(name));
                      if (track != null) {
                        storageBloc.add(
                          StorageAddToPlaylist(name: name, track: track),
                        );
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Created playlist "$name"',
                            style: TextStyle(color: YTColors.primary),
                          ),
                          backgroundColor: YTColors.surfaceLight,
                        ),
                      );
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            BlocBuilder<StorageBloc, StorageState>(
              builder: (context, state) {
                if (state.playlists.isNotEmpty) {
                  const Divider(color: YTColors.divider, height: 1);
                }
                if (state.playlists.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      "No custom playlists yet.",
                      style: TextStyle(color: YTColors.secondary),
                    ),
                  );
                }

                return Column(
                  children: state.playlists.keys
                      .map(
                        (pName) => ListTile(
                          leading: Icon(
                            Icons.queue_music,
                            color: YTColors.primary,
                          ),
                          title: Text(
                            pName,
                            style: TextStyle(
                              color: YTColors.primary,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () {
                            if (track != null) {
                              storageBloc.add(
                                StorageAddToPlaylist(name: pName, track: track),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added to $pName',
                                    style: TextStyle(color: YTColors.primary),
                                  ),
                                  backgroundColor: YTColors.surfaceLight,
                                ),
                              );
                            }
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}

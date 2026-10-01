import 'package:flutter/material.dart';
import 'package:ember_flutter/theme.dart';

class EmberAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const EmberAppBar({
    super.key,
    this.title,
    this.titleText,
    this.actions,
    this.leading,
    this.centerTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title ??
          (titleText != null
              ? Text(
                  titleText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                )
              : null),
      centerTitle: centerTitle,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: leading ?? const BackButton(color: Colors.white),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class EmberSliverAppBar extends StatelessWidget {
  final Widget? title;
  final String? titleText;
  final List<Widget>? actions;
  final Widget? leading;
  final bool floating;
  final bool pinned;
  final bool centerTitle;
  final Widget? bottom;
  final double? expandedHeight;
  final Widget? flexibleSpace;
  final double? titleSpacing;
  final double? toolbarHeight;

  const EmberSliverAppBar({
    super.key,
    this.title,
    this.titleText,
    this.actions,
    this.leading,
    this.floating = true,
    this.pinned = false,
    this.centerTitle = false,
    this.bottom,
    this.expandedHeight,
    this.flexibleSpace,
    this.titleSpacing,
    this.toolbarHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      title: title ??
          (titleText != null
              ? Text(
                  titleText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  ),
                )
              : null),
      centerTitle: centerTitle,
      backgroundColor: YTColors.background,
      elevation: 0,
      floating: floating,
      pinned: pinned,
      expandedHeight: expandedHeight,
      flexibleSpace: flexibleSpace,
      titleSpacing: titleSpacing,
      toolbarHeight: toolbarHeight ?? kToolbarHeight,
      leading: leading ?? const BackButton(color: Colors.white),
      actions: actions,
      bottom: bottom != null ? PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: bottom!,
      ) : null,
    );
  }
}

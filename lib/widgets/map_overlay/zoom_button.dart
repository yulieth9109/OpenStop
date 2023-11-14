import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ZoomButton extends StatelessWidget {
  final void Function()? onZoomInPressed;
  final void Function()? onZoomOutPressed;

  const ZoomButton({
    Key? key,
    this.onZoomInPressed,
    this.onZoomOutPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appLocale = AppLocalizations.of(context)!;
    return Material(
      elevation: Theme.of(context).floatingActionButtonTheme.elevation ?? 4.0,
      shape: Theme.of(context).floatingActionButtonTheme.shape,
      color: Theme.of(context).colorScheme.primaryContainer,
      shadowColor: Theme.of(context).colorScheme.shadow,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Semantics(
            label: appLocale.semanticsZoomInButtonLabel,
            child: SizedBox(
              height: (Theme.of(context).floatingActionButtonTheme.smallSizeConstraints?.minHeight ?? 48.0) * 1.25,
              width: Theme.of(context).floatingActionButtonTheme.smallSizeConstraints?.minWidth ?? 48.0,
              child: InkWell(
                onTap: onZoomInPressed,
                child: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
          Container(
            height: 1,
            width: Theme.of(context).floatingActionButtonTheme.smallSizeConstraints?.minWidth,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.1),
          ),
          Semantics(
            label: appLocale.semanticsZoomOutButtonLabel,
            child: SizedBox(
              height: (Theme.of(context).floatingActionButtonTheme.smallSizeConstraints?.minHeight ?? 48.0) * 1.25,
              width: Theme.of(context).floatingActionButtonTheme.smallSizeConstraints?.minWidth ?? 48.0,
              child: InkWell(
                onTap: onZoomOutPressed,
                child: Icon(
                  Icons.remove,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

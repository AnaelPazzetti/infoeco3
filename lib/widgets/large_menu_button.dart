import 'package:flutter/material.dart';

/// A large, rounded button for use in the main menu, matching the 'Perfil' button style.
class LargeMenuButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;

  const LargeMenuButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ButtonStyle(
        minimumSize: MaterialStateProperty.all(const Size(300, 75)),
        backgroundColor: MaterialStateProperty.all(backgroundColor),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      child: child,
    );
  }
}

import 'package:flutter/material.dart';

/// Used for SnackBars from code that runs outside a route (e.g. OAuth method channel).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

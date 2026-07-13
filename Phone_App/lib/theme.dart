import 'package:flutter/material.dart';

class AppColors {
  static const black = Color(0xFF000000);
  static const white = Color(0xFFFFFFFF);
  static const white90 = Color(0xE5FFFFFF);
  static const white60 = Color(0x99FFFFFF);
  static const white40 = Color(0x66FFFFFF);
  static const white30 = Color(0x4DFFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white10 = Color(0x1AFFFFFF);
  static const white08 = Color(0x14FFFFFF);
  static const white05 = Color(0x0DFFFFFF);

  // Glass-specific
  static const glassFill = Color(0x0FFFFFFF); // ~6% white
  static const glassBorder = Color(0x1FFFFFFF); // ~12% white
  static const glassHighlight = Color(0x14FFFFFF); // ~8% white
  static const glassGlow = Color(0x0AFFFFFF); // ~4% white
}

/// Liquid glass decoration presets for the dashboard UI.
class GlassDecoration {
  GlassDecoration._();

  static const Curve motionCurve = Curves.easeOutCubic;
  static const Duration motionFast = Duration(milliseconds: 160);
  static const Duration motionMedium = Duration(milliseconds: 260);

  static List<BoxShadow> depth({
    bool isActive = false,
    bool pressed = false,
    Color color = AppColors.white,
  }) {
    if (pressed) {
      return [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.42),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: color.withValues(alpha: isActive ? 0.12 : 0.05),
          blurRadius: 16,
          spreadRadius: -2,
        ),
      ];
    }

    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.55),
        blurRadius: isActive ? 28 : 18,
        offset: const Offset(0, 14),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.38),
        blurRadius: isActive ? 10 : 7,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: color.withValues(alpha: isActive ? 0.11 : 0.045),
        blurRadius: isActive ? 30 : 18,
        spreadRadius: isActive ? 1 : -2,
      ),
    ];
  }

  /// Standard glass panel — used for relay buttons, slider backgrounds.
  static BoxDecoration panel({
    double borderRadius = 0,
    bool isActive = false,
    bool pressed = false,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.zero,
      color: pressed
          ? AppColors.white05
          : isActive
              ? AppColors.white10
              : AppColors.glassFill,
      border: Border.all(
        color: pressed
            ? AppColors.white20
            : isActive
                ? AppColors.white30
                : AppColors.glassBorder,
        width: 0.5,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          isActive ? AppColors.white20 : AppColors.glassHighlight,
          Colors.transparent,
          isActive ? AppColors.white08 : AppColors.glassGlow,
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      boxShadow: depth(isActive: isActive, pressed: pressed),
    );
  }

  /// Subtle glass for sliders / bars.
  static BoxDecoration bar({double borderRadius = 0}) {
    return BoxDecoration(
      borderRadius: BorderRadius.zero,
      color: AppColors.glassFill,
      border: Border.all(color: AppColors.glassBorder, width: 0.5),
      boxShadow: depth().map((shadow) {
        return BoxShadow(
          color: shadow.color.withValues(alpha: 0.18),
          blurRadius: shadow.blurRadius * 0.7,
          spreadRadius: shadow.spreadRadius,
          offset: shadow.offset,
        );
      }).toList(),
    );
  }

  /// Glow effect box shadow for active states.
  static List<BoxShadow> glow(
      {Color color = AppColors.white, double blur = 12}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.12),
        blurRadius: blur,
        spreadRadius: 1,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.32),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ];
  }
}

class AppSpace {
  static const double unit = 8;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 24);
}

class AppBorders {
  static const thinBorder = BorderSide(color: AppColors.white20, width: 1);
  static const activeBorder = BorderSide(color: AppColors.white60, width: 1);
  static const brightBorder = BorderSide(color: AppColors.white90, width: 1);
}

class AppTextStyles {
  static TextStyle displayXL({Color color = AppColors.white90}) =>
      const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 72,
        fontWeight: FontWeight.w200,
        letterSpacing: -2.5,
        height: 1,
      ).copyWith(color: color);

  static TextStyle displayLG({Color color = AppColors.white90}) =>
      const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 48,
        fontWeight: FontWeight.w200,
        letterSpacing: -1.5,
        height: 1,
      ).copyWith(color: color);

  static TextStyle headlineLG({Color color = AppColors.white90}) =>
      const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 32,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.5,
      ).copyWith(color: color);

  static TextStyle headlineMD({Color color = AppColors.white90}) =>
      const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 24,
        fontWeight: FontWeight.w300,
        letterSpacing: -0.3,
      ).copyWith(color: color);

  static TextStyle bodyLG({Color color = AppColors.white90}) => const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ).copyWith(color: color);

  static TextStyle labelLG({Color color = AppColors.white60}) =>
      const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 3.5,
      ).copyWith(color: color);

  static TextStyle labelSM({Color color = AppColors.white40}) =>
      const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 9,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.5,
      ).copyWith(color: color);

  static TextStyle tabular(TextStyle style) => style.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

const String kUiVersion = 'V2.4.1';
const String kUiSignature = '$kUiVersion // TERMINAL_UI';

class AppTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.black,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.white,
          onPrimary: AppColors.black,
          secondary: AppColors.white60,
          onSecondary: AppColors.black,
          surface: AppColors.black,
          onSurface: AppColors.white90,
          error: AppColors.white60,
          onError: AppColors.black,
        ),
        fontFamily: 'Manrope',
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Manrope',
              bodyColor: AppColors.white90,
              displayColor: AppColors.white90,
            ),
        iconTheme: const IconThemeData(color: AppColors.white60),
        dividerColor: AppColors.white20,
        dividerTheme: const DividerThemeData(
          color: AppColors.white20,
          thickness: 1,
          space: 1,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.black,
          contentTextStyle: AppTextStyles.labelLG(color: AppColors.white90),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: AppBorders.activeBorder,
          ),
          behavior: SnackBarBehavior.floating,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeSlideTransitionBuilder(),
            TargetPlatform.iOS: _FadeSlideTransitionBuilder(),
            TargetPlatform.linux: _FadeSlideTransitionBuilder(),
            TargetPlatform.macOS: _FadeSlideTransitionBuilder(),
            TargetPlatform.windows: _FadeSlideTransitionBuilder(),
          },
        ),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          color: AppColors.black,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: InputBorder.none,
          focusedBorder: const UnderlineInputBorder(
            borderSide: AppBorders.activeBorder,
          ),
          enabledBorder: const UnderlineInputBorder(
            borderSide: AppBorders.thinBorder,
          ),
          hintStyle: AppTextStyles.bodyLG(color: AppColors.white20),
          labelStyle: AppTextStyles.labelLG(),
        ),
        sliderTheme: const SliderThemeData(
          trackHeight: 1,
          activeTrackColor: AppColors.white90,
          inactiveTrackColor: AppColors.white20,
          thumbColor: AppColors.white90,
          overlayColor: Colors.transparent,
        ),
      );
}

Route<T> buildAppRoute<T>({
  required RouteSettings settings,
  required Widget child,
}) {
  return PageRouteBuilder<T>(
    settings: settings,
    pageBuilder: (_, __, ___) => child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, routeChild) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: routeChild,
        ),
      );
    },
  );
}

class _FadeSlideTransitionBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

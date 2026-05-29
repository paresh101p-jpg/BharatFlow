import 'package:flutter/material.dart';

class CustomWeatherIcon extends StatelessWidget {
  final String condition;
  final bool isNight;
  final double size;

  const CustomWeatherIcon({
    Key? key,
    required this.condition,
    this.isNight = false,
    this.size = 32,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: _buildIconStack(),
    );
  }

  Widget _buildIconStack() {
    final Widget sun = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFEE58), Color(0xFFFF9800)],
      ).createShader(bounds),
      child: Icon(Icons.circle, color: Colors.white, size: size * 0.7, shadows: [Shadow(color: Colors.orangeAccent.withOpacity(0.6), blurRadius: 10)]),
    );
    
    final Widget moon = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF9FA8DA), Color(0xFF3949AB)],
      ).createShader(bounds),
      child: Icon(Icons.nightlight_round, color: Colors.white, size: size * 0.65, shadows: [Shadow(color: Colors.indigo.withOpacity(0.4), blurRadius: 8)]),
    );
    
    final Widget baseCloud = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white, Color(0xFFDDE4F0)],
      ).createShader(bounds),
      child: Icon(
        Icons.cloud,
        color: Colors.white,
        size: size * 0.85,
        shadows: const [Shadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
      ),
    );

    final Widget darkCloud = ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFB0BEC5), Color(0xFF546E7A)],
      ).createShader(bounds),
      child: Icon(
        Icons.cloud,
        color: Colors.white,
        size: size * 0.85,
        shadows: const [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
      ),
    );

    final celestial = isNight ? moon : sun;

    switch (condition) {
      case 'Clear':
        return Stack(
          alignment: Alignment.center,
          children: [
            if (!isNight) Icon(Icons.wb_sunny_rounded, color: Colors.amber.withOpacity(0.3), size: size),
            celestial,
          ],
        );

      case 'PartlyCloudy':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 0, right: 0, child: celestial),
            Positioned(bottom: 0, left: 0, child: baseCloud),
          ],
        );

      case 'Clouds':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 4, right: 2, child: Icon(Icons.cloud, color: Colors.grey.shade300, size: size * 0.6)),
            Positioned(bottom: 0, left: 0, child: baseCloud),
          ],
        );

      case 'Foggy':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 2, child: baseCloud),
            Positioned(bottom: 4, child: Icon(Icons.dehaze_rounded, color: Colors.white, size: size * 0.6)),
          ],
        );

      case 'LightRain':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 0, right: 0, child: celestial),
            Positioned(bottom: 2, left: size * 0.2, child: Icon(Icons.water_drop, color: Colors.lightBlueAccent, size: size * 0.3)),
            Positioned(top: 4, left: 0, child: baseCloud),
          ],
        );

      case 'Rain':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(bottom: 0, left: size * 0.2, child: Icon(Icons.water_drop, color: Colors.blue, size: size * 0.3)),
            Positioned(bottom: 0, right: size * 0.2, child: Icon(Icons.water_drop, color: Colors.blue, size: size * 0.3)),
            Positioned(top: 0, child: darkCloud),
          ],
        );

      case 'HeavyRain':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(bottom: 0, left: size * 0.1, child: Icon(Icons.water_drop, color: Colors.indigoAccent, size: size * 0.3)),
            Positioned(bottom: 0, child: Icon(Icons.water_drop, color: Colors.blue, size: size * 0.35)),
            Positioned(bottom: 0, right: size * 0.1, child: Icon(Icons.water_drop, color: Colors.indigoAccent, size: size * 0.3)),
            Positioned(top: 0, child: darkCloud),
          ],
        );

      case 'Thunderstorm':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(bottom: 2, right: size * 0.3, child: Icon(Icons.water_drop, color: Colors.blue, size: size * 0.3)),
            Positioned(bottom: 0, left: size * 0.3, child: Icon(Icons.flash_on, color: Colors.amber, size: size * 0.45)),
            Positioned(top: 0, child: darkCloud),
          ],
        );

      case 'Snow':
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned(bottom: 0, left: size * 0.2, child: Icon(Icons.ac_unit, color: Colors.cyanAccent, size: size * 0.3)),
            Positioned(bottom: 0, right: size * 0.2, child: Icon(Icons.ac_unit, color: Colors.cyanAccent, size: size * 0.3)),
            Positioned(top: 0, child: baseCloud),
          ],
        );

      default:
        return celestial;
    }
  }
}

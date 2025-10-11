import 'package:flutter/material.dart';
import 'package:sigma/admin/auth/introduction/introduction_screen.dart';
import 'package:sigma/admin/auth/login/login_screen.dart';
import 'package:sigma/service/pref_handler.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_image.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // Tunggu build selesai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateAfterSplash();
    });
  }

  void _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 2));
    final token = await PreferenceHandler.getToken();
    final lookWelcoming = await PreferenceHandler.getLookWelcoming();

    if (!mounted) return;

    if (lookWelcoming == false) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const IntroScreen()),
      );
    } else if (token != null && token.isNotEmpty) {
     Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.backgroundColor,
      body: Center(
        child: Image.asset(
          AppImage.logo,
          height: MediaQuery.of(context).size.width * 0.8,
          width: MediaQuery.of(context).size.width * 0.8,
        ),
      ),
    );
  }
}

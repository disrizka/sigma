import 'package:flutter/material.dart';
import 'package:sigma/admin/auth/welcome/welcome_screen.dart';
import 'package:sigma/service/pref_handler.dart';
import 'package:sigma/utils/app_color.dart';
import 'package:sigma/utils/app_font.dart';
import 'package:sigma/utils/app_image.dart';
import 'package:introduction_screen/introduction_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  _IntroScreenState createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: AppColor.backgroundColor,
      key: introKey,
      pages: [
        PageViewModel(
          titleWidget: SizedBox.shrink(),
          bodyWidget: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 120),
                Image.asset(AppImage.intro1),
                SizedBox(height: 60),
                Text(
                  "Data Payroll\n Menjadi Aman,\n mudah dan \ntrasnparan",
                  textAlign: TextAlign.center,
                  style: PoppinsTextStyle.bold.copyWith(
                    fontSize: 30,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        PageViewModel(
          titleWidget: SizedBox.shrink(),
          bodyWidget: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 150),
              Text(
                "Ajukan izin dan cuti\n langsung, praktis\n tanpa ribet.",
                textAlign: TextAlign.center,
                style: PoppinsTextStyle.bold.copyWith(
                  fontSize: 30,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 30),
              Image.asset(AppImage.intro2),
              SizedBox(height: 20),
            ],
          ),
        ),
        PageViewModel(
          titleWidget: SizedBox.shrink(),
          bodyWidget: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 150),
              Image.asset(AppImage.intro3),
              SizedBox(height: 60),
              Text(
                "Absen Lebih\n Akurat",
                textAlign: TextAlign.center,
                style: PoppinsTextStyle.bold.copyWith(
                  fontSize: 30,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
      showNextButton: false,
      showDoneButton: true,
      done: Text(
        "Selesai",
        style: PoppinsTextStyle.bold.copyWith(
          fontSize: 15,
          color: AppColor.primaryColor,
        ),
      ),
      onDone: () async {
        // Simpan bahwa user sudah lihat intro
        await PreferenceHandler.saveLookWelcoming(true);

        // Arahkan ke WelcomeScreen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        );
      },
      dotsDecorator: DotsDecorator(
        size: const Size(10.0, 10.0),
        color: Colors.grey,
        activeColor: AppColor.primaryColor,
        activeSize: const Size(15.0, 10.0),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
      ),
    );
  }
}

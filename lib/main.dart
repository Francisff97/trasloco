import 'package:material_ui/material_ui.dart';

import 'src/brand.dart';
import 'src/home_page.dart';

void main() {
  runApp(const TraslocoApp());
}

class TraslocoApp extends StatelessWidget {
  const TraslocoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trasloco',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomePage(),
    );
  }
}

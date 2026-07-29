import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/home_screen.dart';
import 'services/local_inference_service.dart';
import 'services/mesh_client_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ResilienceMeshApp());
}

class ResilienceMeshApp extends StatelessWidget {
  const ResilienceMeshApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (_) => LocalInferenceService()),
        RepositoryProvider(create: (_) => MeshClientService()),
      ],
      child: MaterialApp(
        title: 'ResilienceMesh',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

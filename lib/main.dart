import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:arise_application/auth_servers/auth_gate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:arise_application/cubits/profiles/profiles_cubit.dart';
const supabaseUrl = 'https://zpnykmhpzagnnmwhhjcp.supabase.co';
const supabasePublishableKey = 'sb_publishable_yRdFl4KBJXqTqmTzawMISQ_TaIS5Npl';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: supabaseUrl, 
    publishableKey: supabasePublishableKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
   const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfilesCubit>(
      create: (context) => ProfilesCubit(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'ARISE',
        home: AuthGate(),
      )
    );
  }
}
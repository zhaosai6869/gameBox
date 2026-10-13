import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'games/bsy_screen.dart';
import 'games/jcc_screen.dart';

/// 路由入口壳：按当前游戏分发到各自独立设计的页面。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(filterProvider.select((f) => f.game));
    return switch (game) {
      'bsy' => const BsyScreen(),
      _ => const JccScreen(),
    };
  }
}

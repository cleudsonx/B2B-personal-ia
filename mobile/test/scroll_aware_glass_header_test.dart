import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ia/core/widgets/meta_components.dart';
import 'package:personal_ia/core/widgets/scroll_aware_glass_header.dart';

void main() {
  testWidgets('ScrollAwareGlassHeader renders titleText, leading, actions and bottom',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: ScrollAwareGlassHeader(
            leading: const Icon(Icons.fitness_center_rounded),
            titleText: 'Painel de Treinos',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () {},
              ),
            ],
            bottom: const Text('Barra de Pesquisa e Filtros'),
          ),
        ),
      ),
    );

    expect(find.text('Painel de Treinos'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    expect(find.text('Barra de Pesquisa e Filtros'), findsOneWidget);
  });

  testWidgets('ScrollAwareGlassHeader interpolates blur and background based on scrollOffset',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. Estado inicial (scrollOffset: 0.0)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScrollAwareGlassHeader(
            titleText: 'Feed de Alunos',
            scrollOffset: 0.0,
            elevationThreshold: 30.0,
          ),
        ),
      ),
    );

    final initialBackdrop = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    final initialFilter = initialBackdrop.filter;
    // O blur inicial com offset 0 deve ser zero
    expect(initialFilter.toString(), contains('0.0, 0.0'));

    // 2. Estado rolado (scrollOffset: 30.0 -> progresso máximo)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScrollAwareGlassHeader(
            titleText: 'Feed de Alunos',
            scrollOffset: 30.0,
            elevationThreshold: 30.0,
            maxBlur: 18.0,
          ),
        ),
      ),
    );

    final scrolledBackdrop = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    final scrolledFilter = scrolledBackdrop.filter;
    expect(scrolledFilter.toString(), contains('18.0, 18.0'));
  });

  testWidgets('ScrollAwareGlassHeader reacts dynamically to ScrollController scrolling',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView.builder(
                controller: scrollController,
                itemCount: 50,
                itemBuilder: (ctx, index) => ListTile(
                  title: Text('Item $index'),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ScrollAwareGlassHeader(
                  titleText: 'Alunos do Treinador',
                  scrollController: scrollController,
                  elevationThreshold: 40.0,
                  maxBlur: 16.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Alunos do Treinador'), findsOneWidget);

    // Rola o ListView em 80 pixels para baixo
    scrollController.jumpTo(80.0);
    await tester.pumpAndSettle();

    final scrolledBackdrop = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(scrolledBackdrop.filter.toString(), contains('16.0, 16.0'));
  });

  testWidgets('SliverScrollAwareGlassHeader integrates into CustomScrollView',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              const SliverScrollAwareGlassHeader(
                titleText: 'Cockpit de Prescrição',
                pinned: true,
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ListTile(title: Text('Ficha #$index')),
                  childCount: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Cockpit de Prescrição'), findsOneWidget);
    expect(find.text('Ficha #0'), findsOneWidget);

    // Rola o CustomScrollView
    await tester.drag(find.text('Ficha #2'), const Offset(0, -200));
    await tester.pumpAndSettle();

    // Título continua visível (pinned: true)
    expect(find.text('Cockpit de Prescrição'), findsOneWidget);
  });
}


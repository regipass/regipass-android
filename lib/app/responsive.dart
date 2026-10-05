/// İP-T2: tablet (iPad / Android tablet) uyumu.
///
/// Telefon için tasarlanmış ekranlar geniş ekranda iki şekilde düzenlenir:
///  - Okuma/form ekranları ortada sabit genişlikte durur ([ReadableScaffold]).
///  - Kart listeleri (Keşfet, organizatör etkinlikleri) 2–3 sütun olur
///    ([AdaptiveCardList]).
/// Telefonda (genişlik < [kTabletBreakpoint]) hiçbir şey değişmez.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Bu genişlikten itibaren tablet düzeni (mantıksal piksel).
const double kTabletBreakpoint = 700;

/// Okuma/form ekranlarının en fazla genişliği.
const double kReadableMaxWidth = 760;

/// Giriş/kayıt gibi dar formların en fazla genişliği.
const double kNarrowMaxWidth = 540;

/// Kart ızgarasının toplam en fazla genişliği.
const double kGridMaxWidth = 1180;

bool isTabletWidth(double width) => width >= kTabletBreakpoint;

bool isTablet(BuildContext context) =>
    isTabletWidth(MediaQuery.sizeOf(context).width);

/// Kart listesinde sütun sayısı.
int cardColumnsFor(double width) {
  if (width >= 1100) return 3;
  if (width >= kTabletBreakpoint) return 2;
  return 1;
}

/// Geniş ekranda içeriği ortalayıp en fazla [maxWidth] genişlikte tutar.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = kReadableMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Gövdesi geniş ekranda ortada sabit genişlikte duran [Scaffold].
/// Uygulama çubuğu (AppBar) tam genişlikte kalır.
class ReadableScaffold extends Scaffold {
  ReadableScaffold({
    super.key,
    super.appBar,
    Widget? body,
    super.floatingActionButton,
    super.floatingActionButtonLocation,
    super.bottomNavigationBar,
    super.bottomSheet,
    super.backgroundColor,
    super.resizeToAvoidBottomInset,
    super.extendBody,
    super.extendBodyBehindAppBar,
    super.drawer,
    super.endDrawer,
    super.persistentFooterButtons,
    super.primary,
    double maxWidth = kReadableMaxWidth,
  }) : super(
         body: body == null
             ? null
             : ReadableWidth(maxWidth: maxWidth, child: body),
       );
}

/// Giriş/kayıt gibi dar formlar için ([kNarrowMaxWidth]).
class NarrowScaffold extends ReadableScaffold {
  NarrowScaffold({
    super.key,
    super.appBar,
    super.body,
    super.floatingActionButton,
    super.bottomNavigationBar,
    super.bottomSheet,
    super.backgroundColor,
    super.resizeToAvoidBottomInset,
    super.extendBodyBehindAppBar,
  }) : super(maxWidth: kNarrowMaxWidth);
}

/// Başlık + kart listesi. Telefonda tek sütun (eskisi gibi), tablette 2–3
/// sütunlu ızgara; başlık ortada okunur genişlikte kalır.
class AdaptiveCardList extends StatelessWidget {
  const AdaptiveCardList({
    super.key,
    this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 32),
    this.spacing = 16,
    this.physics,
  });

  final Widget? header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;
  final double spacing;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int cols = cardColumnsFor(constraints.maxWidth);
        final int headerCount = header == null ? 0 : 1;
        if (cols == 1) {
          return ListView.separated(
            physics: physics,
            padding: padding,
            itemCount: itemCount + headerCount,
            separatorBuilder: (_, _) => SizedBox(height: spacing),
            itemBuilder: (BuildContext context, int index) {
              if (headerCount == 1 && index == 0) return header!;
              return itemBuilder(context, index - headerCount);
            },
          );
        }
        // Geniş ekran: kenarlarda boşluk bırakıp içeriği ortala.
        final double side = math.max(
          padding.left,
          (constraints.maxWidth - kGridMaxWidth) / 2,
        );
        final int rows = (itemCount / cols).ceil();
        return ListView.builder(
          physics: physics,
          padding: EdgeInsets.fromLTRB(
            side,
            padding.top + 8,
            side,
            padding.bottom,
          ),
          itemCount: rows + headerCount,
          itemBuilder: (BuildContext context, int index) {
            if (headerCount == 1 && index == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: spacing),
                child: ReadableWidth(child: header!),
              );
            }
            final int row = index - headerCount;
            return Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int c = 0; c < cols; c++) ...<Widget>[
                    if (c > 0) SizedBox(width: spacing),
                    Expanded(
                      child: row * cols + c < itemCount
                          ? itemBuilder(context, row * cols + c)
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Alt gezinme çubuğundaki sekmeleri geniş ekranda ortada toplar.
double navBarSideInset(BuildContext context) =>
    math.max(0, (MediaQuery.sizeOf(context).width - 640) / 2);

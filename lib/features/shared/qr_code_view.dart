import 'package:flutter/material.dart';

import '../../app/demo_mode.dart';
import '../../domain/checkin_qr.dart';

/// QR'ı cihazda çizen kutu (İP-O / O3).
///
/// Ağ gerekmez: bilet ve oturum QR'ı internet yokken de görünür, içerik
/// üçüncü tarafa gitmez. Zemin her zaman beyazdır (koyu modda da) ve
/// [kQrQuietZone] modül sessiz alan kutunun içinde bırakılır.
class QrCodeView extends StatelessWidget {
  const QrCodeView({required this.data, this.size = 260, super.key});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Ekran görüntüsü kipinde (yalnız demo) QR herkese regipass.com açar.
    final String shown = kShotsMode ? kShotsQrData : data;
    return RepaintBoundary(
      child: CustomPaint(
        key: ValueKey<String>(shown),
        size: Size.square(size),
        painter: QrMatrixPainter(buildQrMatrix(shown)),
      ),
    );
  }
}

class QrMatrixPainter extends CustomPainter {
  QrMatrixPainter(this.matrix);

  final List<List<bool>> matrix;

  @override
  void paint(Canvas canvas, Size size) {
    final int dim = matrix.length + kQrQuietZone * 2;
    // Tam piksele yuvarlanan modül boyu: bulanık kenar kameranın işini
    // zorlaştırır. Artan pay iki yana eşit bölünür.
    final double side = size.shortestSide;
    final double cell = (side / dim).floorToDouble().clamp(1, double.infinity);
    final double offset = ((side - cell * dim) / 2).floorToDouble();

    canvas.drawRect(
      Offset.zero & Size.square(side),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final Paint dark = Paint()
      ..color = const Color(0xFF000000)
      ..isAntiAlias = false;
    for (int r = 0; r < matrix.length; r += 1) {
      final List<bool> row = matrix[r];
      int c = 0;
      while (c < row.length) {
        if (!row[c]) {
          c += 1;
          continue;
        }
        final int start = c;
        while (c < row.length && row[c]) {
          c += 1;
        }
        canvas.drawRect(
          Rect.fromLTWH(
            offset + (start + kQrQuietZone) * cell,
            offset + (r + kQrQuietZone) * cell,
            (c - start) * cell,
            cell,
          ),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(QrMatrixPainter oldDelegate) =>
      !identical(oldDelegate.matrix, matrix);
}

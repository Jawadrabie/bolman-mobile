import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/i18n/l10n.dart';
import '../../data/models.dart';
import 'formatters.dart';

const _shareQrSize = 1024.0;
const _shareQrPadding = 0.12;

int? _seatForTicket(BookingDetails booking, Ticket ticket) {
  if (ticket.type != 'individual') return null;
  final passengerId = ticket.passengerId;
  if (passengerId == null) return null;
  final idx = booking.passengers.indexWhere((p) => p.id == passengerId);
  if (idx < 0) return null;
  final seats = booking.seats.map((s) => s.seatNumber).whereType<int>().toList();
  if (idx >= seats.length) return null;
  return seats[idx];
}

String _seatsLine(L10n l10n, BookingDetails booking, Ticket ticket) {
  if (ticket.type == 'individual') {
    final seat = _seatForTicket(booking, ticket);
    if (seat == null) return '';
    return '${l10n.t('passenger.shareSeat')}: $seat';
  }
  final seats = booking.seatNumbers;
  if (seats.isEmpty) return '';
  return '${l10n.t('passenger.seatsLabel')}: ${seats.join(', ')}';
}

Future<Uint8List?> _qrPngBytes(QrPainter painter, double size) async {
  final padding = size * _shareQrPadding;
  final qrSize = size - (padding * 2);
  final picture = painter.toPicture(qrSize);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size, size),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  canvas.save();
  canvas.translate(padding, padding);
  canvas.drawPicture(picture);
  canvas.restore();
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

String _buildShareText({
  required L10n l10n,
  required Trip trip,
  required Ticket ticket,
  required BookingDetails booking,
}) {
  final lines = <String>[
    l10n.t('passenger.shareTicketHeading'),
    '',
    '${trip.originName} ${l10n.t('common.routeArrow')} ${trip.destinationName}',
    formatDateTime(trip.departure, l10n.languageCode),
  ];

  final seatsLine = _seatsLine(l10n, booking, ticket);
  if (seatsLine.isNotEmpty) lines.add(seatsLine);

  if (ticket.type == 'individual' &&
      ticket.passengerName != null &&
      ticket.passengerName!.trim().isNotEmpty) {
    lines.add('${l10n.t('passenger.sharePassenger')}: ${ticket.passengerName!.trim()}');
  }

  lines.addAll([
    '${l10n.t('passenger.shareTicketCode')}: ${ticket.code}',
    '',
    l10n.t('passenger.shareScanHint'),
  ]);

  return lines.join('\n');
}

Future<void> shareTicket({
  required BuildContext context,
  required Ticket ticket,
  required BookingDetails booking,
  Rect? sharePositionOrigin,
}) async {
  final l10n = L10n.of(context);
  final trip = booking.trip;
  if (trip == null) return;

  final qrToken = ticket.qr.trim();
  if (qrToken.isEmpty) return;

  try {
    final painter = QrPainter(
      data: qrToken,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
      // gapless: false hairlines every module apart. That survives a 1024px render but not the
      // re-compression WhatsApp/Telegram apply to a forwarded ticket, which smears the seams into
      // the dark modules and drops the decode rate.
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
    final pngBytes = await _qrPngBytes(painter, _shareQrSize);
    if (pngBytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/bolman_ticket_${ticket.code.replaceAll(RegExp(r'[^\w-]'), '_')}.png',
    );
    await file.writeAsBytes(pngBytes, flush: true);

    final text = _buildShareText(l10n: l10n, trip: trip, ticket: ticket, booking: booking);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png', name: 'bolman_ticket.png')],
        text: text,
        subject: l10n.t('passenger.shareTicketSubject'),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  } on PlatformException {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('passenger.shareFailed'))),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('passenger.shareFailed'))),
    );
  }
}

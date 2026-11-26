import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import '../models/trip.dart';
import '../utils/format.dart';
import 'file_delivery.dart';

class ExportService {
  String buildCsv(List<Trip> trips) {
    trips = _chronological(trips);
    final rows = <List<String>>[
      [
        'Date',
        'Type',
        'Kilométrage départ',
        'Kilométrage arrivée',
        'Distance',
        'Statut',
      ],
      ...trips.map(
        (trip) => [
          DateFormat('yyyy-MM-dd').format(trip.date),
          trip.category.label,
          _formatKm(trip.startKm),
          trip.endKm == null ? '' : _formatKm(trip.endKm!),
          trip.endKm == null ? '' : _formatKm(trip.distanceKm),
          trip.isCompleted ? 'Terminé' : 'En cours',
        ],
      ),
    ];

    return rows.map((row) => row.map(_escapeCsv).join(';')).join('\r\n');
  }

  Future<DeliveryResult> saveCsv(List<Trip> trips) {
    final fileName =
        'kilometrage_${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    final bytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(buildCsv(trips)),
    ]);

    return deliverFile(
      name: fileName,
      extension: 'csv',
      mimeTypeName: 'text/csv',
      mimeType: MimeType.csv,
      bytes: bytes,
    );
  }

  Future<DeliveryResult> savePdf({
    required List<Trip> trips,
    required String periodLabel,
  }) async {
    final bytes = await buildPdf(trips: trips, periodLabel: periodLabel);
    final fileName =
        'rapport_kilometrage_${DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now())}';
    return deliverFile(
      name: fileName,
      extension: 'pdf',
      mimeTypeName: 'application/pdf',
      mimeType: MimeType.pdf,
      bytes: bytes,
    );
  }

  Future<Uint8List> buildPdf({
    required List<Trip> trips,
    required String periodLabel,
  }) async {
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    trips = _chronological(trips);
    final professionalKm = _totalFor(trips, TripCategory.professional);
    final privateKm = _totalFor(trips, TripCategory.privateUse);
    final rows = trips
        .map(
          (trip) => [
            DateFormat('dd/MM/yyyy').format(trip.date),
            trip.category.label,
            formatKm(trip.startKm),
            trip.endKm == null ? '—' : formatKm(trip.endKm!),
            trip.endKm == null ? '—' : formatKm(trip.distanceKm),
            trip.isCompleted ? 'Terminé' : 'En cours',
          ],
        )
        .toList();

    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Rapport de kilométrage',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Text(periodLabel, style: const pw.TextStyle(fontSize: 13)),
          pw.SizedBox(height: 18),
          pw.Row(
            children: [
              _pdfSummary('Professionnel', professionalKm),
              pw.SizedBox(width: 16),
              _pdfSummary('Privé', privateKm),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Date',
              'Type',
              'Départ',
              'Arrivée',
              'Distance',
              'Statut',
            ],
            data: rows,
            headerStyle: pw.TextStyle(
              color: pdf.PdfColors.white,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: pdf.PdfColors.indigo700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellPadding: const pw.EdgeInsets.all(6),
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(
                color: pdf.PdfColors.grey300,
                width: 0.5,
              ),
              bottom: pw.BorderSide(color: pdf.PdfColors.grey300, width: 0.5),
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(55),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FixedColumnWidth(48),
              3: const pw.FixedColumnWidth(48),
              4: const pw.FixedColumnWidth(52),
              5: const pw.FlexColumnWidth(1),
            },
          ),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _pdfSummary(String label, double kilometers) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: pdf.PdfColors.grey100),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 5),
            pw.Text(
              '${formatKm(kilometers)} km',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  double _totalFor(List<Trip> trips, TripCategory category) {
    return trips
        .where(
          (trip) =>
              trip.category == category &&
              trip.isCompleted &&
              trip.endKm != null,
        )
        .fold(0, (total, trip) => total + trip.distanceKm);
  }

  /// Ordre chronologique : date, puis kilométrage de départ.
  List<Trip> _chronological(List<Trip> trips) {
    final sorted = [...trips];
    sorted.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.startKm.compareTo(b.startKm);
    });
    return sorted;
  }

  // CSV : virgule décimale, sans séparateur de milliers (tableur français).
  String _formatKm(double value) => formatKmPlain(value);

  String _escapeCsv(String value) {
    if (!value.contains(';') && !value.contains('"') && !value.contains('\n')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }
}

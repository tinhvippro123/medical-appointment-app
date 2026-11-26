import 'package:flutter/material.dart';

import '../../models/department.dart';
import '../../models/patient_profile.dart';
import '../doctors/search/doctor_search_page.dart';
import 'booking_logic.dart';

class BookingDatePage extends StatefulWidget {
  const BookingDatePage({
    super.key,
    required this.department,
    required this.patient,
  });

  final Department department;
  final PatientProfile patient;

  @override
  State<BookingDatePage> createState() => _BookingDatePageState();
}

class _BookingDatePageState extends State<BookingDatePage> {
  final _today = normalizeDateOnly(vietnamNow());
  late DateTime _date = _today;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chọn ngày khám')),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              title: Text(widget.department.name),
              subtitle: Text(widget.patient.displayLabel),
            ),
            CalendarDatePicker(
              initialDate: _date,
              firstDate: _today,
              lastDate: _today.add(const Duration(days: 60)),
              currentDate: _today,
              onDateChanged: (date) => setState(() => _date = date),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DoctorSearchPage(
                    browse: true,
                    department: widget.department,
                    patient: widget.patient,
                    bookingDate: _date,
                  ),
                ),
              ),
              child: const Text('Chọn bác sĩ'),
            ),
          ],
        ),
      ),
    ),
  );
}

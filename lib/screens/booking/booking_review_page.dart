import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/doctor.dart';
import '../../models/patient_profile.dart';
import 'booking_logic.dart';
import 'checkout_page.dart';

class BookingReviewPage extends StatelessWidget {
  const BookingReviewPage({
    super.key,
    required this.doctor,
    required this.patient,
    required this.date,
    required this.slot,
    required this.note,
  });

  final Doctor doctor;
  final PatientProfile patient;
  final DateTime date;
  final String slot;
  final String note;

  void _openPayment(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          doctor: doctor,
          patient: patient,
          date: date,
          slot: slot,
          note: note,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Xác nhận thông tin')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final details = _buildDetails();
                final payment = _buildPaymentCard(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAppointmentTime(),
                    const SizedBox(height: 16),
                    if (constraints.maxWidth >= 760)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: details),
                          const SizedBox(width: 16),
                          SizedBox(width: 300, child: payment),
                        ],
                      )
                    else ...[
                      details,
                      const SizedBox(height: 16),
                      payment,
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildAppointmentTime() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0x26ffffff),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.calendar_month_outlined,
            size: 28,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ngày và giờ khám',
                style: TextStyle(
                  color: Color(0xffe1efff),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDisplayDate(date),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                slot,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildDetails() => _ReviewCard(
    title: 'Thông tin lịch hẹn',
    child: Column(
      children: [
        _DetailRow(
          icon: Icons.person_outline,
          label: 'Người khám',
          value: patient.displayLabel,
        ),
        _DetailRow(
          icon: Icons.medical_services_outlined,
          label: 'Bác sĩ',
          value: doctor.fullName,
        ),
        _DetailRow(
          icon: Icons.local_hospital_outlined,
          label: 'Chuyên khoa',
          value: doctor.departmentName,
        ),
        if (doctor.roomNumber?.trim().isNotEmpty == true)
          _DetailRow(
            icon: Icons.meeting_room_outlined,
            label: 'Phòng khám',
            value: doctor.roomDetailDisplay,
          ),
        if (note.isNotEmpty)
          _DetailRow(
            icon: Icons.notes_rounded,
            label: 'Ghi chú',
            value: note,
          ),
      ],
    ),
  );

  Widget _buildPaymentCard(BuildContext context) => _ReviewCard(
    title: 'Phí khám',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          doctor.feeFormatted,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppColors.dark,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xffe2e8f0)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _openPayment(context),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
          iconAlignment: IconAlignment.end,
          label: const Text('Tiếp tục thanh toán', textAlign: TextAlign.center),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Quay lại sửa', textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xffdbe7f2)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.light,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.dark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.text,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

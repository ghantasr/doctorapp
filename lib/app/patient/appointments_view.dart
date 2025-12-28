import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'appointment_booking_view.dart';
import 'my_appointments_view.dart';

class AppointmentsView extends ConsumerStatefulWidget {
  const AppointmentsView({super.key});

  @override
  ConsumerState<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends ConsumerState<AppointmentsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
            indicatorColor: theme.colorScheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.calendar_month_rounded),
                text: 'Book Appointment',
              ),
              Tab(
                icon: Icon(Icons.event_note_rounded),
                text: 'My Appointments',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              AppointmentBookingView(),
              MyAppointmentsView(),
            ],
          ),
        ),
      ],
    );
  }
}

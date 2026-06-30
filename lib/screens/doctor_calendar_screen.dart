import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/appointment_calendar_providers.dart';
import '../providers/appointment_providers.dart';
import '../providers/service_providers.dart';
import '../providers/auth_providers.dart';
import '../data/models/appointment_model.dart';
import '../data/models/service_model.dart';
import '../data/models/time_slot_model.dart';
import '../data/models/user_model.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';
import '../widgets/whatsapp_status_badge.dart';
import '../screens/patient_detail_screen.dart';
import 'create_appointment_screen.dart';
import 'public_appointment_booking_screen.dart';
import 'create_prescription_screen.dart';
import 'create_medical_record_screen.dart';
import '../core/utils/result.dart';
import '../l10n/app_localizations.dart';
import '../providers/locale_providers.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String _priorityFilter = 'all';
  String _serviceFilter = 'all';
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appointmentsAsync = ref.watch(
      appointmentsByDateProvider(
        AppointmentsByDateParams(
          year: _focusedDay.year,
          month: _focusedDay.month,
        ),
      ),
    );
    final servicesAsync = ref.watch(servicesProvider);

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: primaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations?.calendar ?? 'Calendar',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          // View Appointments Button
          Builder(
            builder: (context) => IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.list_rounded,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
              tooltip: 'View appointments',
            ),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: primaryColor,
                size: 24,
              ),
            ),
            onPressed: () {
              final authState = ref.read(authProvider);
              if (authState.user?.isPatient == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PublicAppointmentBookingScreen(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateAppointmentScreen(),
                  ),
                );
              }
            },
            tooltip: 'Create appointment',
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: appointmentsAsync.when(
        data: (result) => result.when(
          success: (appointments) {
            final filteredAppointments = _filterAppointments(appointments);
            final eventMap = _groupAppointmentsByDate(filteredAppointments);
            final selectedDateKey =
                DateFormat('yyyy-MM-dd').format(_selectedDay);
            final appointmentsForDay = eventMap[selectedDateKey] ?? [];
            return _buildAppointmentsDrawer(appointmentsForDay, isDark);
          },
          failure: (_) => const SizedBox(),
        ),
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: appointmentsAsync.when(
            data: (result) => result.when(
              success: (appointments) => _buildNewCalendarLayout(
                appointments,
                servicesAsync,
                isDark,
              ),
              failure: (message) => _buildErrorContainer(message, isDark),
            ),
            loading: () => const Center(child: LoadingWidget()),
            error: (error, stack) => Center(
              child: CustomErrorWidget(message: error.toString()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewCalendarLayout(
    List<AppointmentModel> appointments,
    AsyncValue<Result<List<ServiceModel>>> servicesAsync,
    bool isDark,
  ) {
    final localizations = AppLocalizations.of(context);
    final filteredAppointments = _filterAppointments(appointments);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Search Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _showSearchResultsDialog(appointments, isDark);
              }
            },
            decoration: InputDecoration(
              hintText:
                  localizations?.searchPatient ?? 'Search for a patient...',
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.search, color: primaryColor),
                      onPressed: () {
                        _showSearchResultsDialog(appointments, isDark);
                      },
                      tooltip: 'Show results',
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF252525) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Filter Section
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Priority Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return _buildFilterChip(
                          label: localizations?.all ?? 'All',
                          isSelected: _priorityFilter == 'all',
                          onTap: () => setState(() => _priorityFilter = 'all'),
                          isDark: isDark,
                          primaryColor: primaryColor,
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: '🔴',
                      isSelected: _priorityFilter == 'high',
                      onTap: () => setState(() => _priorityFilter = 'high'),
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: '🟡',
                      isSelected: _priorityFilter == 'medium',
                      onTap: () => setState(() => _priorityFilter = 'medium'),
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    _buildFilterChip(
                      label: '🟢',
                      isSelected: _priorityFilter == 'low',
                      onTap: () => setState(() => _priorityFilter = 'low'),
                      isDark: isDark,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Service Dropdown
              servicesAsync.when(
                data: (result) => result.when(
                  success: (services) => _buildServiceDropdown(
                    services,
                    isDark,
                    primaryColor,
                  ),
                  failure: (_) => const SizedBox(),
                ),
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
            ],
          ),
        ),

        // Calendar Section
        _buildNewCalendar(filteredAppointments, isDark),
      ],
    );
  }

  Widget _buildAppointmentsDrawer(
      List<AppointmentModel> appointments, bool isDark) {
    final localizations = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final locale = ref.watch(localeProvider).locale;
    final selectedDateFormatted =
        DateFormat('EEEE d MMMM yyyy', locale.toString()).format(_selectedDay);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            decoration: BoxDecoration(
              color: primaryColor,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      onPressed: () {
                        // Could add filter options here
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      '${localizations?.appointments ?? 'Appointments'}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  selectedDateFormatted,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        '${appointments.length} appointment${appointments.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Appointments List
          Expanded(
            child: _buildNewAppointmentsList(appointments, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF252525) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 1,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.grey[800]),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildServiceDropdown(
    List<ServiceModel> services,
    bool isDark,
    Color primaryColor,
  ) {
    final localizations = AppLocalizations.of(context);
    final items = <DropdownMenuItem<String>>[
      DropdownMenuItem(
        value: 'all',
        child: Text(
          localizations?.allServices ?? 'All Services',
          style: TextStyle(fontSize: 13),
        ),
      ),
      ...services.map((service) => DropdownMenuItem(
            value: service.id.toString(),
            child: Text(
              service.title ?? 'N/A',
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )),
    ];

    return DropdownButtonFormField<String>(
      value: _serviceFilter,
      isExpanded: true,
      isDense: true,
      decoration: InputDecoration(
        labelText: localizations?.service ?? 'Service',
        labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixIcon: Icon(
          Icons.medical_services_rounded,
          size: 18,
          color: primaryColor,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF252525) : Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.grey.withOpacity(0.3),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: primaryColor,
            width: 1.5,
          ),
        ),
      ),
      items: items,
      selectedItemBuilder: (context) => [
        Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations?.allServices ?? 'All Services',
              style: TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        ...services.map((service) => Text(
              service.title ?? 'N/A',
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )),
      ],
      onChanged: (value) {
        setState(() {
          _serviceFilter = value ?? 'all';
        });
      },
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white : Colors.black87,
      ),
      icon: Icon(
        Icons.arrow_drop_down,
        color: primaryColor,
        size: 20,
      ),
      dropdownColor: isDark ? const Color(0xFF252525) : Colors.white,
    );
  }

  Widget _buildNewCalendar(List<AppointmentModel> appointments, bool isDark) {
    final filteredAppointments = _filterAppointments(appointments);
    final eventMap = _groupAppointmentsByDate(filteredAppointments);
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final selectedDateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    final appointmentsForDay = eventMap[selectedDateKey] ?? [];

    return Column(
      children: [
        // Calendar Container
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TableCalendar<AppointmentModel>(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: _calendarFormat,
              eventLoader: (day) =>
                  eventMap[DateFormat('yyyy-MM-dd').format(day)] ?? [],
              startingDayOfWeek: StartingDayOfWeek.monday,
              locale: ref.watch(localeProvider).locale.toString(),
              calendarStyle: CalendarStyle(
                outsideDaysVisible: false,
                defaultTextStyle: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                weekendTextStyle: TextStyle(
                  color: primaryColor.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                todayTextStyle: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                todayDecoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor,
                    width: 2,
                  ),
                ),
                selectedDecoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.transparent,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 4,
                markerSize: 0,
                cellMargin: const EdgeInsets.all(6),
                cellPadding: const EdgeInsets.all(4),
                canMarkersOverflow: true,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
                titleTextStyle: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                formatButtonDecoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                formatButtonTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left,
                  color: primaryColor,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right,
                  color: primaryColor,
                ),
                headerPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
                weekendStyle: TextStyle(
                  color: primaryColor.withOpacity(0.7),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox();
                  final eventCount = events.length;
                  final hasMultiple = eventCount > 1;

                  return Positioned(
                    bottom: 2,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasMultiple)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor,
                                  primaryColor.withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$eventCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          ...events.take(3).map((event) {
                            final appointment = event;
                            Color color;
                            if (appointment.status == 'completed') {
                              color = Colors.green;
                            } else if (appointment.status == 'cancelled') {
                              color = Colors.red;
                            } else if (appointment.priority == 'high') {
                              color = Colors.red;
                            } else if (appointment.priority == 'medium') {
                              color = Colors.orange;
                            } else {
                              color = Colors.blue;
                            }
                            return Container(
                              width: 8,
                              height: 8,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 1.5),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  );
                },
                defaultBuilder: (context, date, focusedDay) {
                  final isToday = isSameDay(date, DateTime.now());
                  final isSelected = isSameDay(date, _selectedDay);
                  final hasEvents =
                      (eventMap[DateFormat('yyyy-MM-dd').format(date)] ?? [])
                          .isNotEmpty;

                  return Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: hasEvents && !isToday && !isSelected
                          ? Border.all(
                              color: primaryColor.withOpacity(0.3),
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? primaryColor
                                  : textColor,
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Selected Date Header with View Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.event_rounded, color: primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        final locale = ref.watch(localeProvider).locale;
                        return Text(
                          DateFormat('EEEE d MMMM yyyy', locale.toString())
                              .format(_selectedDay),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          '${appointmentsForDay.length} appointment${appointmentsForDay.length != 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (appointmentsForDay.isNotEmpty) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${appointmentsForDay.length}',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.arrow_forward_ios,
                        color: primaryColor, size: 18),
                    onPressed: () {
                      Scaffold.of(context).openEndDrawer();
                    },
                    tooltip: 'View all appointments',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Appointments List Preview (Limited to 3 items)
        if (appointmentsForDay.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          'Today\'s Appointments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        );
                      },
                    ),
                    if (appointmentsForDay.length > 3)
                      TextButton(
                        onPressed: () {
                          Scaffold.of(context).openEndDrawer();
                        },
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              'View all (${appointmentsForDay.length})',
                              style: TextStyle(color: primaryColor),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ...appointmentsForDay.take(3).map((appointment) =>
                    _buildNewAppointmentCard(appointment, isDark)),
                if (appointmentsForDay.length > 3)
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        Scaffold.of(context).openEndDrawer();
                      },
                      icon: Icon(Icons.arrow_forward, color: primaryColor),
                      label: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            'View ${appointmentsForDay.length - 3} more',
                            style: TextStyle(color: primaryColor),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildNewAppointmentsList(
      List<AppointmentModel> appointments, bool isDark) {
    if (appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  children: [
                    Text(
                      'No Appointments',
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No appointments scheduled for this date',
                      style: TextStyle(
                        color: isDark ? Colors.grey[500] : Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    // Sort by time
    appointments.sort((a, b) {
      final timeA = a.appointmentTime ?? '00:00:00';
      final timeB = b.appointmentTime ?? '00:00:00';
      return timeA.compareTo(timeB);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: appointments.length,
      itemBuilder: (context, index) {
        final appointment = appointments[index];
        return _buildNewAppointmentCard(appointment, isDark);
      },
    );
  }

  Widget _buildNewAppointmentCard(AppointmentModel appointment, bool isDark) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    final localizations = AppLocalizations.of(context);
    switch (appointment.status?.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusText = 'Cancelled';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_rounded;
        statusText = 'Pending';
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule_rounded;
        statusText = 'Scheduled';
    }

    Color priorityColor;
    switch (appointment.priority?.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () => _showAppointmentDetailsDialog(appointment),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: priorityColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Time Container
              Container(
                width: 60,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(appointment.appointmentTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Patient Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            appointment.patient?.user?.name ?? 'Unknown',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                statusIcon,
                                size: 12,
                                color: statusColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.medical_services_rounded,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            appointment.service?.title ?? 'Unknown Service',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (appointment.patient?.phone != null ||
                        appointment.patient?.phoneNumber != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 12,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              appointment.patient?.phone ??
                                  appointment.patient?.phoneNumber ??
                                  '',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[500]
                                    : Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Priority Indicator
              Container(
                width: 3,
                height: 50,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAppointmentDetailsDialog(AppointmentModel appointment) {
    // Get user info for conditional display
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Status colors and icons
    Color statusColor;
    IconData statusIcon;
    String statusText;

    final localizations = AppLocalizations.of(context);
    switch (appointment.status?.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusText = 'Cancelled';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_rounded;
        statusText = 'Pending';
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule_rounded;
        statusText = 'Scheduled';
    }

    Color priorityColor;
    String priorityText;
    switch (appointment.priority?.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        priorityText = '🔴 High';
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityText = '🟡 Medium';
        break;
      default:
        priorityColor = Colors.green;
        priorityText = '🟢 Low';
    }

    final patientId = appointment.patient?.id;
    final appointmentId = appointment.id;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Compact Header with close button
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Appointment Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        minimumSize: const Size(32, 32),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable content with fade indicator
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Status and Priority badges - Compact
                          Row(
                            children: [
                              _buildModernBadge(
                                  statusColor, statusIcon, statusText),
                              const SizedBox(width: 8),
                              _buildModernBadge(
                                  priorityColor, null, priorityText,
                                  isIcon: false),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Patient Information Section - Compact
                          if (appointment.patient != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Compact section header
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person_rounded,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Patient',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Patient name - Compact
                                  _buildCompactInfoRow(
                                    Icons.person_outline_rounded,
                                    appointment.patient?.user?.name ??
                                        'Not provided',
                                    subtitle: appointment.patient?.user?.email,
                                  ),

                                  // Phone number with actions - Compact
                                  if (appointment.patient?.phoneNumber !=
                                          null ||
                                      appointment.patient?.phone != null) ...[
                                    const SizedBox(height: 8),
                                    _buildCompactPhoneRow(
                                      appointment.patient?.phoneNumber ??
                                          appointment.patient?.phone ??
                                          '',
                                      user: user,
                                    ),
                                  ],

                                  // WhatsApp Status - Prominently displayed
                                  if (patientId != null ||
                                      appointmentId != null) ...[
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFF25D366)
                                              .withOpacity(0.3),
                                        ),
                                      ),
                                      child: Consumer(
                                        builder: (context, ref, child) {
                                          final statusParams =
                                              WhatsAppStatusParams(
                                            clientId: patientId,
                                            appointmentId: appointmentId,
                                          );

                                          final statusStream = ref.watch(
                                              whatsAppStatusProvider(
                                                  statusParams));

                                          return statusStream.when(
                                            data: (result) {
                                              return result.when(
                                                success: (data) {
                                                  final status =
                                                      data['status'] as String?;
                                                  if (status == null ||
                                                      status == 'not_found') {
                                                    return Row(
                                                      children: [
                                                        Icon(
                                                          Icons.message_rounded,
                                                          color:
                                                              Colors.grey[600],
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                            width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            'No WhatsApp message sent',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontStyle:
                                                                  FontStyle
                                                                      .italic,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  }

                                                  return Row(
                                                    children: [
                                                      Icon(
                                                        Icons.message_rounded,
                                                        color: const Color(
                                                            0xFF25D366),
                                                        size: 18,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      const Text(
                                                        'Status: ',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      WhatsAppStatusBadge(
                                                        status: status,
                                                        showLabel: true,
                                                      ),
                                                    ],
                                                  );
                                                },
                                                failure: (_) =>
                                                    const SizedBox.shrink(),
                                              );
                                            },
                                            loading: () => Row(
                                              children: [
                                                SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      const Color(0xFF25D366),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  'Loading...',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            error: (_, __) =>
                                                const SizedBox.shrink(),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Appointment Information - Compact
                          Builder(
                            builder: (context) {
                              final locale = ref.watch(localeProvider).locale;
                              return Column(
                                children: [
                                  _buildCompactInfoRow(
                                    Icons.calendar_today_outlined,
                                    appointment.appointmentDate != null
                                        ? DateFormat('EEEE d MMMM yyyy',
                                                locale.toString())
                                            .format(DateTime.parse(
                                                appointment.appointmentDate!))
                                        : 'N/A',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCompactInfoRow(
                                    Icons.access_time_outlined,
                                    _formatTime(appointment.appointmentTime),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCompactInfoRow(
                                    Icons.medical_services_outlined,
                                    appointment.doctor?.user?.name ??
                                        'Not assigned',
                                    subtitle:
                                        appointment.doctor?.specialization ??
                                            appointment.doctor?.specialty ??
                                            '',
                                  ),
                                  const SizedBox(height: 8),
                                  _buildCompactInfoRow(
                                    Icons.local_hospital_outlined,
                                    appointment.service?.title ??
                                        'Unknown Service',
                                    subtitle: appointment.service?.description,
                                  ),
                                  if (appointment.notes != null &&
                                      appointment.notes!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _buildCompactInfoRow(
                                      Icons.note_outlined,
                                      appointment.notes!,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),

                          // Invoice if exists
                          if (appointment.additionalData?['invoice'] !=
                              null) ...[
                            const SizedBox(height: 12),
                            _buildInvoiceCard(
                                appointment.additionalData!['invoice']
                                    as Map<String, dynamic>),
                          ],

                          // Scroll indicator hint
                          const SizedBox(height: 8),
                          Center(
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    // Fade gradient at bottom to indicate scrollable
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 20,
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Compact Action Buttons Section
              _buildCompactActionButtons(context, appointment),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact info row for better space usage
  Widget _buildCompactInfoRow(IconData icon, String value, {String? subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compact phone row
  Widget _buildCompactPhoneRow(String phoneNumber, {required UserModel? user}) {
    final canContact = user != null &&
        ((user.isDoctor ?? 0) == 1 ||
            (user.isAdmin ?? 0) == 1 ||
            (user.isReceptionist ?? 0) == 1);
    final hasPhoneNumber = phoneNumber.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              phoneNumber,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (canContact && hasPhoneNumber) ...[
            const SizedBox(width: 8),
            // Compact WhatsApp button
            Material(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _handleWhatsAppMessage(phoneNumber),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: const Icon(
                    Icons.message_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Compact Call button
            Material(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _handlePhoneCall(phoneNumber),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: const Icon(
                    Icons.phone_rounded,
                    color: Colors.blue,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernBadge(Color color, IconData? icon, String text,
      {bool isIcon = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null && isIcon) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernInfoCard(IconData icon, String title, String content,
      {String? subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ],
      ),
    );
  }

  /// Build phone info card with WhatsApp and Call action buttons
  Widget _buildPhoneInfoCard(String phoneNumber, {required UserModel? user}) {
    // Check if user is doctor, admin, or receptionist (all can contact patients)
    final canContact = user != null &&
        ((user.isDoctor ?? 0) == 1 ||
            (user.isAdmin ?? 0) == 1 ||
            (user.isReceptionist ?? 0) == 1);
    final hasPhoneNumber = phoneNumber.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_rounded,
                  size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Phone',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Phone Number
          Text(
            phoneNumber,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          // Action buttons below phone number
          if (canContact && hasPhoneNumber) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // WhatsApp Button
                Expanded(
                  child: Material(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _handleWhatsAppMessage(phoneNumber),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.message_rounded,
                              color: Colors.green,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'WhatsApp',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Call Button
                Expanded(
                  child: Material(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _handlePhoneCall(phoneNumber),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.phone_rounded,
                              color: Colors.blue,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Call',
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_rounded, size: 20, color: Colors.amber),
              const SizedBox(width: 8),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return const Text('Invoice',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('ID: ${invoice['id']}'),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount: ${invoice['amount']} MAD'),
                  Text(
                      'Status: ${invoice['status'] == 'paid' ? 'Paid' : 'Unpaid'}'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionButtons(
      BuildContext context, AppointmentModel appointment) {
    final authState = ref.read(authProvider);
    final user = authState.user;

    // Check if user has permission to perform actions
    final userDoctorId = user?.additionalData?['doctor']?['id'] as int?;
    final canPerformActions = user != null &&
        (user.isAdmin == 1 ||
            user.isReceptionist == 1 ||
            (user.isDoctor == 1 &&
                (appointment.doctor?.id == userDoctorId ||
                    appointment.doctor?.user?.id == user.id)));

    final isCompleted = appointment.status?.toLowerCase() == 'completed';
    final isCancelled = appointment.status?.toLowerCase() == 'cancelled';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
            top: BorderSide(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1))),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.start,
        children: [
          // Add to Google Calendar - Available for all users
          _buildCompactActionButton(
            context,
            icon: Icons.calendar_today_rounded,
            label: 'Calendar',
            color: Colors.blue,
            onPressed: () => _handleAddToGoogleCalendar(appointment),
          ),

          // Doctor-specific quick actions
          if (user?.isDoctor == 1 &&
              appointment.doctor != null &&
              (appointment.doctor!.id == userDoctorId ||
                  (appointment.doctor!.user != null &&
                      appointment.doctor!.user!.id == user?.id)) &&
              !isCancelled) ...[
            if (appointment.patient?.id != null)
              _buildCompactActionButton(
                context,
                icon: Icons.description_rounded,
                label: 'Prescription',
                color: Colors.amber,
                onPressed: () => _handleCreatePrescription(appointment),
              ),
            if (appointment.patient?.id != null)
              _buildCompactActionButton(
                context,
                icon: Icons.medical_services_rounded,
                label: 'Record',
                color: Colors.teal,
                onPressed: () => _handleCreateMedicalRecord(appointment),
              ),
            if (appointment.patient?.id != null)
              _buildCompactActionButton(
                context,
                icon: Icons.history_rounded,
                label: 'History',
                color: Colors.indigo,
                onPressed: () => _handleViewPatientHistory(appointment),
              ),
          ],

          // Admin/Doctor/Receptionist actions
          if (canPerformActions) ...[
            if (!isCompleted)
              _buildCompactActionButton(
                context,
                icon: Icons.check_circle_rounded,
                label: 'Complete',
                color: Colors.green,
                onPressed: () => _handleUpdateStatus(appointment, 'completed'),
              ),
            if (!isCancelled)
              _buildCompactActionButton(
                context,
                icon: Icons.cancel_rounded,
                label: 'Cancel',
                color: Colors.red,
                onPressed: () => _handleUpdateStatus(appointment, 'cancelled'),
              ),
            if (isCancelled)
              _buildCompactActionButton(
                context,
                icon: Icons.refresh_rounded,
                label: 'Reschedule',
                color: Colors.blue,
                onPressed: () => _handleUpdateStatus(appointment, 'scheduled'),
              ),
            _buildCompactActionButton(
              context,
              icon: Icons.edit_rounded,
              label: 'Edit',
              color: Colors.blue,
              onPressed: () => _handleEditAppointment(appointment),
            ),
            if (!isCompleted && !isCancelled)
              _buildCompactActionButton(
                context,
                icon: Icons.message_rounded,
                label: 'WhatsApp',
                color: Colors.green,
                onPressed: () => _handleSendWhatsAppReminder(appointment),
              ),
            if (appointment.patient?.id != null)
              _buildCompactActionButton(
                context,
                icon: Icons.person_rounded,
                label: 'Profile',
                color: Colors.purple,
                onPressed: () => _handleViewPatientProfile(appointment),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdateStatus(
      AppointmentModel appointment, String status) async {
    if (appointment.id == null) return;

    final localizations = AppLocalizations.of(context);
    final confirmMessage = status == 'completed'
        ? 'Mark this appointment as completed?'
        : status == 'cancelled'
            ? 'Cancel this appointment?'
            : 'Reschedule this appointment?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: const Text('Confirmation'),
          content: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    status == 'cancelled' ? Colors.red : Colors.blue,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    Navigator.of(context).pop(); // Close details dialog

    final result = await ref.read(
      updateAppointmentStatusProvider(
        UpdateStatusParams(
          appointmentId: appointment.id!,
          status: status,
        ),
      ).future,
    );

    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  status == 'completed'
                      ? 'Appointment marked as completed'
                      : status == 'cancelled'
                          ? 'Appointment cancelled'
                          : 'Appointment rescheduled',
                );
              },
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh appointments
        ref.invalidate(appointmentsByDateProvider(
          AppointmentsByDateParams(
            year: _focusedDay.year,
            month: _focusedDay.month,
          ),
        ));
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $error'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  Future<void> _handleSendWhatsAppReminder(AppointmentModel appointment) async {
    if (appointment.id == null) return;

    final localizations = AppLocalizations.of(context);
    final patientName = appointment.patient?.user?.name ?? 'this patient';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: const Text('Send WhatsApp Reminder'),
          content: Text('Send WhatsApp reminder to $patientName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final result = await ref.read(
      sendWhatsAppReminderProvider(appointment.id!).future,
    );

    result.when(
      success: (_) {
        if (!mounted) return;

        final patientName = appointment.patient?.user?.name ?? 'the patient';
        final localizations = AppLocalizations.of(context);

        // Build success message with patient name
        String successMessage;
        if (localizations?.localeName == 'fr') {
          successMessage =
              'Rappel WhatsApp envoyé avec succès !\n\nÀ: $patientName';
        } else if (localizations?.localeName == 'ar') {
          successMessage =
              'تم إرسال تذكير WhatsApp بنجاح!\n\nإلى: $patientName';
        } else {
          successMessage =
              'WhatsApp reminder sent successfully!\n\nTo: $patientName';
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.scale,
          title: localizations?.success ?? 'Success',
          desc: successMessage,
          btnOkText: localizations?.ok ?? 'OK',
          btnOkColor: const Color(0xFF25D366), // WhatsApp green
          btnOkOnPress: () {},
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          descTextStyle: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
          padding: const EdgeInsets.all(20),
        ).show();
      },
      failure: (error) {
        if (!mounted) return;

        final localizations = AppLocalizations.of(context);
        String errorMessage = localizations?.failedToSendWhatsAppReminder ??
            'Failed to send WhatsApp reminder. Please try again.';

        if (error.contains('Daily message limit') || error.contains('429')) {
          errorMessage = localizations?.dailyMessageLimitReached ??
              'Daily message limit reached. Please try again tomorrow.';
        } else if (error.isNotEmpty) {
          errorMessage = error;
        }

        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          animType: AnimType.scale,
          title: localizations?.error ?? 'Error',
          desc: errorMessage,
          btnOkText: localizations?.ok ?? 'OK',
          btnOkColor: Colors.red,
          btnOkOnPress: () {},
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          descTextStyle: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
          padding: const EdgeInsets.all(20),
        ).show();
      },
    );
  }

  void _handleEditAppointment(AppointmentModel appointment) {
    Navigator.of(context).pop(); // Close details dialog
    _showEditAppointmentDialog(appointment);
  }

  void _showEditAppointmentDialog(AppointmentModel appointment) {
    if (appointment.id == null || appointment.doctor?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text('Unable to edit this appointment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    DateTime selectedDate = appointment.appointmentDate != null
        ? DateTime.parse(appointment.appointmentDate!)
        : DateTime.now();
    String selectedTime = _formatTime(appointment.appointmentTime);
    final doctorId = appointment.doctor!.id!;

    showDialog(
      context: context,
      builder: (context) => _EditAppointmentDialog(
        appointment: appointment,
        initialDate: selectedDate,
        initialTime: selectedTime,
        doctorId: doctorId,
        onUpdate: (date, time) async {
          final formattedDate = DateFormat('yyyy-MM-dd').format(date);
          // Ensure time is in HH:mm format (not HH:mm:ss)
          // Remove seconds if present, keep only HH:mm
          String formattedTime = time;
          if (formattedTime.contains(':') &&
              formattedTime.split(':').length == 3) {
            final parts = formattedTime.split(':');
            formattedTime = '${parts[0]}:${parts[1]}';
          }
          // Validate format is HH:mm
          if (!RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$')
              .hasMatch(formattedTime)) {
            formattedTime = _formatTime(time);
          }

          // Build complete payload with all required fields like Next.js
          final appointmentData = <String, dynamic>{
            'doctor_id': doctorId.toString(),
            'appointment_date': formattedDate,
            'appointment_time': formattedTime,
            'priority': appointment.priority ?? 'medium',
            'status': appointment.status ?? 'scheduled',
            'notes': appointment.notes,
            'service_id': appointment.service?.id?.toString(),
            'patient_id': appointment.patient?.id,
          };

          final result = await ref.read(
            updateAppointmentProvider(
              UpdateAppointmentParams(
                appointmentId: appointment.id!,
                appointmentData: appointmentData,
              ),
            ).future,
          );

          result.when(
            success: (_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: const Text('Appointment updated successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              // Refresh appointments
              ref.invalidate(appointmentsByDateProvider(
                AppointmentsByDateParams(
                  year: _focusedDay.year,
                  month: _focusedDay.month,
                ),
              ));
            },
            failure: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erreur: $error'),
                  backgroundColor: Colors.red,
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _handleViewPatientProfile(AppointmentModel appointment) {
    if (appointment.patient?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations patient non disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close details dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PatientDetailScreen(patientId: appointment.patient!.id!),
      ),
    );
  }

  /// Handle creating prescription from appointment (Quick action for doctors)
  void _handleCreatePrescription(AppointmentModel appointment) {
    if (appointment.patient?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations patient non disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close details dialog

    // appointment.patient is already a PatientModel, so we can pass it directly
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePrescriptionScreen(
          currentPatient: appointment.patient!,
        ),
      ),
    );
  }

  /// Handle creating medical record from appointment (Quick action for doctors)
  void _handleCreateMedicalRecord(AppointmentModel appointment) {
    if (appointment.patient?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations patient non disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close details dialog

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateMedicalRecordScreen(
          patientId: appointment.patient!.id,
        ),
      ),
    ).then((result) {
      // Refresh appointments if a record was created
      if (result == true) {
        ref.invalidate(appointmentsByDateProvider(
          AppointmentsByDateParams(
            year: _focusedDay.year,
            month: _focusedDay.month,
          ),
        ));
      }
    });
  }

  /// Handle viewing patient history (Quick action for doctors)
  void _handleViewPatientHistory(AppointmentModel appointment) {
    if (appointment.patient?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations patient non disponibles'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.of(context).pop(); // Close details dialog

    // Navigate to patient detail screen which should show history
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PatientDetailScreen(patientId: appointment.patient!.id!),
      ),
    );
  }

  Widget _buildErrorContainer(String message, bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Erreur: $message',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<AppointmentModel> _filterAppointments(
      List<AppointmentModel> appointments) {
    return appointments.where((appointment) {
      if (_priorityFilter != 'all' && appointment.priority != _priorityFilter) {
        return false;
      }

      if (_serviceFilter != 'all' &&
          appointment.service?.id?.toString() != _serviceFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final patientName =
            appointment.patient?.user?.name?.toLowerCase() ?? '';
        final serviceName = appointment.service?.title?.toLowerCase() ?? '';
        if (!patientName.contains(_searchQuery) &&
            !serviceName.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _showSearchResultsDialog(
      List<AppointmentModel> appointments, bool isDark) {
    if (_searchQuery.isEmpty) {
      return;
    }

    // Filter appointments based on search query
    final searchResults = appointments.where((appointment) {
      final patientName = appointment.patient?.user?.name?.toLowerCase() ?? '';
      final serviceName = appointment.service?.title?.toLowerCase() ?? '';
      return patientName.contains(_searchQuery) ||
          serviceName.contains(_searchQuery);
    }).toList();

    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Search Results',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Search: "${_searchQuery}"',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Results Count
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[50],
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          searchResults.isEmpty
                              ? 'No results found'
                              : '${searchResults.length} result${searchResults.length != 1 ? 's' : ''} found',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Results List
              Expanded(
                child: searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return Column(
                                  children: [
                                    Text(
                                      'No Results',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[600],
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No appointments match your search',
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.grey[500]
                                            : Colors.grey[500],
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: searchResults.length,
                        itemBuilder: (context, index) {
                          final appointment = searchResults[index];
                          return _buildSearchResultCard(appointment, isDark);
                        },
                      ),
              ),

              // Close Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Fermer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(AppointmentModel appointment, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black87;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    final localizations = AppLocalizations.of(context);
    switch (appointment.status?.toLowerCase()) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusIcon = Icons.cancel_rounded;
        statusText = 'Cancelled';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_rounded;
        statusText = 'Pending';
        break;
      default:
        statusColor = Colors.blue;
        statusIcon = Icons.schedule_rounded;
        statusText = 'Scheduled';
    }

    Color priorityColor;
    switch (appointment.priority?.toLowerCase()) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pop(); // Close search dialog
        _showAppointmentDetailsDialog(appointment);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252525) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: priorityColor.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Date/Time Container
              Container(
                width: 65,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (appointment.appointmentDate != null)
                      Text(
                        DateFormat('d MMM', 'fr_FR').format(
                          DateTime.parse(appointment.appointmentDate!),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(appointment.appointmentTime),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Patient Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          flex: 3,
                          child: Text(
                            appointment.patient?.user?.name ?? 'Unknown',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  statusIcon,
                                  size: 12,
                                  color: statusColor,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.medical_services_rounded,
                          size: 13,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            appointment.service?.title ?? 'Unknown Service',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (appointment.appointmentDate != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 11,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                final locale = ref.watch(localeProvider).locale;
                                return Text(
                                  DateFormat('d MMM yyyy', locale.toString())
                                      .format(
                                    DateTime.parse(
                                        appointment.appointmentDate!),
                                  ),
                                  style: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Priority Indicator
              Container(
                width: 3,
                height: 60,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List<AppointmentModel>> _groupAppointmentsByDate(
    List<AppointmentModel> appointments,
  ) {
    final map = <String, List<AppointmentModel>>{};
    for (final appointment in appointments) {
      if (appointment.appointmentDate != null) {
        final dateKey = appointment.appointmentDate!;
        map.putIfAbsent(dateKey, () => []).add(appointment);
      }
    }
    return map;
  }

  String _formatTime(String? time) {
    if (time == null) return '00:00';
    try {
      if (time.contains(':') && time.split(':').length == 3) {
        final parts = time.split(':');
        return '${parts[0]}:${parts[1]}';
      }
      return time;
    } catch (e) {
      return '00:00';
    }
  }

  /// Generate Google Calendar URL for an appointment
  String _generateGoogleCalendarUrl(AppointmentModel appointment) {
    try {
      // Parse appointment date and time
      final formattedTime = _formatTime(appointment.appointmentTime);
      final timeParts = formattedTime.split(':');
      final hours = int.tryParse(timeParts[0]) ?? 0;
      final minutes = int.tryParse(timeParts[1]) ?? 0;

      // Create start date in local timezone
      DateTime startDate;
      if (appointment.appointmentDate != null) {
        startDate = DateTime.parse(appointment.appointmentDate!);
        startDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
          hours,
          minutes,
        );
      } else {
        startDate = DateTime.now();
      }

      // Calculate end date (add service duration or default to 30 minutes)
      // ServiceModel doesn't have duration, so we use default 30 minutes
      final duration = 30;
      final endDate = startDate.add(Duration(minutes: duration));

      // Format dates for Google Calendar (YYYYMMDDTHHmmss - without Z for local time)
      String formatGoogleDate(DateTime date) {
        final year = date.year.toString();
        final month = date.month.toString().padLeft(2, '0');
        final day = date.day.toString().padLeft(2, '0');
        final hour = date.hour.toString().padLeft(2, '0');
        final minute = date.minute.toString().padLeft(2, '0');
        final second = date.second.toString().padLeft(2, '0');
        return '$year$month${day}T$hour$minute$second';
      }

      final startDateStr = formatGoogleDate(startDate);
      final endDateStr = formatGoogleDate(endDate);

      // Build event details
      final title = Uri.encodeComponent(
        '${appointment.service?.title ?? "Appointment"} - ${appointment.patient?.user?.name ?? "Patient"}',
      );

      final details = Uri.encodeComponent(
        'Patient: ${appointment.patient?.user?.name ?? "Unknown"}\n'
        'Doctor: ${appointment.doctor?.user?.name ?? "Unknown"}\n'
        'Service: ${appointment.service?.title ?? "Unknown Service"}\n'
        '${appointment.notes != null && appointment.notes!.isNotEmpty ? "Notes: ${appointment.notes}" : ""}',
      );

      final location = Uri.encodeComponent('Hospital');

      // Generate Google Calendar URL
      final googleCalendarUrl =
          'https://calendar.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$startDateStr/$endDateStr&details=$details&location=$location';

      return googleCalendarUrl;
    } catch (e) {
      return '';
    }
  }

  /// Handle making a phone call
  Future<void> _handlePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text('Phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Clean phone number (remove spaces, dashes, etc.)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Add country code if not present (assuming Morocco +212)
    String phoneUri = cleanPhone;
    if (!cleanPhone.startsWith('+')) {
      // If it starts with 0, replace with +212
      if (cleanPhone.startsWith('0')) {
        phoneUri = '+212${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('212')) {
        phoneUri = '+212$cleanPhone';
      } else {
        phoneUri = '+$cleanPhone';
      }
    }

    try {
      final uri = Uri.parse('tel:$phoneUri');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Try with the original phone number
        final fallbackUri = Uri.parse('tel:$cleanPhone');
        await launchUrl(fallbackUri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle sending WhatsApp message
  Future<void> _handleWhatsAppMessage(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text('Phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Clean phone number (remove spaces, dashes, etc.)
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Add country code if not present (assuming Morocco +212)
    String phoneUri = cleanPhone;
    if (!cleanPhone.startsWith('+')) {
      // If it starts with 0, replace with 212
      if (cleanPhone.startsWith('0')) {
        phoneUri = '212${cleanPhone.substring(1)}';
      } else if (!cleanPhone.startsWith('212')) {
        phoneUri = '212$cleanPhone';
      }
    } else {
      phoneUri = cleanPhone.substring(1); // Remove the +
    }

    try {
      // Use WhatsApp URL scheme: https://wa.me/PHONENUMBER
      final uri = Uri.parse('https://wa.me/$phoneUri');

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: try platform default
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to open WhatsApp: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle adding appointment to Google Calendar
  Future<void> _handleAddToGoogleCalendar(AppointmentModel appointment) async {
    final url = _generateGoogleCalendarUrl(appointment);
    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: const Text('Unable to generate Google Calendar link'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(url);

      // Try to launch the URL
      // On Android, canLaunchUrl might return false even for valid URLs,
      // so we try to launch anyway with different modes
      try {
        // First try with platformDefault (works better for web URLs on Android)
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: const Text('Opening Google Calendar...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // If platformDefault fails, try externalApplication
        try {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: const Text('Opening Google Calendar...'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (launchError) {
          // If both fail, show error message with URL for manual copy
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Unable to open Google Calendar automatically. Please copy the link manually.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
            // Log the URL for debugging
            debugPrint('Google Calendar URL: $url');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

// Edit Appointment Dialog Widget
class _EditAppointmentDialog extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final DateTime initialDate;
  final String initialTime;
  final int doctorId;
  final Function(DateTime date, String time) onUpdate;

  const _EditAppointmentDialog({
    required this.appointment,
    required this.initialDate,
    required this.initialTime,
    required this.doctorId,
    required this.onUpdate,
  });

  @override
  ConsumerState<_EditAppointmentDialog> createState() =>
      _EditAppointmentDialogState();
}

class _EditAppointmentDialogState
    extends ConsumerState<_EditAppointmentDialog> {
  late DateTime _selectedDate;
  String? _selectedTime;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _selectedTime = widget.initialTime;
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('fr', 'FR'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedTime = null; // Reset time when date changes
      });
    }
  }

  String _normalizeTime(String time) {
    // Ensure time is in HH:mm format
    if (time.contains(':') && time.split(':').length == 3) {
      final parts = time.split(':');
      return '${parts[0]}:${parts[1]}';
    }
    // Validate it's already in HH:mm format
    if (RegExp(r'^([0-1][0-9]|2[0-3]):[0-5][0-9]$').hasMatch(time)) {
      return time;
    }
    // Fallback: try to parse and format
    try {
      final parts = time.split(':');
      if (parts.length >= 2) {
        final hour = parts[0].padLeft(2, '0');
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
    } catch (e) {
      // If parsing fails, return default
    }
    return '09:00'; // Default fallback
  }

  Future<void> _handleSave() async {
    if (_selectedTime == null || _selectedTime!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: const Text('Please select a time'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Normalize time to HH:mm format before sending
    final normalizedTime = _normalizeTime(_selectedTime!);
    await widget.onUpdate(_selectedDate, normalizedTime);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeSlotsAsync = ref.watch(
      timeSlotsProvider(
        TimeSlotsParams(
          doctorId: widget.doctorId,
          date: formattedDate,
        ),
      ),
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.edit_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Modifier le Rendez-vous',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Patient Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.appointment.patient?.user?.name ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Date Picker
            Text(
              'Date',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          final locale = ref.watch(localeProvider).locale;
                          return Text(
                            DateFormat('EEEE d MMMM yyyy', locale.toString())
                                .format(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          );
                        },
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Time Slots
            Text(
              'Heure',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            timeSlotsAsync.when(
              data: (result) => result.when(
                success: (timeSlots) {
                  if (timeSlots.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return const Text(
                            'No time slots available for this date',
                            style: TextStyle(color: Colors.orange),
                          );
                        },
                      ),
                    );
                  }

                  // Filter available slots
                  final availableSlots =
                      timeSlots.where((slot) => slot.available).toList();

                  // If current time is not in available slots, add it
                  if (_selectedTime != null &&
                      !availableSlots
                          .any((slot) => slot.time == _selectedTime)) {
                    availableSlots.add(TimeSlotModel(
                      time: _selectedTime!,
                      available: true,
                    ));
                    availableSlots.sort((a, b) => a.time.compareTo(b.time));
                  }

                  return Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: availableSlots.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Builder(
                              builder: (context) {
                                final localizations =
                                    AppLocalizations.of(context);
                                return const Text('No time slots available');
                              },
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: availableSlots.length,
                            itemBuilder: (context, index) {
                              final slot = availableSlots[index];
                              final isSelected = _selectedTime == slot.time;
                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedTime = slot.time;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.1)
                                        : Colors.transparent,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: isDark
                                            ? Colors.white.withOpacity(0.05)
                                            : Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                                .radio_button_unchecked_rounded,
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        slot.time,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : null,
                                        ),
                                      ),
                                      if (!slot.available) ...[
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Occupied',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
                failure: (error) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Text(
                  'Erreur: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return const Text('Cancel');
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Builder(
                            builder: (context) {
                              final localizations =
                                  AppLocalizations.of(context);
                              return const Text('Save');
                            },
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

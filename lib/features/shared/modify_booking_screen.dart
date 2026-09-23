import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';
import '../shared/seat_grid.dart';

class ModifyBookingScreen extends StatefulWidget {
  final BookingDetails booking;
  const ModifyBookingScreen({super.key, required this.booking});

  @override
  State<ModifyBookingScreen> createState() => _ModifyBookingScreenState();
}

class _ModifyBookingScreenState extends State<ModifyBookingScreen> {
  final bookingRepo = BookingRepo();
  final _formKey = GlobalKey<FormState>();

  late final String fromStopId;
  late final String toStopId;
  String mode = 'group';

  List<TextEditingController> names = [];
  List<TextEditingController> nids = [];
  List<TextEditingController> phones = [];

  bool submitting = false;

  @override
  void initState() {
    super.initState();
    mode = widget.booking.ticketMode.isNotEmpty ? widget.booking.ticketMode : 'group';
    fromStopId = widget.booking.fromStopId ?? widget.booking.trip?.fromStopId ?? '';
    toStopId = widget.booking.toStopId ?? widget.booking.trip?.toStopId ?? '';
    _initPassengers(widget.booking.passengers.isNotEmpty ? widget.booking.passengers.length : 1);
  }

  void _initPassengers(int count) {
    _syncPassengerControllers(count);
  }

  void _syncPassengerControllers(int count) {
    if (count <= 0) count = 1;
    if (names.length == count) return;

    final newNames = <TextEditingController>[];
    final newNids = <TextEditingController>[];
    final newPhones = <TextEditingController>[];

    for (int i = 0; i < count; i++) {
      if (i < names.length) {
        newNames.add(names[i]);
        newNids.add(nids[i]);
        newPhones.add(phones[i]);
      } else if (i < widget.booking.passengers.length) {
        newNames.add(TextEditingController(text: widget.booking.passengers[i].fullName));
        newNids.add(TextEditingController(text: widget.booking.passengers[i].nationalId));
        newPhones.add(TextEditingController(text: widget.booking.passengers[i].phone ?? ''));
      } else {
        newNames.add(TextEditingController());
        newNids.add(TextEditingController());
        newPhones.add(TextEditingController());
      }
    }

    for (int i = count; i < names.length; i++) {
      names[i].dispose();
      nids[i].dispose();
      phones[i].dispose();
    }

    setState(() {
      names = newNames;
      nids = newNids;
      phones = newPhones;
    });
  }

  @override
  void dispose() {
    for (final c in [...names, ...nids, ...phones]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'يرجى إدخال اسم الراكب';
    }
    if (v.length < 3) {
      return 'الاسم يجب أن يتكون من 3 أحرف على الأقل';
    }
    // Only letters (Arabic & Latin) and spaces allowed
    final nameRegex = RegExp(r'^[\u0600-\u06FFa-zA-Z\s]+$');
    if (!nameRegex.hasMatch(v)) {
      return 'الاسم يقبل أحرف فقط بدون أرقام أو رموز';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return null; // Phone is optional
    }
    // Only digits
    final digitRegex = RegExp(r'^[0-9]+$');
    if (!digitRegex.hasMatch(v)) {
      return 'رقم الهاتف يقبل أرقام فقط';
    }
    // Must start with 09 and be 10 digits
    if (v.length != 10 || !v.startsWith('09')) {
      return 'يرجى إدخال رقم هاتف سوري صحيح (10 أرقام تبدأ بـ 09)';
    }
    return null;
  }

  String? _validateNationalId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'الرقم الوطني مطلوب';
    }
    final digitRegex = RegExp(r'^[0-9]+$');
    if (!digitRegex.hasMatch(v)) {
      return 'الرقم الوطني يقبل أرقام فقط';
    }
    if (v.length != 11) {
      return 'الرقم الوطني يجب أن يتألف من 11 رقماً بدقة';
    }
    return null;
  }

  Future<void> _submit(BuildContext context, SeatState seatState) async {
    if (!_formKey.currentState!.validate()) {
      showAppSnack(
        context,
        'يرجى التأكد من صحة كافة البيانات المدخلة',
        type: AppSnackType.error,
      );
      return;
    }

    if (seatState.selected.isEmpty) {
      showAppSnack(
        context,
        'يرجى تحديد المقاعد المطلوبة للتعديل (المقاعد المختارة: 0)',
        type: AppSnackType.error,
      );
      return;
    }

    if (seatState.selected.length != widget.booking.seats.length) {
      showAppSnack(
        context,
        'يجب اختيار نفس عدد المقاعد الأصلي وهو (${widget.booking.seats.length}) مقاعد',
        type: AppSnackType.error,
      );
      return;
    }

    if (seatState.selected.length != names.length) {
      _syncPassengerControllers(seatState.selected.length);
      showAppSnack(
        context,
        'عدد الركاب (${names.length}) يجب أن يطابق عدد المقاعد المختارة (${seatState.selected.length})',
        type: AppSnackType.error,
      );
      return;
    }

    final passengers = <PassengerDraft>[];
    for (int i = 0; i < names.length; i++) {
      final name = names[i].text.trim();
      final nid = nids[i].text.trim();
      final phone = phones[i].text.trim();

      if (name.isEmpty || nid.isEmpty) {
        showAppSnack(context, context.tr('passenger.enterNameNationalId'), type: AppSnackType.error);
        return;
      }
      passengers.add(PassengerDraft(
        fullName: name,
        phone: phone.isEmpty ? null : phone,
        nationalId: nid,
      ));
    }

    setState(() => submitting = true);
    try {
      await bookingRepo.modify(
        bookingId: widget.booking.id,
        from: fromStopId,
        to: toStopId,
        seatIds: seatState.selected.toList(),
        passengers: passengers,
        ticketMode: mode,
      );
      if (context.mounted) {
        showAppSnack(context, context.tr('booking.modifySuccess'), type: AppSnackType.success);
        context.pop(true);
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnack(context, mapError(e, L10n.of(context)), type: AppSnackType.error);
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.booking.trip;
    if (trip == null || fromStopId.isEmpty || toStopId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('booking.modifyTitle')),
          leading: const BackButton(),
        ),
        body: Center(child: Text(context.tr('passenger.segmentUnknown'))),
      );
    }

    return BlocProvider(
      create: (_) {
        final cubit = SeatCubit();
        final currentSeatIds = widget.booking.seats.map((e) => e.busSeatId).toList();
        cubit.load(trip.id, fromStopId, toStopId, currentSeatIds: currentSeatIds);
        return cubit;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('booking.modifyTitle')),
          leading: const BackButton(),
          elevation: 0,
        ),

        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: BlocConsumer<SeatCubit, SeatState>(
            listener: (context, seatState) {
              if (seatState.selected.isNotEmpty && seatState.selected.length != names.length) {
                _syncPassengerControllers(seatState.selected.length);
              }
            },
            builder: (context, seatState) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // Notice & Trip Route Summary (Read-Only)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('booking.modifyHint'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.directions_bus_outlined, size: 18, color: AppColors.mutedLight),
                            const SizedBox(width: 6),
                            Text(
                              trip.companyName.isNotEmpty ? trip.companyName : 'بولمان',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${trip.originName} ${context.tr('common.routeArrow')} ${trip.destinationName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Ticket Mode Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 2),
                          child: Text(
                            context.tr('passenger.ticketTypeLabel'),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        RadioGroup<String>(
                          groupValue: mode,
                          onChanged: (v) {
                            if (v != null) setState(() => mode = v);
                          },
                          child: Column(
                            children: [
                              RadioListTile<String>(
                                value: 'group',
                                contentPadding: EdgeInsets.zero,
                                title: Text(context.tr('ticketMode.group'), style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(context.tr('ticketMode.groupHint'), style: const TextStyle(fontSize: 12)),
                              ),
                              RadioListTile<String>(
                                value: 'individual',
                                contentPadding: EdgeInsets.zero,
                                title: Text(context.tr('ticketMode.individual'), style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Passenger Details Header
                  Row(
                    children: [
                      const Icon(Icons.people_outline, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('passenger.passengerData'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const Spacer(),
                      Text(
                        '(${names.length} ${context.tr('passenger.passengersCount')})',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Passenger Form Cards
                  for (int i = 0; i < names.length; i++) ...[
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primary.withValues(alpha: .12),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.tr('passenger.passengerN', {'n': '${i + 1}'}),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Name Field (Letters Only)
                          TextFormField(
                            controller: names[i],
                            keyboardType: TextInputType.name,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FFa-zA-Z\s]')),
                            ],
                            validator: _validateName,
                            decoration: InputDecoration(
                              labelText: context.tr('passenger.name'),
                              hintText: 'الاسم الثلاثي (أحرف فقط)',
                              prefixIcon: const Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Phone Field (Digits Only, max 10)
                          TextFormField(
                            controller: phones[i],
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: _validatePhone,
                            decoration: InputDecoration(
                              labelText: context.tr('passenger.phoneOptional'),
                              hintText: '09xxxxxxxx',
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // National ID Field (Digits Only, 11 digits)
                          TextFormField(
                            controller: nids[i],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            validator: _validateNationalId,
                            decoration: InputDecoration(
                              labelText: context.tr('passenger.nationalId'),
                              hintText: '11 رقماً (أرقام فقط)',
                              prefixIcon: const Icon(Icons.badge_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  const SizedBox(height: 12),

                  // Seat Map Section (At the Bottom with Full-Height Scrollable View)
                  Row(
                    children: [
                      const Icon(Icons.airline_seat_recline_normal, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('passenger.selectSeats'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const Spacer(),
                      Badge(
                        text: context.tr('passenger.seatSelectionSummary', {'count': '${seatState.selected.length}'}),
                        color: AppColors.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  if (seatState.loading && seatState.seats.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else
                    SeatGrid(
                      seats: seatState.seats,
                      selected: seatState.selected,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onToggle: (seat) {
                        HapticFeedback.selectionClick();
                        context.read<SeatCubit>().toggle(seat, max: widget.booking.seats.length);
                      },
                    ),

                  const SizedBox(height: 8),
                  const SeatLegend(),

                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
        bottomNavigationBar: BlocBuilder<SeatCubit, SeatState>(
          builder: (c, seatState) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: FilledButton(
                  onPressed: submitting ? null : () => _submit(context, seatState),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          context.tr('booking.confirmModify'),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/i18n/l10n.dart';
import '../../app/theme.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../../shared/step_indicator.dart';
import '../../shared/widgets.dart';
import '../cubits.dart';
import '../shared/formatters.dart';
import '../shared/seat_grid.dart';
import '../shared/ticket_share.dart';
import 'booking_args.dart';

class SeatsScreen extends StatefulWidget {
  final SeatsArgs args;
  const SeatsScreen({super.key, required this.args});

  @override
  State<SeatsScreen> createState() => _SeatsScreenState();
}

class _SeatsScreenState extends State<SeatsScreen> {
  Trip? _trip;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.args.trip.hasSegment) {
      _trip = widget.args.trip;
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final t = await TripsRepo().ensureSegment(widget.args.trip);
    if (!mounted) return;
    if (!t.hasSegment) {
      setState(() => _error = 'segment');
      return;
    }
    setState(() => _trip = t);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr('passenger.selectSeats')),
          leading: const BackButton(),
        ),

        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  context.tr('passenger.segmentUnknown'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('passenger.segmentUnknownHint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.go('/home'),
                  child: Text(context.tr('passenger.backToSearch')),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final trip = _trip;
    if (trip == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final f = trip.fromStopId!;
    final t = trip.toStopId!;
    return BlocProvider(
      create: (_) => SeatCubit()..load(trip.id, f, t),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('passenger.selectSeats')),
          leading: const BackButton(),
        ),

        body: BlocBuilder<SeatCubit, SeatState>(
          builder: (c, s) => StateBox(
            loading: s.loading && s.seats.isEmpty,
            error: s.error != null ? mapError(s.error!, L10n.of(c)) : null,
            child: Column(
              children: [
                BookingStepIndicator(
                  currentStep: 0,
                  labels: [
                    c.tr('passenger.stepSeats'),
                    c.tr('passenger.stepPassengers'),
                    c.tr('passenger.stepPayment'),
                    c.tr('passenger.stepTicket'),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.tr('passenger.selectSeatsHint', {'count': '${s.selected.length}'}))),
                      if (s.selected.isNotEmpty)
                        Badge(
                          text: c.tr('passenger.seatSelectionSummary', {'count': '${s.selected.length}'}),
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SeatGrid(
                    seats: s.seats,
                    selected: s.selected,
                    onToggle: (seat) {
                      HapticFeedback.selectionClick();
                      c.read<SeatCubit>().toggle(seat);
                    },
                  ),
                ),
                const SeatLegend(),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (s.selected.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            '${c.tr('passenger.pricePreview')}: ${formatMoney(s.selected.length * trip.finalPrice, c.l10n)}',
                            textAlign: TextAlign.center,
                            style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      FilledButton(
                        onPressed: s.selected.isEmpty
                            ? null
                            : () async {
                                final ok = await c.read<SeatCubit>().lock(trip.id, f, t);
                                if (ok && c.mounted) {
                                  c.push('/passengers', extra: PassArgs(trip, f, t, c.read<SeatCubit>().state.selectedSeats));
                                }
                              },
                        child: Text(c.tr('passenger.lockSeats')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PassengersScreen extends StatefulWidget {
  final PassArgs args;
  const PassengersScreen({super.key, required this.args});

  @override
  State<PassengersScreen> createState() => _PassState();
}

class _PassState extends State<PassengersScreen> {
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> names, nids, phones;
  String mode = 'group';

  @override
  void initState() {
    super.initState();
    names = List.generate(widget.args.seats.length, (_) => TextEditingController());
    nids = List.generate(widget.args.seats.length, (_) => TextEditingController());
    phones = List.generate(widget.args.seats.length, (_) => TextEditingController());
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
    if (v.isEmpty) return 'يرجى إدخال اسم الراكب';
    if (v.length < 3) return 'الاسم يجب أن يتكون من 3 أحرف على الأقل';
    if (!RegExp(r'^[\u0600-\u06FFa-zA-Z\s]+$').hasMatch(v)) {
      return 'الاسم يقبل أحرف فقط بدون أرقام أو رموز';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'رقم الهاتف يقبل أرقام فقط';
    if (v.length != 10 || !v.startsWith('09')) {
      return 'يرجى إدخال رقم هاتف سوري صحيح (10 أرقام تبدأ بـ 09)';
    }
    return null;
  }

  String? _validateNationalId(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'الرقم الوطني مطلوب';
    if (!RegExp(r'^[0-9]+$').hasMatch(v)) return 'الرقم الوطني يقبل أرقام فقط';
    if (v.length != 11) return 'الرقم الوطني يجب أن يتألف من 11 رقماً بدقة';
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr('passenger.passengerData')),
          leading: const BackButton(),
        ),

        body: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              BookingStepIndicator(
                currentStep: 1,
                labels: [
                  context.tr('passenger.stepSeats'),
                  context.tr('passenger.stepPassengers'),
                  context.tr('passenger.stepPayment'),
                  context.tr('passenger.stepTicket'),
                ],
              ),
              AppCard(
                child: RadioGroup<String>(
                  groupValue: mode,
                  onChanged: (v) {
                    if (v != null) setState(() => mode = v);
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        value: 'group',
                        title: Text(context.tr('ticketMode.group')),
                        subtitle: Text(context.tr('ticketMode.groupHint')),
                      ),
                      RadioListTile<String>(
                        value: 'individual',
                        title: Text(context.tr('ticketMode.individual')),
                      ),
                    ],
                  ),
                ),
              ),
              for (int i = 0; i < names.length; i++)
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
                          const SizedBox(width: AppSpacing.sm),
                          Text(context.tr('passenger.passengerN', {'n': '${i + 1}'}), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
        bottomNavigationBar: Container(
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
                onPressed: () {
                  if (!_formKey.currentState!.validate()) {
                    showAppSnack(context, 'يرجى التأكد من صحة كافة بيانات الركاب', type: AppSnackType.error);
                    return;
                  }
                  final ps = <PassengerDraft>[];
                  for (int i = 0; i < names.length; i++) {
                    final name = names[i].text.trim();
                    final nid = nids[i].text.trim();
                    final phone = phones[i].text.trim();
                    if (name.isEmpty || nid.isEmpty) {
                      showAppSnack(context, context.tr('passenger.enterNameNationalId'), type: AppSnackType.error);
                      return;
                    }
                    ps.add(PassengerDraft(
                      fullName: name,
                      phone: phone.isEmpty ? null : phone,
                      nationalId: nid,
                    ));
                  }
                  context.push(
                    '/payment',
                    extra: BookingDraft(
                      trip: widget.args.trip,
                      from: widget.args.from,
                      to: widget.args.to,
                      seats: widget.args.seats,
                      passengers: ps,
                      mode: mode,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  context.tr('passenger.continuePayment'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ),
      );
}

class PaymentScreen extends StatelessWidget {
  final BookingDraft draft;
  const PaymentScreen({super.key, required this.draft});

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => WalletCubit()..load()),
          BlocProvider(create: (_) => BookingCubit()),
        ],
        child: BlocConsumer<BookingCubit, BookingState>(
          listener: (c, s) {
            if (s.error != null) showAppSnack(c, mapError(s.error!, L10n.of(c)), type: AppSnackType.error);
            if (s.bookingId != null) {
              c.read<BookingsCubit>().load();
              c.read<WalletCubit>().load();
              c.go('/ticket/${s.bookingId}');
            }
          },
          builder: (c, bs) => Scaffold(
            appBar: AppBar(
              title: Text(c.tr('passenger.payment')),
              leading: const BackButton(),
            ),

            body: BlocBuilder<WalletCubit, WalletState>(
              builder: (c, ws) {
                final bal = ws.wallet?.balance ?? 0;
                final enough = bal >= draft.total;
                return StateBox(
                  loading: ws.loading,
                  error: ws.error != null ? mapError(ws.error!, L10n.of(c)) : null,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      BookingStepIndicator(
                        currentStep: 2,
                        labels: [
                          c.tr('passenger.stepSeats'),
                          c.tr('passenger.stepPassengers'),
                          c.tr('passenger.stepPayment'),
                          c.tr('passenger.stepTicket'),
                        ],
                      ),
                      Header(title: c.tr('passenger.total'), subtitle: formatMoney(draft.total, c.l10n)),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          gradient: AppGradients.wallet,
                          boxShadow: AppShadows.medium(AppColors.primary),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.tr('passenger.yourBalance'), style: TextStyle(color: Colors.white.withValues(alpha: .8))),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              formatMoney(bal, c.l10n),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${c.tr('passenger.seatsLabel')}: ${draft.seats.map((e) => e.number).join(', ')}'),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${c.tr('passenger.ticketTypeLabel')}: ${draft.mode == 'group' ? c.tr('ticketMode.group') : c.tr('ticketMode.individual')}',
                            ),
                          ],
                        ),
                      ),
                      if (!enough) Text(c.tr('passenger.insufficientBalance'), style: const TextStyle(color: Colors.red)),
                      FilledButton(
                        onPressed: !enough || bs.loading ? null : () => c.read<BookingCubit>().confirm(draft),
                        child: bs.loading ? const CircularProgressIndicator() : Text(c.tr('passenger.confirmPay')),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
}

class TicketScreen extends StatelessWidget {
  final String bookingId;
  const TicketScreen({super.key, required this.bookingId});

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BookingDetails>(
        future: BookingRepo().details(bookingId),
        builder: (c, bookingSnap) => FutureBuilder<List<Ticket>>(
          future: BookingRepo().tickets(bookingId),
          builder: (c, s) => Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _back(c),
              ),
              title: Text(c.tr('passenger.ticket')),
            ),
            body: StateBox(
              loading: s.connectionState == ConnectionState.waiting,
              error: s.error?.toString(),
              empty: s.hasData && s.data!.isEmpty,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  BookingStepIndicator(
                    currentStep: 3,
                    labels: [
                      c.tr('passenger.stepSeats'),
                      c.tr('passenger.stepPassengers'),
                      c.tr('passenger.stepPayment'),
                      c.tr('passenger.stepTicket'),
                    ],
                  ),
                  if (bookingSnap.hasData)
                    AppCard(
                      child: Text(
                        '${c.tr('passenger.bookingId')}: ${bookingId.substring(0, 8)}\n'
                        '${c.tr('passenger.seatsLabel')}: ${bookingSnap.data!.seatNumbers.join(', ')}',
                      ),
                    ),
                  ...(s.data ?? []).map((t) {
                    final booking = bookingSnap.data;
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(c).cardColor,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: Theme.of(c).dividerColor.withValues(alpha: .7)),
                      ),
                      child: Column(
                        children: [
                          if (t.type == 'individual' && t.passengerName != null && t.passengerName!.isNotEmpty) ...[
                            Text(t.passengerName!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                          Row(
                            children: [
                              const Spacer(),
                              Expanded(
                                flex: 6,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.confirmation_num_outlined, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        t.type == 'group' ? c.tr('passenger.groupTicket') : c.tr('passenger.individualTicket'),
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (booking != null)
                                Builder(
                                  builder: (btnCtx) => IconButton(
                                    tooltip: c.tr('passenger.shareTicket'),
                                    icon: const Icon(Icons.share_outlined),
                                    onPressed: () {
                                      final box = btnCtx.findRenderObject() as RenderBox?;
                                      shareTicket(
                                        context: c,
                                        ticket: t,
                                        booking: booking,
                                        sharePositionOrigin: box == null || !box.hasSize
                                            ? null
                                            : box.localToGlobal(Offset.zero) & box.size,
                                      );
                                    },
                                  ),
                                )
                              else
                                const SizedBox(width: 48),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Container(height: 1, color: Theme.of(c).dividerColor),
                          const SizedBox(height: AppSpacing.md),
                          // generate_qr_token() emits 64 hex chars, so level H forced version 7
                          // (45x45). Squeezed into 220dp with a 12dp quiet zone barely 2.8 modules
                          // wide, each module landed at 4.4dp -- too fine for a driver's camera to
                          // resolve off a glossy phone screen, and the quiet zone was under the
                          // 4-module minimum the spec requires. Level M drops it to version 5
                          // (37x37): 5.2dp per module with a 4.6-module quiet zone.
                          QrImageView(
                            data: t.qr,
                            size: 240,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            padding: const EdgeInsets.all(24),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(t.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: AppSpacing.xs),
                          StatusBadge(t.status),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
}

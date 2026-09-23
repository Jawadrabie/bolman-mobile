import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';
import '../core/driver_trip_utils.dart';
import '../core/fcm_service.dart';
import '../data/models.dart';
import '../data/repositories.dart';

class SafeCubit<T> extends Cubit<T> {
  SafeCubit(super.initialState);

  void safeEmit(T state) {
    if (!isClosed) emit(state);
  }
}

class AuthState extends Equatable {
  final bool loading;
  final Profile? profile;
  final String? error;
  const AuthState({this.loading = false, this.profile, this.error});
  bool get authed => profile != null;
  bool get isDriver => profile?.isDriver ?? false;
  bool get isPassenger => profile?.isPassenger ?? false;
  @override
  List<Object?> get props => [loading, profile, error];
}

class AuthCubit extends SafeCubit<AuthState> {
  final r = AuthRepo();
  AuthCubit() : super(const AuthState(loading: true));

  Future<void> bootstrap() async {
    try {
      await _clearStaleSessionIfNeeded();
      if (sb.auth.currentUser == null) {
        safeEmit(const AuthState(loading: false));
        return;
      }
      final profile = await r.profile().timeout(const Duration(seconds: 6));
      safeEmit(AuthState(loading: false, profile: profile));
      if (profile != null) unawaited(FcmService.instance.registerForCurrentUser());
    } on TimeoutException {
      safeEmit(const AuthState(loading: false, error: 'NETWORK_TIMEOUT'));
    } on AuthException catch (e) {
      if (_isStaleRefreshToken(e)) {
        await r.logout();
        safeEmit(const AuthState(loading: false));
        return;
      }
      safeEmit(AuthState(loading: false, error: friendlyError(e)));
    } catch (e) {
      safeEmit(AuthState(loading: false, error: friendlyError(e)));
    }
  }

  Future<void> _clearStaleSessionIfNeeded() async {
    final session = sb.auth.currentSession;
    if (session == null) return;
    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (expiry.isAfter(DateTime.now().add(const Duration(minutes: 2)))) return;
    }
    try {
      await sb.auth.refreshSession().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      // Keep cached session; profile fetch will surface real auth errors.
    } on AuthException catch (e) {
      if (_isStaleRefreshToken(e)) await r.logout();
    } catch (_) {
      await r.logout();
    }
  }

  bool _isStaleRefreshToken(AuthException e) =>
      e.code == 'refresh_token_not_found' || e.message.contains('Refresh Token');

  /// Clears stale bootstrap errors after hot restart / config fix.
  Future<void> refreshSession() async {
    safeEmit(const AuthState(loading: true, error: null));
    await bootstrap();
  }

  Future<void> login(String email, String password) async {
    safeEmit(const AuthState(loading: true, error: null));
    try {
      await r.login(email, password);
      final profile = await r.profile();
      if (profile == null) {
        await r.logout();
        assert(() {
          // ignore: avoid_print
          print('Bolman auth: signed in but public.users row missing for ${email.trim()}');
          return true;
        }());
        safeEmit(const AuthState(error: 'PROFILE_NOT_FOUND'));
        return;
      }
      safeEmit(AuthState(profile: profile));
      FcmService.instance.registerForCurrentUser();
    } catch (x) {
      assert(() {
        // ignore: avoid_print
        print('Bolman auth login error: $x');
        return true;
      }());
      safeEmit(AuthState(error: friendlyError(x)));
    }
  }

  Future<void> register(String n, String ph, String e, String p) async {
    safeEmit(const AuthState(loading: true, error: null));
    try {
      await r.registerPassenger(fullName: n, phone: ph, email: e, password: p);
      final profile = await r.profile();
      if (profile == null) {
        safeEmit(const AuthState(error: 'PROFILE_NOT_FOUND'));
        return;
      }
      safeEmit(AuthState(profile: profile));
      FcmService.instance.registerForCurrentUser();
    } catch (x) {
      safeEmit(AuthState(error: friendlyError(x)));
    }
  }

  Future<void> reset(String e) => r.reset(e);

  /// Publishes a profile edited elsewhere (edit-profile / avatar screens).
  ///
  /// Never touches [AuthState.loading]: the router redirects to /splash while
  /// auth is loading, so a profile save must not go through this cubit's flag.
  void applyProfile(Profile profile) => safeEmit(AuthState(profile: profile));

  Future<void> logout() async {
    await r.logout();
    safeEmit(const AuthState());
  }
}

/// Own loading/error state so saving a profile never triggers the auth redirect.
class ProfileEditState extends Equatable {
  final bool saving;
  final bool uploadingAvatar;
  final String? error;
  final String? savedMessageKey;

  const ProfileEditState({this.saving = false, this.uploadingAvatar = false, this.error, this.savedMessageKey});

  bool get busy => saving || uploadingAvatar;

  @override
  List<Object?> get props => [saving, uploadingAvatar, error, savedMessageKey];
}

class ProfileEditCubit extends SafeCubit<ProfileEditState> {
  final AuthRepo r = AuthRepo();
  final AuthCubit auth;

  ProfileEditCubit(this.auth) : super(const ProfileEditState());

  Future<bool> save({required String fullName, String? phone}) async {
    if (state.busy) return false;
    safeEmit(const ProfileEditState(saving: true));
    try {
      auth.applyProfile(await r.updateProfile(fullName: fullName, phone: phone));
      safeEmit(const ProfileEditState(savedMessageKey: 'profile.saved'));
      return true;
    } catch (e) {
      safeEmit(ProfileEditState(error: friendlyError(e)));
      return false;
    }
  }

  Future<bool> uploadAvatar({required Uint8List bytes, required String fileExtension}) async {
    if (state.busy) return false;
    safeEmit(const ProfileEditState(uploadingAvatar: true));
    try {
      auth.applyProfile(await r.uploadAvatar(bytes: bytes, fileExtension: fileExtension));
      safeEmit(const ProfileEditState(savedMessageKey: 'profile.avatarUpdated'));
      return true;
    } catch (e) {
      safeEmit(ProfileEditState(error: friendlyError(e)));
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    if (state.busy) return false;
    safeEmit(const ProfileEditState(uploadingAvatar: true));
    try {
      auth.applyProfile(await r.removeAvatar());
      safeEmit(const ProfileEditState(savedMessageKey: 'profile.avatarRemoved'));
      return true;
    } catch (e) {
      safeEmit(ProfileEditState(error: friendlyError(e)));
      return false;
    }
  }

  void clearFlash() => safeEmit(const ProfileEditState());
}

class ChangePasswordState extends Equatable {
  final bool loading;
  final bool done;
  final String? error;

  const ChangePasswordState({this.loading = false, this.done = false, this.error});

  @override
  List<Object?> get props => [loading, done, error];
}

class ChangePasswordCubit extends SafeCubit<ChangePasswordState> {
  final AuthRepo r = AuthRepo();

  ChangePasswordCubit() : super(const ChangePasswordState());

  Future<bool> submit({required String currentPassword, required String newPassword}) async {
    if (state.loading) return false;
    safeEmit(const ChangePasswordState(loading: true));
    try {
      await r.changePassword(currentPassword: currentPassword, newPassword: newPassword);
      safeEmit(const ChangePasswordState(done: true));
      return true;
    } catch (e) {
      safeEmit(ChangePasswordState(error: friendlyError(e)));
      return false;
    }
  }
}

enum ResetStep { requestCode, enterCode, done }

class PasswordResetState extends Equatable {
  final ResetStep step;
  final bool loading;
  final String? email;
  final String? error;

  const PasswordResetState({this.step = ResetStep.requestCode, this.loading = false, this.email, this.error});

  PasswordResetState copyWith({ResetStep? step, bool? loading, String? email, String? error}) => PasswordResetState(
        step: step ?? this.step,
        loading: loading ?? this.loading,
        email: email ?? this.email,
        error: error,
      );

  @override
  List<Object?> get props => [step, loading, email, error];
}

/// Email → recovery code → new password. Kept out of [AuthCubit] because
/// `verifyOTP` opens a real session and the router must not react mid-flow.
class PasswordResetCubit extends SafeCubit<PasswordResetState> {
  final AuthRepo r = AuthRepo();

  PasswordResetCubit() : super(const PasswordResetState());

  Future<bool> sendCode(String email) async {
    if (state.loading) return false;
    safeEmit(state.copyWith(loading: true, error: null));
    try {
      await r.sendPasswordResetCode(email);
      safeEmit(state.copyWith(loading: false, step: ResetStep.enterCode, email: email.trim()));
      return true;
    } catch (e) {
      safeEmit(state.copyWith(loading: false, error: friendlyError(e)));
      return false;
    }
  }

  Future<bool> resendCode() async {
    final email = state.email;
    if (email == null) return false;
    safeEmit(state.copyWith(loading: true, error: null));
    try {
      await r.sendPasswordResetCode(email);
      safeEmit(state.copyWith(loading: false));
      return true;
    } catch (e) {
      safeEmit(state.copyWith(loading: false, error: friendlyError(e)));
      return false;
    }
  }

  Future<bool> confirm({required String code, required String newPassword}) async {
    final email = state.email;
    if (email == null || state.loading) return false;
    safeEmit(state.copyWith(loading: true, error: null));
    try {
      await r.confirmPasswordReset(email: email, code: code, newPassword: newPassword);
      safeEmit(state.copyWith(loading: false, step: ResetStep.done));
      return true;
    } catch (e) {
      safeEmit(state.copyWith(loading: false, error: friendlyError(e)));
      return false;
    }
  }

  void backToEmail() => safeEmit(const PasswordResetState());
}
class SearchState extends Equatable {
  final bool loading;
  final List<City> cities;
  final List<Trip> results, offers, upcoming;
  final String? error;
  final String? lastFromId, lastToId, lastFromName, lastToName;
  final DateTime? lastTravelDate;

  const SearchState({
    this.loading = false,
    this.cities = const [],
    this.results = const [],
    this.offers = const [],
    this.upcoming = const [],
    this.error,
    this.lastFromId,
    this.lastToId,
    this.lastFromName,
    this.lastToName,
    this.lastTravelDate,
  });

  bool get hasLastSearch => lastFromId != null && lastToId != null && lastTravelDate != null;

  SearchState c({
    bool? loading,
    List<City>? cities,
    List<Trip>? results,
    List<Trip>? offers,
    List<Trip>? upcoming,
    String? error,
    String? lastFromId,
    String? lastToId,
    String? lastFromName,
    String? lastToName,
    DateTime? lastTravelDate,
  }) =>
      SearchState(
        loading: loading ?? this.loading,
        cities: cities ?? this.cities,
        results: results ?? this.results,
        offers: offers ?? this.offers,
        upcoming: upcoming ?? this.upcoming,
        error: error,
        lastFromId: lastFromId ?? this.lastFromId,
        lastToId: lastToId ?? this.lastToId,
        lastFromName: lastFromName ?? this.lastFromName,
        lastToName: lastToName ?? this.lastToName,
        lastTravelDate: lastTravelDate ?? this.lastTravelDate,
      );

  @override
  List<Object?> get props => [loading, cities, results, offers, upcoming, error, lastFromId, lastToId, lastFromName, lastToName, lastTravelDate];
}

class SearchCubit extends SafeCubit<SearchState> {
  final refs = RefRepo();
  final trips = TripsRepo();
  SearchCubit() : super(const SearchState());

  Future<void> init() async {
    if (isClosed) return;
    safeEmit(state.c(loading: true));
    try {
      final results = await Future.wait([refs.cities(), trips.upcoming(), trips.offers()]);
      final upcoming = results[1] as List<Trip>..sort((a, b) => a.departure.compareTo(b.departure));
      final offers = results[2] as List<Trip>..sort((a, b) => a.departure.compareTo(b.departure));
      safeEmit(state.c(
        loading: false,
        cities: results[0] as List<City>,
        upcoming: upcoming,
        offers: offers,
      ));
    } catch (e) {
      safeEmit(state.c(loading: false, error: friendlyError(e)));
    }
  }

  Future<void> search(String fromId, String toId, DateTime date, {String? fromName, String? toName}) async {
    emit(state.c(
      loading: true,
      results: [],
      error: null,
      lastFromId: fromId,
      lastToId: toId,
      lastFromName: fromName,
      lastToName: toName,
      lastTravelDate: date,
    ));
    try {
      emit(state.c(loading: false, results: await trips.search(fromId, toId, date)));
    } catch (e) {
      emit(state.c(loading: false, error: friendlyError(e)));
    }
  }

  Future<void> retryLastSearch() async {
    if (!state.hasLastSearch) return;
    await search(
      state.lastFromId!,
      state.lastToId!,
      state.lastTravelDate!,
      fromName: state.lastFromName,
      toName: state.lastToName,
    );
  }
}
class DetailsState extends Equatable{final bool loading; final List<TripStop> stops; final String? error; const DetailsState({this.loading=false,this.stops=const[],this.error}); @override List<Object?> get props=>[loading,stops,error];}
class DetailsCubit extends Cubit<DetailsState>{ final r=TripsRepo(); DetailsCubit():super(const DetailsState()); Future<void> load(String id)async{emit(const DetailsState(loading:true));try{emit(DetailsState(stops:await r.stops(id)));}catch(e){emit(DetailsState(error:friendlyError(e)));}}}
class SeatState extends Equatable{final bool loading; final List<SeatStatus> seats; final Set<String> selected; final String? error; const SeatState({this.loading=false,this.seats=const[],this.selected=const{},this.error}); SeatState c({bool? loading,List<SeatStatus>? seats,Set<String>? selected,String? error})=>SeatState(loading:loading??this.loading,seats:seats??this.seats,selected:selected??this.selected,error:error); List<SeatStatus> get selectedSeats=>seats.where((e)=>selected.contains(e.id)).toList(); @override List<Object?> get props=>[loading,seats,selected,error];}
class SeatCubit extends Cubit<SeatState> {
  final r = SeatsRepo();
  SeatCubit() : super(const SeatState());

  Future<void> load(String trip, String from, String to, {List<String> currentSeatIds = const []}) async {
    emit(state.c(loading: true));
    try {
      final seats = await r.status(trip, from, to);
      final updatedSeats = seats.map((seat) {
        if (currentSeatIds.contains(seat.id)) {
          return SeatStatus(
            id: seat.id,
            number: seat.number,
            column: seat.column,
            status: 'available',
            isOwnLock: false,
          );
        }
        return seat;
      }).toList();

      final selected = {
        ...updatedSeats.where((e) => e.isOwnLock).map((e) => e.id),
        ...currentSeatIds,
      };

      emit(state.c(loading: false, seats: updatedSeats, selected: selected));
    } catch (e) {
      emit(state.c(loading: false, error: friendlyError(e)));
    }
  }

  void toggle(SeatStatus s, {int max = 6}) {
    if (!s.selectable) return;
    final n = {...state.selected};
    n.contains(s.id)
        ? n.remove(s.id)
        : n.length < max
            ? n.add(s.id)
            : null;
    emit(state.c(selected: n));
  }

  Future<bool> lock(String trip, String from, String to) async {
    try {
      emit(state.c(loading: true));
      await r.lock(trip, from, to, state.selected.toList());
      await load(trip, from, to);
      return true;
    } catch (e) {
      emit(state.c(loading: false, error: friendlyError(e)));
      return false;
    }
  }
}
class BookingDraft { final Trip trip; final String from,to,mode; final List<SeatStatus> seats; final List<PassengerDraft> passengers; BookingDraft({required this.trip,required this.from,required this.to,required this.seats,required this.passengers,required this.mode}); double get total=>trip.finalPrice*passengers.length; }
class BookingState extends Equatable{final bool loading; final String? bookingId,error; const BookingState({this.loading=false,this.bookingId,this.error}); @override List<Object?> get props=>[loading,bookingId,error];}
class BookingCubit extends Cubit<BookingState>{ final r=BookingRepo(); BookingCubit():super(const BookingState()); Future<void> confirm(BookingDraft d)async{emit(const BookingState(loading:true));try{emit(BookingState(bookingId:await r.confirmWallet(trip:d.trip,from:d.from,to:d.to,seats:d.seats.map((e)=>e.id).toList(),passengers:d.passengers,ticketMode:d.mode)));}catch(e){emit(BookingState(error:friendlyError(e)));}}}
class WalletState extends Equatable{final bool loading; final Wallet? wallet; final List<WalletTx> txs; final String? error; const WalletState({this.loading=false,this.wallet,this.txs=const[],this.error}); @override List<Object?> get props=>[loading,wallet,txs,error];}
class WalletCubit extends SafeCubit<WalletState>{ final r=WalletRepo(); WalletCubit():super(const WalletState()); Future<void> load()async{if(isClosed)return;safeEmit(const WalletState(loading:true));try{final w=await r.wallet();final txs=w==null?const <WalletTx>[]:await r.txs(w.id);safeEmit(WalletState(wallet:w,txs:txs));}catch(e){safeEmit(WalletState(error:friendlyError(e)));}}}
class BookingsState extends Equatable{final bool loading; final List<BookingSummary> items; final String? error; const BookingsState({this.loading=false,this.items=const[],this.error}); @override List<Object?> get props=>[loading,items,error];}
class BookingsCubit extends SafeCubit<BookingsState>{ final r=BookingRepo(); BookingsCubit():super(const BookingsState()); Future<void> load()async{if(isClosed)return;final keep=state.items;safeEmit(BookingsState(loading:keep.isEmpty,items:keep));try{final items=await r.mine();safeEmit(BookingsState(items:items));}catch(e){safeEmit(BookingsState(items:keep,error:friendlyError(e)));}} Future<void> rate(String id,int stars)async{await r.rate(id,stars); await load();}}
class BookingDetailsState extends Equatable{ final bool loading,actionLoading; final BookingDetails? details; final String? error,message; const BookingDetailsState({this.loading=false,this.actionLoading=false,this.details,this.error,this.message}); BookingDetailsState copyWith({bool? loading,bool? actionLoading,BookingDetails? details,String? error,String? message})=>BookingDetailsState(loading:loading??this.loading,actionLoading:actionLoading??this.actionLoading,details:details??this.details,error:error,message:message); @override List<Object?> get props=>[loading,actionLoading,details,error,message];}
class BookingDetailsCubit extends Cubit<BookingDetailsState>{ final r=BookingRepo(); BookingDetailsCubit():super(const BookingDetailsState()); Future<void> load(String id)async{emit(state.copyWith(loading:true,error:null));try{emit(BookingDetailsState(details:await r.details(id)));}catch(e){emit(BookingDetailsState(error:friendlyError(e)));}} Future<bool> cancel(String id)async{emit(state.copyWith(actionLoading:true,error:null));try{await r.cancel(id); await load(id); emit(state.copyWith(actionLoading:false,message:'cancelled')); return true;}catch(e){emit(state.copyWith(actionLoading:false,error:friendlyError(e))); return false;}} Future<bool> modify({required String bookingId,required String from,required String to,required List<String> seatIds,required List<PassengerDraft> passengers,required String ticketMode})async{emit(state.copyWith(actionLoading:true,error:null));try{await r.modify(bookingId:bookingId,from:from,to:to,seatIds:seatIds,passengers:passengers,ticketMode:ticketMode); await load(bookingId); emit(state.copyWith(actionLoading:false,message:'modified')); return true;}catch(e){emit(state.copyWith(actionLoading:false,error:friendlyError(e))); return false;}} Future<bool> payPending(String id)async{emit(state.copyWith(actionLoading:true,error:null));try{await r.payPending(id); await load(id); emit(state.copyWith(actionLoading:false,message:'paid')); return true;}catch(e){emit(state.copyWith(actionLoading:false,error:friendlyError(e))); return false;}} Future<void> rate(String id,int stars)async{await r.rate(id,stars); await load(id);}}
class NotificationsState extends Equatable {
  final bool loading;
  final List<NotificationItem> items;
  final String? error;

  const NotificationsState({this.loading = false, this.items = const [], this.error});

  int get unread => items.where((x) => !x.read).length;

  @override
  List<Object?> get props => [loading, items, error];
}

class NotificationsCubit extends SafeCubit<NotificationsState> {
  final r = NotificationsRepo();
  StreamSubscription<void>? _fcmSub;
  AppLifecycleListener? _lifecycle;
  bool _loading = false;
  bool _reloadQueued = false;

  NotificationsCubit() : super(const NotificationsState()) {
    // Auto-refresh whenever a new notification arrives (FCM or Supabase realtime)
    _fcmSub = FcmService.instance.onNewNotification.listen((_) => load());
    // Pushes that land while the app is backgrounded produce no stream event, so
    // resync the list every time the user comes back to the app.
    _lifecycle = AppLifecycleListener(onResume: load);
  }

  Future<void> load() async {
    if (isClosed) return;
    // Realtime insert + FCM message can fire back to back; collapse the burst
    // into one extra fetch instead of hammering the API.
    if (_loading) {
      _reloadQueued = true;
      return;
    }
    _loading = true;
    // Keep the current list on screen while refreshing so the page never blinks
    // back to the empty state.
    safeEmit(NotificationsState(loading: true, items: state.items));
    try {
      final items = await r.list();
      assert(() {
        // ignore: avoid_print
        print('Bolman notifications: fetched ${items.length} row(s) for ${sb.auth.currentUser?.id}');
        return true;
      }());
      safeEmit(NotificationsState(items: items));
    } catch (e) {
      // Swallowing this used to leave the page stuck on the empty state with no
      // hint that the query itself had failed.
      assert(() {
        // ignore: avoid_print
        print('Bolman notifications load error: $e');
        return true;
      }());
      safeEmit(NotificationsState(items: state.items, error: friendlyError(e)));
    } finally {
      _loading = false;
      if (_reloadQueued && !isClosed) {
        _reloadQueued = false;
        await load();
      }
    }
  }

  Future<void> read(String id) async {
    // Flip the flag locally first so the badge and the tile react immediately,
    // then confirm against the server.
    safeEmit(NotificationsState(
      items: [for (final n in state.items) if (n.id == id) n.copyWith(read: true) else n],
    ));
    try {
      await r.read(id);
    } catch (_) {}
    await load();
  }

  @override
  Future<void> close() {
    _fcmSub?.cancel();
    _lifecycle?.dispose();
    return super.close();
  }
}
class DriverTripsCubit extends Cubit<BookingsState>{
  final r=DriverRepo();
  DriverTripsCubit():super(const BookingsState());
  Trip? get activeTrip => pickDriverCurrentTrip(state.items.map((b) => b.trip).whereType<Trip>());
  Future<void> loadTrips()async{emit(const BookingsState(loading:true));try{final trips=await r.trips(); emit(BookingsState(items:trips.map((e)=>BookingSummary(id:e.id,status:e.status,paymentStatus:'',ticketMode:'',count:0,total:e.finalPrice,trip:e,createdAt:e.departure)).toList()));}catch(e){emit(BookingsState(error:friendlyError(e)));}}
}
class QrCubit extends SafeCubit<ScanResult?> {
  final r = DriverRepo();
  QrCubit() : super(null);

  String? _lastToken;
  DateTime? _lastAt;
  bool _busy = false;

  void clear() => safeEmit(null);

  String _normalizeToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      for (final key in ['token', 'qr', 'qr_token', 't']) {
        final value = uri.queryParameters[key]?.trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    return trimmed.replaceAll(RegExp(r'\s+'), '');
  }

  Future<ScanResult?> scan(String t, {String? expectedTripId}) async {
    if (isClosed) return null;
    final token = _normalizeToken(t);
    if (token.isEmpty) return state;

    final now = DateTime.now();
    if (_busy) return state;
    if (_lastToken == token && _lastAt != null && now.difference(_lastAt!) < const Duration(seconds: 2)) {
      return state;
    }

    _busy = true;
    _lastToken = token;
    _lastAt = now;
    try {
      final res = await r.scan(token, expectedTripId: expectedTripId);
      safeEmit(res);
      return res;
    } catch (e) {
      final err = ScanResult(scanResult: 'invalid', message: friendlyError(e), passengerCount: 0);
      safeEmit(err);
      return err;
    } finally {
      _busy = false;
    }
  }
}

// lib/data/repositories/admin_repository.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/school_model.dart';
import '../models/board_model.dart';
import '../models/user_profile_model.dart';
import '../models/app_version_model.dart';
import '../models/broadcast_package_model.dart';
import '../models/support_ticket_model.dart';
import '../../core/constants/app_constants.dart';

class AdminRepository {
  /// Anon client — login / auth işlemleri
  final SupabaseClient _client = Supabase.instance.client;

  /// Service-role client — auth.admin işlemleri (kullanıcı oluşturma/silme)
  late final SupabaseClient _adminClient;

  /// Saf Service-role Postgrest client — Asla tarayıcı oturumunu miras almaz, RLS'e takılmaz!
  late final PostgrestClient _db;

  /// Saf Service-role Storage client — Asla tarayıcı oturumunu miras almaz, RLS'e takılmaz!
  late final SupabaseStorageClient _storage;

  AdminRepository() {
    final effectiveKey = AppConstants.supabaseServiceRoleKey.isNotEmpty
        ? AppConstants.supabaseServiceRoleKey
        : AppConstants.supabaseAnonKey;
    _adminClient = SupabaseClient(
      AppConstants.supabaseUrl,
      effectiveKey,
    );
    _db = PostgrestClient(
      '${AppConstants.supabaseUrl}/rest/v1',
      headers: {
        'apikey': effectiveKey,
        'Authorization': 'Bearer $effectiveKey',
      },
    );
    _storage = SupabaseStorageClient(
      '${AppConstants.supabaseUrl}/storage/v1',
      {
        'apikey': effectiveKey,
        'Authorization': 'Bearer $effectiveKey',
      },
    );
  }

  // ─────────────────────────── AUTH ────────────────────────────────────────

  /// Mevcut kullanıcının profilini çeker (user_profiles tablosu)
  Future<UserProfileModel?> getCurrentUserProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      final data = await _db
          .from('user_profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data == null) return null;
      final map = Map<String, dynamic>.from(data as Map);
      map['email'] = user.email;
      return UserProfileModel.fromMap(map);
    } catch (e) {
      debugPrint('getCurrentUserProfile error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─────────────────────────── SCHOOLS ─────────────────────────────────────

  /// Tüm okulları, bağlı tahta ve öğretmen sayılarıyla birlikte ultra-hızlı çeker
  Future<List<SchoolModel>> getSchools() async {
    try {
      // 3 paralel sorgu: Okullar, tüm tahtaların okul id'leri ve tüm profiller (_db ile RLS'siz saf service-role)
      final results = await Future.wait([
        _db.from('schools').select().order('name', ascending: true),
        _db.from('boards').select('school_id'),
        _db.from('user_profiles').select('school_id, role'),
      ]);

      final schoolsData = (results[0] as List);
      final boardsData = (results[1] as List);
      final profilesData = (results[2] as List);

      // Tahta sayılarını haritala
      final boardCounts = <String, int>{};
      for (final b in boardsData) {
        final bm = b as Map;
        final sid = bm['school_id']?.toString();
        if (sid != null) {
          boardCounts[sid] = (boardCounts[sid] ?? 0) + 1;
        }
      }

      // Öğretmen ve Müdür sayılarını haritala
      final teacherCounts = <String, int>{};
      final adminCounts = <String, int>{};
      for (final p in profilesData) {
        final pm = p as Map;
        final sid = pm['school_id']?.toString();
        final role = pm['role']?.toString();
        if (sid != null) {
          if (role == 'admin') {
            adminCounts[sid] = (adminCounts[sid] ?? 0) + 1;
          } else {
            teacherCounts[sid] = (teacherCounts[sid] ?? 0) + 1;
          }
        }
      }

      return schoolsData.map((m) {
        final s = SchoolModel.fromMap(Map<String, dynamic>.from(m as Map));
        final tCount = teacherCounts[s.id] ?? 0;
        final aCount = adminCounts[s.id] ?? 0;
        return s.copyWith(
          boardCount: boardCounts[s.id] ?? 0,
          userCount: tCount,
          teacherCount: tCount,
          adminCount: aCount,
        );
      }).toList();
    } catch (e) {
      debugPrint('getSchools error: $e');
      return [];
    }
  }

  Future<SchoolModel?> createSchool({
    required String name,
    required String city,
    bool isLicensed = true,
    DateTime? licenseExpiresAt,
    String? licenseNotes,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name.trim(),
        'city': city.trim(),
        'is_licensed': isLicensed,
        'license_expires_at': (licenseExpiresAt ?? DateTime.now().add(const Duration(days: 365))).toIso8601String(),
        'license_notes': licenseNotes?.trim(),
      };
      final data = await _db
          .from('schools')
          .insert(payload)
          .select()
          .single();
      return SchoolModel.fromMap(data);
    } catch (e) {
      debugPrint('createSchool error: $e');
      rethrow;
    }
  }

  Future<void> updateSchool({
    required String schoolId,
    required String name,
    required String city,
    bool? isLicensed,
    DateTime? licenseExpiresAt,
    String? licenseNotes,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name.trim(),
        'city': city.trim(),
      };
      if (isLicensed != null) payload['is_licensed'] = isLicensed;
      if (licenseExpiresAt != null) payload['license_expires_at'] = licenseExpiresAt.toIso8601String();
      if (licenseNotes != null) payload['license_notes'] = licenseNotes.trim();

      await _db
          .from('schools')
          .update(payload)
          .eq('id', schoolId);
    } catch (e) {
      debugPrint('updateSchool error: $e');
      rethrow;
    }
  }

  Future<void> updateSchoolLicense({
    required String schoolId,
    required bool isLicensed,
    required DateTime licenseExpiresAt,
    String? licenseNotes,
  }) async {
    try {
      final payload = <String, dynamic>{
        'is_licensed': isLicensed,
        'license_expires_at': licenseExpiresAt.toIso8601String(),
      };
      if (licenseNotes != null) payload['license_notes'] = licenseNotes.trim();

      await _db
          .from('schools')
          .update(payload)
          .eq('id', schoolId);
    } catch (e) {
      debugPrint('updateSchoolLicense error: $e');
      rethrow;
    }
  }

  Future<void> deleteSchool(String schoolId) async {
    try {
      await _db.from('schools').delete().eq('id', schoolId);
    } catch (e) {
      debugPrint('deleteSchool error: $e');
      rethrow;
    }
  }

  /// Realtime school stream
  Stream<List<SchoolModel>> streamSchools() {
    return _client
        .from('schools')
        .stream(primaryKey: ['id'])
        .order('name', ascending: true)
        .map((rows) => rows.map((m) => SchoolModel.fromMap(m)).toList());
  }

  Stream<SchoolModel?> streamSchool(String schoolId) {
    return _client
        .from('schools')
        .stream(primaryKey: ['id'])
        .eq('id', schoolId)
        .map((rows) => rows.isNotEmpty ? SchoolModel.fromMap(rows.first) : null);
  }

  Future<SchoolModel?> getSchoolById(String schoolId) async {
    try {
      final data = await _db.from('schools').select().eq('id', schoolId).maybeSingle();
      if (data == null) return null;
      return SchoolModel.fromMap(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      debugPrint('getSchoolById error: $e');
      return null;
    }
  }

  /// Okulun tahta ve yetkili öğretmen sayılarıyla detaylı bilgilerini çeker
  Future<SchoolModel?> getSchoolDetails(String schoolId) async {
    try {
      final results = await Future.wait<dynamic>([
        _db.from('schools').select().eq('id', schoolId).maybeSingle(),
        _db.from('boards').select('id, is_online, is_locked').eq('school_id', schoolId),
        _db.from('user_profiles').select('id, role').eq('school_id', schoolId),
      ]);

      if (results[0] == null) return null;
      final schoolData = Map<String, dynamic>.from(results[0] as Map);
      final boardsData = (results[1] as List);
      final profilesData = (results[2] as List);

      int teacherCount = 0;
      int adminCount = 0;
      for (final p in profilesData) {
        final role = (p as Map)['role']?.toString();
        if (role == 'admin') {
          adminCount++;
        } else {
          teacherCount++;
        }
      }

      final school = SchoolModel.fromMap(schoolData);
      return school.copyWith(
        boardCount: boardsData.length,
        userCount: teacherCount,
        teacherCount: teacherCount,
        adminCount: adminCount,
      );
    } catch (e) {
      debugPrint('getSchoolDetails error: $e');
      return null;
    }
  }

  // ─────────────────────────── BOARDS ──────────────────────────────────────

  /// Realtime board stream — okul müdürü için school_id filtreli
  Stream<List<BoardModel>> streamBoards(String? schoolId) {
    var stream = _client.from('boards').stream(primaryKey: ['id']);
    if (schoolId != null) {
      stream = stream.eq('school_id', schoolId);
    }
    return stream
        .order('name', ascending: true)
        .map((rows) => rows.map((m) => BoardModel.fromMap(m)).toList());
  }

  /// Tüm tahtaları çek (Sistem Yöneticisi için filtre yok)
  Future<List<BoardModel>> getBoards(String? schoolId) async {
    try {
      var query = _db.from('boards').select();
      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }
      final data = await query.order('name', ascending: true);
      return (data as List)
          .map((m) => BoardModel.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getBoards error: $e');
      return [];
    }
  }

  Future<void> toggleBoardLock({
    required String boardId,
    required bool newUnlocked,
    required String actorName,
  }) async {
    final updateData = <String, dynamic>{'is_unlocked': newUnlocked};
    if (newUnlocked) {
      updateData['last_unlocked_by'] = actorName;
    } else {
      updateData['last_locked_by'] = actorName;
    }
    await _db.from('boards').update(updateData).eq('id', boardId);
  }

  Future<void> lockAllBoards({
    required String schoolId,
    required String actorName,
  }) async {
    await _db
        .from('boards')
        .update({
          'is_unlocked': false,
          'last_locked_by': 'Yönetici (Web Panel)',
        })
        .eq('school_id', schoolId)
        .eq('is_active', true);
  }

  Future<void> unlockAllBoards({
    required String schoolId,
    required String actorName,
  }) async {
    await _db
        .from('boards')
        .update({
          'is_unlocked': true,
          'last_unlocked_by': 'Yönetici (Web Panel)',
        })
        .eq('school_id', schoolId)
        .eq('is_active', true);
  }

  Future<void> updateBoard({
    required String boardId,
    required String name,
    String? grade,
    String? branch,
    int? autoLockMinutes,
    required bool isActive,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'grade': grade?.trim() ?? '',
      'branch': branch?.trim() ?? '',
      'is_active': isActive,
    };
    if (autoLockMinutes != null) {
      data['auto_lock_minutes'] = autoLockMinutes;
    }
    await _db.from('boards').update(data).eq('id', boardId);
  }

  Future<void> deleteBoard(String boardId) async {
    await _db.from('boards').delete().eq('id', boardId);
  }

  /// Akıllı tahtayı uzaktan kapatma komutu gönderir (Windows KioskLockApp shutdown yapar)
  Future<void> sendRemoteShutdown(String boardId) async {
    try {
      await _db.from('boards').update({
        'remote_command': 'SHUTDOWN',
      }).eq('id', boardId);
    } catch (e) {
      debugPrint('sendRemoteShutdown error: $e');
      rethrow;
    }
  }

  /// Birden fazla akıllı tahtayı toplu olarak uzaktan kapatma komutu gönderir
  Future<void> sendBulkRemoteShutdown(List<String> boardIds) async {
    try {
      if (boardIds.isEmpty) return;
      await _db.from('boards').update({
        'remote_command': 'SHUTDOWN',
      }).filter('id', 'in', boardIds);
    } catch (e) {
      debugPrint('sendBulkRemoteShutdown error: $e');
      rethrow;
    }
  }

  /// Akıllı tahtaya uzaktan uygulama bütünlüğü onarım komutu gönderir (TahtaRepair çalıştırılır)
  Future<void> sendRepairIntegrityCommand(String boardId) async {
    try {
      await _db.from('boards').update({
        'remote_command': 'REPAIR_INTEGRITY',
      }).eq('id', boardId);
    } catch (e) {
      debugPrint('sendRepairIntegrityCommand error: $e');
      rethrow;
    }
  }

  /// Birden fazla akıllı tahtaya toplu olarak uzaktan uygulama bütünlüğü onarım komutu gönderir
  Future<void> sendBulkRepairIntegrityCommand(List<String> boardIds) async {
    try {
      if (boardIds.isEmpty) return;
      await _db.from('boards').update({
        'remote_command': 'REPAIR_INTEGRITY',
      }).filter('id', 'in', boardIds);
    } catch (e) {
      debugPrint('sendBulkRepairIntegrityCommand error: $e');
      rethrow;
    }
  }

  /// 6 haneli eşleştirme kodu ile yeni tahta ekle (board_pairings mantığı)
  Future<void> pairBoard({
    required String pairingCode,
    required String schoolId,
    required String name,
    String? grade,
    String? branch,
    int? autoLockMinutes,
  }) async {
    // 1. Pairing kaydını bul
    final pairingData = await _client
        .from('board_pairings')
        .select()
        .eq('pairing_code', pairingCode)
        .eq('status', 'pending')
        .maybeSingle();

    if (pairingData == null) {
      throw Exception('Geçersiz veya süresi dolmuş eşleştirme kodu!');
    }

    // 2. offline_secret üret
    final offlineSecret = _generateOfflineSecret();

    // 3. Boards tablosuna ekle
    final insertData = <String, dynamic>{
      'school_id': schoolId,
      'name': name.trim(),
      'grade': grade?.trim() ?? '',
      'branch': branch?.trim() ?? '',
      'is_active': true,
      'is_unlocked': false,
      'offline_secret': offlineSecret,
    };
    if (autoLockMinutes != null) {
      insertData['auto_lock_minutes'] = autoLockMinutes;
    }

    final boardResponse = await _client
        .from('boards')
        .insert(insertData)
        .select()
        .single();

    // 4. board_pairings kaydını güncelle (completed)
    await _client.from('board_pairings').update({
      'board_id': boardResponse['id'],
      'offline_secret': offlineSecret,
      'status': 'completed',
    }).eq('pairing_code', pairingCode);
  }

  String _generateOfflineSecret() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(16, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  // ─────────────────────────── USERS ───────────────────────────────────────

  Map<String, String>? _cachedEmailMap;
  DateTime? _emailCacheTime;

  Future<Map<String, String>> _getEmailMap({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedEmailMap != null &&
        _emailCacheTime != null &&
        now.difference(_emailCacheTime!).inMinutes < 15) {
      return _cachedEmailMap!;
    }

    final emailMap = <String, String>{};
    try {
      final authUsers = await _adminClient.auth.admin
          .listUsers(perPage: 1000)
          .timeout(const Duration(seconds: 2), onTimeout: () => []);
      for (final u in authUsers) {
        if (u.email != null) {
          emailMap[u.id] = u.email!;
        }
      }
      if (emailMap.isNotEmpty) {
        _cachedEmailMap = emailMap;
        _emailCacheTime = now;
      }
    } catch (e) {
      debugPrint('Auth users fetch notice: $e');
      if (_cachedEmailMap != null) return _cachedEmailMap!;
    }
    return _cachedEmailMap ?? emailMap;
  }

  /// Belirtilen okula veya sisteme ait kullanıcıları (öğretmen ve yöneticileri) REST ile anında çeker.
  /// Okul müdürlerini (admin) listenin EN BAŞINA koyar, ardından öğretmenleri alfabetik sıralar.
  Future<List<UserProfileModel>> getUsers(String? schoolId) async {
    try {
      final cleanSchoolId = (schoolId != null &&
              schoolId.trim().isNotEmpty &&
              schoolId.trim() != 'null')
          ? schoolId.trim()
          : null;

      // 1. Profil, okul listesi ve e-posta haritasını (varsa cache'den) tamamen paralel çek (_db ile RLS'siz saf service-role)
      final results = await Future.wait<dynamic>([
        cleanSchoolId != null
            ? _db.from('user_profiles').select().eq('school_id', cleanSchoolId)
            : _db.from('user_profiles').select(),
        _db.from('schools').select('id, name'),
        _getEmailMap(),
      ]);

      final profilesData = (results[0] as List);
      final schoolsData = (results[1] as List);
      final emailMap = (results[2] as Map<String, String>);

      final schoolMap = <String, String>{};
      for (final s in schoolsData) {
        final sm = s as Map;
        final sid = sm['id']?.toString();
        final sname = sm['name']?.toString();
        if (sid != null && sname != null) {
          schoolMap[sid] = sname;
        }
      }

      // 2. UserProfileModel nesnelerini oluştur
      final userList = profilesData.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        final uid = map['id']?.toString() ?? '';
        if (emailMap.containsKey(uid)) {
          map['email'] = emailMap[uid];
        }
        final sid = map['school_id']?.toString();
        final sName = sid != null ? schoolMap[sid] : null;
        return UserProfileModel.fromMap(map, schoolName: sName);
      }).toList();

      // 3. SIRALAMA: Müdürler / Yöneticiler (role == admin) EN ÜSTE, sonra öğretmenler
      userList.sort((a, b) {
        if (a.role == UserRole.admin && b.role != UserRole.admin) return -1;
        if (a.role != UserRole.admin && b.role == UserRole.admin) return 1;
        return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });

      return userList;
    } catch (e, st) {
      debugPrint('getUsers error: $e\n$st');
      rethrow;
    }
  }

  /// user_profiles tablosundan kullanıcıları çek (stream - realtime)
  Stream<List<UserProfileModel>> streamUsers(String? schoolId) {
    var stream = _client.from('user_profiles').stream(primaryKey: ['id']);
    if (schoolId != null) {
      stream = stream.eq('school_id', schoolId);
    }
    return stream
        .order('full_name', ascending: true)
        .map((rows) => rows.map((m) => UserProfileModel.fromMap(m)).toList());
  }

  /// Yeni kullanıcı oluştur (auth.users + user_profiles)
  Future<void> createUser({
    required String email,
    required String password,
    required String fullName,
    required String schoolId,
    required String role,
  }) async {
    // 1. Auth kullanıcısı oluştur (service role)
    final response = await _adminClient.auth.admin.createUser(
      AdminUserAttributes(
        email: email.trim(),
        password: password.trim(),
        emailConfirm: true,
      ),
    );

    final newUserId = response.user!.id;

    // 2. user_profiles'a ekle (_db saf service-role)
    await _db.from('user_profiles').insert({
      'id': newUserId,
      'school_id': schoolId,
      'role': role,
      'full_name': fullName.trim(),
    });
    _cachedEmailMap = null;
  }

  /// Kullanıcı şifresini yönetici olarak sıfırla / güncelle
  Future<void> updateUserPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      await _adminClient.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(password: newPassword.trim()),
      );
    } catch (e) {
      debugPrint('updateUserPassword error: $e');
      rethrow;
    }
  }

  /// Kullanıcı e-postasını yönetici olarak güncelle
  Future<void> updateUserEmail({
    required String userId,
    required String newEmail,
  }) async {
    try {
      await _adminClient.auth.admin.updateUserById(
        userId,
        attributes: AdminUserAttributes(
          email: newEmail.trim(),
          emailConfirm: true,
        ),
      );
      _cachedEmailMap = null;
    } catch (e) {
      debugPrint('updateUserEmail error: $e');
      rethrow;
    }
  }

  /// Profil bilgilerini (ad, soyad, rol, okul) güncelle
  Future<void> updateUserProfile({
    required String userId,
    required String fullName,
    required String role,
    String? schoolId,
  }) async {
    final updateData = <String, dynamic>{
      'full_name': fullName.trim(),
      'role': role,
    };
    if (schoolId != null) updateData['school_id'] = schoolId;

    await _db
        .from('user_profiles')
        .update(updateData)
        .eq('id', userId);
  }

  /// Kullanıcıyı ve profilini sistemden kalıcı olarak sil
  Future<void> deleteUser(String userId) async {
    try {
      // Önce profil kaydını sil
      await _db.from('user_profiles').delete().eq('id', userId);
      // Ardından Auth kullanıcısını sil
      await _adminClient.auth.admin.deleteUser(userId);
      _cachedEmailMap = null;
    } catch (e) {
      debugPrint('deleteUser error: $e');
      rethrow;
    }
  }

  Future<void> assignUserToSchool({
    required String userId,
    required String schoolId,
    required String role,
  }) async {
    await _db.from('user_profiles').upsert({
      'id': userId,
      'school_id': schoolId,
      'role': role,
    });
  }

  // ─────────────────────────── APP VERSIONS ────────────────────────────────

  Future<List<AppVersionModel>> getAppVersions() async {
    try {
      final data = await _db
          .from('app_versions')
          .select()
          .order('created_at', ascending: false);
      return (data as List)
          .map((m) => AppVersionModel.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('getAppVersions error: $e');
      return [];
    }
  }

  Future<void> createAppVersion({
    required String versionNumber,
    required String downloadUrl,
  }) async {
    await _db.from('app_versions').insert({
      'version_number': versionNumber.trim(),
      'download_url': downloadUrl.trim(),
    });
  }

  Future<void> updateAppVersion({
    required String id,
    required String versionNumber,
    required String downloadUrl,
  }) async {
    await _db.from('app_versions').update({
      'version_number': versionNumber.trim(),
      'download_url': downloadUrl.trim(),
    }).eq('id', id);
  }

  /// Sürümü veritabanından (Service-Role) ve ilişkili Storage dosyasından temizler
  Future<void> deleteAppVersion(
    String id, {
    String? downloadUrl,
    String? versionNumber,
  }) async {
    try {
      // 1. Storage'daki ilişkili güncelleme paketini temizle
      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        try {
          final uri = Uri.tryParse(downloadUrl);
          if (uri != null) {
            final segments = uri.pathSegments;
            final updatesIndex = segments.indexOf('updates');
            if (updatesIndex != -1 && updatesIndex < segments.length - 1) {
              final fileName = segments.sublist(updatesIndex + 1).join('/');
              if (fileName.isNotEmpty) {
                await _storage.from('updates').remove([fileName]);
                debugPrint('Storage paketi silindi: $fileName');
              }
            }
          }
        } catch (storageErr) {
          debugPrint('Storage dosya silme uyarısı: $storageErr');
        }
      }

      // 2. Veritabanından kesin olarak sil (Service-Role ile RLS kısıtlamalarını aşar)
      await _db.from('app_versions').delete().eq('id', id);
    } catch (e) {
      debugPrint('deleteAppVersion error: $e');
      rethrow;
    }
  }

  /// En güncel sürüm numarasını çeker (en son yayınlanan sürüm neyse o)
  Future<String?> getLatestVersionNumber() async {
    try {
      final data = await _db
          .from('app_versions')
          .select('version_number')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data != null && data['version_number'] != null) {
        return data['version_number'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('getLatestVersionNumber error: $e');
      return null;
    }
  }

  /// Supabase Storage 'updates' kovasına dosya yükler ve public URL döner
  Future<String> uploadUpdatePackage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      // Temiz ve sabit dosya adı (rastgele zaman damgası olmadan orijinal dosya adını korur)
      final cleanName = fileName.split(RegExp(r'[\\/]')).last.trim();
      final safeName = cleanName.isNotEmpty ? cleanName : 'TahtaUpdate.zip';
      await _storage.from('updates').uploadBinary(
        safeName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final publicUrl = _storage.from('updates').getPublicUrl(safeName);
      return publicUrl;
    } catch (e) {
      debugPrint('uploadUpdatePackage error: $e');
      rethrow;
    }
  }

  // ─────────────────────────── MEDIA & ANNOUNCEMENTS ───────────────────────

  static BroadcastPackageModel? _cachedActivePackage;
  static final List<BroadcastPackageModel> _cachedPackages = [];
  static final List<BroadcastPackageModel> _cachedTemplates = [];

  /// Aktif yayın paketini getirir (önbellek veya Supabase)
  Future<BroadcastPackageModel?> getActivePackage(String? schoolId) async {
    try {
      var filter = _db
          .from('broadcast_packages')
          .select()
          .eq('is_active', true)
          .eq('is_template', false);

      if (schoolId != null) {
        filter = filter.eq('school_id', schoolId);
      }
      final data = await filter
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data != null) {
        _cachedActivePackage = BroadcastPackageModel.fromMap(data);
        return _cachedActivePackage;
      }
    } catch (_) {
      // broadcast_packages tablosu henüz yoksa bellek önbelleği devrededir
    }
    return _cachedActivePackage;
  }

  /// Tüm yayınlanan paketlerin geçmişini getirir
  Future<List<BroadcastPackageModel>> getAllPackages(String? schoolId) async {
    try {
      var filter = _db
          .from('broadcast_packages')
          .select()
          .eq('is_template', false);

      if (schoolId != null) {
        filter = filter.eq('school_id', schoolId);
      }
      final list = await filter.order('created_at', ascending: false);
      if (list.isNotEmpty) {
        final dbPkgs = list.map((x) => BroadcastPackageModel.fromMap(x)).toList();
        for (final p in dbPkgs) {
          if (!_cachedPackages.any((c) => c.id == p.id)) {
            _cachedPackages.add(p);
          }
        }
      }
    } catch (_) {}

    return List.from(_cachedPackages);
  }

  /// Hazır şablonları ve hazır paketleri getirir
  Future<List<BroadcastPackageModel>> getTemplates(String? schoolId) async {
    final list = <BroadcastPackageModel>[];

    // 1. Sistem Varsayılan Hazır Şablonları (Otomatik Eklenir)
    list.addAll(_getBuiltInSchoolTemplates());

    // 2. Kullanıcının Kaydettiği Şablonlar
    try {
      var filter = _db
          .from('broadcast_packages')
          .select()
          .eq('is_template', true);

      if (schoolId != null) {
        filter = filter.eq('school_id', schoolId);
      }
      final dbTemplates = await filter.order('created_at', ascending: false);
      if (dbTemplates.isNotEmpty) {
        for (final t in dbTemplates) {
          final model = BroadcastPackageModel.fromMap(t);
          if (!list.any((x) => x.id == model.id)) {
            list.add(model);
          }
        }
      }
    } catch (_) {}

    for (final t in _cachedTemplates) {
      if (!list.any((x) => x.id == t.id)) {
        list.add(t);
      }
    }

    return list;
  }

  /// Bir paketi hazır şablon olarak kaydeder
  Future<void> saveAsTemplate({
    required String packageId,
    required String templateName,
  }) async {
    final pkg = _cachedPackages.cast<BroadcastPackageModel?>().firstWhere(
      (p) => p?.id == packageId,
      orElse: () => _cachedActivePackage,
    );
    if (pkg == null) return;

    final template = pkg.copyWith(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      isTemplate: true,
      templateName: templateName.trim(),
      isActive: false,
      createdAt: DateTime.now(),
    );

    _cachedTemplates.insert(0, template);
    try {
      await _db.from('broadcast_packages').upsert(template.toMap());
    } catch (_) {}
  }

  /// Paketi geçmişten siler
  Future<void> deletePackage(String packageId) async {
    _cachedPackages.removeWhere((p) => p.id == packageId);
    _cachedTemplates.removeWhere((p) => p.id == packageId);
    if (_cachedActivePackage?.id == packageId) {
      _cachedActivePackage = null;
    }
    try {
      await _db.from('broadcast_packages').delete().eq('id', packageId);
    } catch (_) {}
  }

  /// Aktif yayın paketini kaydeder
  Future<void> saveActivePackage(BroadcastPackageModel package) async {
    _cachedActivePackage = package;
    _cachedPackages.removeWhere((p) => p.id == package.id);
    _cachedPackages.insert(0, package);
    try {
      await _db.from('broadcast_packages').upsert(package.toMap());
    } catch (_) {
      // Tablo yoksa sessizce geç
    }
  }

  /// Önceden yayınlanmış bir pakete sonradan açılan yeni cihazları ekler (Tekrardan yüklenmiş gibi gider)
  Future<void> addBoardsToPackage({
    required String packageId,
    required List<String> boardIds,
  }) async {
    try {
      final pkg = _cachedPackages.cast<BroadcastPackageModel?>().firstWhere(
        (p) => p?.id == packageId,
        orElse: () => _cachedActivePackage,
      );

      if (pkg == null) {
        throw Exception('Hedef paket bulunamadı!');
      }

      final List<String> uploadedStorageFiles = [];
      final List<Map<String, dynamic>> dispatchedItems = [];

      for (int i = 0; i < pkg.items.length; i++) {
        final item = pkg.items[i];
        String imageUrl = item.imageUrl ?? '';

        // Eğer afişin base64'ü varsa yeni cihazın indirebilmesi için geçici olarak storage'a yükle
        if (item.isPoster && item.imageBase64 != null && item.imageBase64!.isNotEmpty) {
          try {
            final bytes = base64Decode(item.imageBase64!);
            final safeName = 'media_${DateTime.now().millisecondsSinceEpoch}_add_$i.jpg';
            await _storage.from('updates').uploadBinary(
              safeName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
            uploadedStorageFiles.add(safeName);
            imageUrl = _storage.from('updates').getPublicUrl(safeName);
          } catch (_) {}
        }

        dispatchedItems.add({
          'id': item.id,
          'type': item.type,
          'title': item.title,
          'content': item.content,
          'image_url': imageUrl,
        });
      }

      final payloadMap = {
        'package_id': pkg.id,
        'package_title': pkg.title,
        'package_version': pkg.version,
        'valid_from': pkg.validFrom.toUtc().toIso8601String(),
        'valid_to': pkg.validTo.toUtc().toIso8601String(),
        'items': dispatchedItems,
      };

      final commandString = 'MEDIA_DISPATCH:${jsonEncode(payloadMap)}';

      for (final boardId in boardIds) {
        await _db.from('boards').update({
          'remote_command': commandString,
          'active_media_id': pkg.id,
        }).eq('id', boardId);
      }

      // Paketin hedef tahtalar listesini güncelle
      final updatedBoards = Set<String>.from(pkg.targetBoardIds)..addAll(boardIds);
      final updatedPkg = pkg.copyWith(targetBoardIds: updatedBoards.toList());
      await saveActivePackage(updatedPkg);

      if (uploadedStorageFiles.isNotEmpty) {
        Future.delayed(const Duration(seconds: 45), () async {
          try {
            await _storage.from('updates').remove(uploadedStorageFiles);
          } catch (_) {}
        });
      }
    } catch (e) {
      debugPrint('addBoardsToPackage error: $e');
      rethrow;
    }
  }

  /// Çoklu görsel afiş ve çoklu duyuru içeren versiyonlu yayın paketini tahtalara gönderir.
  Future<BroadcastPackageModel> dispatchPackageToBoards({
    required List<String> boardIds,
    required String title,
    required String version,
    required DateTime validFrom,
    required DateTime validTo,
    required List<Map<String, dynamic>> posterInputs,
    required List<Map<String, dynamic>> announcementInputs,
    int rotationIntervalSeconds = 15,
    String? schoolId,
  }) async {
    try {
      final packageId = 'pkg_${DateTime.now().millisecondsSinceEpoch}';
      final List<PackageItem> items = [];
      final List<String> uploadedStorageFiles = [];

      // 1. Afiş görsellerini işle ve yükle
      for (int i = 0; i < posterInputs.length; i++) {
        final p = posterInputs[i];
        final pId = p['id']?.toString() ?? 'poster_${DateTime.now().millisecondsSinceEpoch}_$i';
        final pTitle = p['title']?.toString() ?? 'Afiş ${i + 1}';
        final pContent = p['content']?.toString() ?? '';

        String? imageUrl = p['imageUrl']?.toString();
        String? thumbBase64 = p['thumbnailBase64']?.toString();
        String? imgBase64 = p['imageBase64']?.toString();

        final bytes = p['bytes'] as Uint8List?;
        final fileName = p['fileName']?.toString() ?? 'poster_$i.jpg';

        if (bytes != null && bytes.isNotEmpty) {
          // Canlı önizleme ve sonradan yeni cihaz ekleme için base64 sakla
          thumbBase64 = base64Encode(bytes);
          imgBase64 = thumbBase64;

          // Tahtanın yerel diskine çekebilmesi için Storage updates kovasına yükle
          // Türkçe karakter, boşluk ve özel simgelerden arındırılmış %100 güvenli S3 anahtarı üretir
          final safeName = _sanitizeStorageFileName(fileName, '$i');
          await _storage.from('updates').uploadBinary(
            safeName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
          uploadedStorageFiles.add(safeName);
          imageUrl = _storage.from('updates').getPublicUrl(safeName);
        }

        items.add(PackageItem(
          id: pId,
          type: 'poster',
          title: pTitle,
          content: pContent,
          imageUrl: imageUrl,
          thumbnailBase64: thumbBase64,
          imageBase64: imgBase64,
        ));
      }

      // 2. Metin duyurularını ekle
      for (int i = 0; i < announcementInputs.length; i++) {
        final a = announcementInputs[i];
        final aId = a['id']?.toString() ?? 'ann_${DateTime.now().millisecondsSinceEpoch}_$i';
        final aTitle = a['title']?.toString() ?? 'Duyuru ${i + 1}';
        final aContent = a['content']?.toString() ?? '';

        items.add(PackageItem(
          id: aId,
          type: 'announcement',
          title: aTitle,
          content: aContent,
        ));
      }

      final packageModel = BroadcastPackageModel(
        id: packageId,
        schoolId: schoolId,
        title: title.trim(),
        version: version.trim(),
        validFrom: validFrom,
        validTo: validTo,
        items: items,
        isActive: true,
        targetBoardIds: boardIds,
        rotationIntervalSeconds: rotationIntervalSeconds,
        createdAt: DateTime.now(),
      );

      // Tahtalara gidecek JSON yükü
      final payloadMap = {
        'package_id': packageId,
        'package_title': title.trim(),
        'package_version': version.trim(),
        'rotation_interval_seconds': rotationIntervalSeconds,
        'duration_seconds': rotationIntervalSeconds,
        'valid_from': validFrom.toUtc().toIso8601String(),
        'valid_to': validTo.toUtc().toIso8601String(),
        'items': items.map((x) => {
          'id': x.id,
          'type': x.type,
          'title': x.title,
          'content': x.content,
          'image_url': x.imageUrl ?? '',
        }).toList(),
      };

      final commandString = 'MEDIA_DISPATCH:${jsonEncode(payloadMap)}';

      for (final boardId in boardIds) {
        await _db.from('boards').update({
          'remote_command': commandString,
          'active_media_id': packageId,
        }).eq('id', boardId);
      }

      // Paketi kaydet
      await saveActivePackage(packageModel);

      // Kapalı tahtaların da afişleri indirebilmesi için görseller sunucuda 3 gün tutulur.
      // 3 günden eski eski paket kalıntıları arka planda otomatik süpürülür.
      cleanupExpiredMediaFiles(retentionDays: 3).catchError((_) => 0);

      return packageModel;
    } catch (e) {
      debugPrint('dispatchPackageToBoards error: $e');
      rethrow;
    }
  }

  /// Sistemle gelen hazır okul şablonları
  List<BroadcastPackageModel> _getBuiltInSchoolTemplates() {
    final now = DateTime.now();
    return [
      BroadcastPackageModel(
        id: 'builtin_cumhuriyet',
        title: '29 Ekim Cumhuriyet Bayramı Tören Programı',
        version: 'v1.0',
        validFrom: now,
        validTo: now.add(const Duration(days: 7)),
        isTemplate: true,
        templateName: '🏛️ Cumhuriyet Bayramı & Milli Günler',
        items: const [
          PackageItem(
            id: 'b_ann_1',
            type: 'announcement',
            title: 'Kutlama Töreni Saat Bilgisi',
            content: '29 Ekim Cumhuriyet Bayramı kutlama töreni saat 10:00\'da okul bahçesinde icra edilecektir.',
          ),
          PackageItem(
            id: 'b_ann_2',
            type: 'announcement',
            title: 'Kıyafet ve Düzen',
            content: 'Tüm öğrenci ve öğretmenlerimizin tören düzenine uygun kıyafetle hazır bulunmaları rica olunur.',
          ),
        ],
        createdAt: now,
      ),
      BroadcastPackageModel(
        id: 'builtin_tubitak',
        title: 'TÜBİTAK 4006 Bilim Şenliği ve Proje Fuarı',
        version: 'v1.0',
        validFrom: now,
        validTo: now.add(const Duration(days: 5)),
        isTemplate: true,
        templateName: '🔬 TÜBİTAK & Bilim Fuarı',
        items: const [
          PackageItem(
            id: 'b_ann_3',
            type: 'announcement',
            title: 'Bilim Fuarı Açılışı',
            content: 'Öğrencilerimizin hazırladığı 24 bilimsel proje fuar alanında sergilenmektedir. Tüm sınıflarımız sırayla ziyaret edecektir.',
          ),
        ],
        createdAt: now,
      ),
      BroadcastPackageModel(
        id: 'builtin_kutuphane',
        title: 'Her Gün 1 Ders Saati Kitap Okuma Vakti',
        version: 'v1.0',
        validFrom: now,
        validTo: now.add(const Duration(days: 30)),
        isTemplate: true,
        templateName: '📚 Kütüphane & Okuma Saati',
        items: const [
          PackageItem(
            id: 'b_ann_4',
            type: 'announcement',
            title: 'Kitap Okuma Etkinliği',
            content: 'Her gün 3. ders saatinin ilk 20 dakikası tüm sınıflarımızda kitap okuma vaktidir.',
          ),
        ],
        createdAt: now,
      ),
      BroadcastPackageModel(
        id: 'builtin_kurallar',
        title: 'Akıllı Tahta ve Sınıf Düzeni Kuralları',
        version: 'v1.0',
        validFrom: now,
        validTo: now.add(const Duration(days: 30)),
        isTemplate: true,
        templateName: '🔔 Sınıf & Tahta Kuralları',
        items: const [
          PackageItem(
            id: 'b_ann_5',
            type: 'announcement',
            title: 'Tahta Kullanım İlkeleri',
            content: '1. Tahtayı yalnızca ders amaçlı kullanalım.\n2. Ders bitiminde tahtanın kilitlendiğinden emin olalım.\n3. Nöbetçi öğretmen talimatlarına uyalım.',
          ),
        ],
        createdAt: now,
      ),
    ];
  }

  /// Mevcut yayın paketinin geçerlilik süresini uzatır veya kısaltır
  Future<void> updatePackageDuration({
    required List<String> boardIds,
    required String packageId,
    required DateTime validFrom,
    required DateTime validTo,
  }) async {
    try {
      final payloadMap = {
        'package_id': packageId,
        'valid_from': validFrom.toUtc().toIso8601String(),
        'valid_to': validTo.toUtc().toIso8601String(),
      };
      final commandString = 'MEDIA_UPDATE_DURATION:${jsonEncode(payloadMap)}';

      for (final boardId in boardIds) {
        await _db.from('boards').update({
          'remote_command': commandString,
        }).eq('id', boardId);
      }

      if (_cachedActivePackage != null) {
        _cachedActivePackage = _cachedActivePackage!.copyWith(
          validFrom: validFrom,
          validTo: validTo,
        );
        await saveActivePackage(_cachedActivePackage!);
      }
    } catch (e) {
      debugPrint('updatePackageDuration error: $e');
      rethrow;
    }
  }

  /// Tekil afiş/duyuru gönderimi (Geriye uyumluluk için)
  Future<void> dispatchMediaToBoards({
    required List<String> boardIds,
    required String type,
    required String title,
    required String content,
    String? imageUrl,
    required DateTime validFrom,
    required DateTime validTo,
  }) async {
    await dispatchPackageToBoards(
      boardIds: boardIds,
      title: title,
      version: 'v1.0',
      validFrom: validFrom,
      validTo: validTo,
      posterInputs: type == 'poster'
          ? [{'id': 'poster_1', 'title': title, 'content': content, 'imageUrl': imageUrl}]
          : [],
      announcementInputs: type == 'announcement'
          ? [{'id': 'ann_1', 'title': title, 'content': content}]
          : [],
    );
  }

  /// Seçilen tahtaların afiş/duyurusunu varsayılan (DEFAULT) durumuna döndürür
  Future<void> resetBoardsMedia(List<String> boardIds) async {
    try {
      for (final boardId in boardIds) {
        await _db.from('boards').update({
          'remote_command': 'MEDIA_RESET',
          'active_media_id': 'DEFAULT',
        }).eq('id', boardId);
      }

      if (_cachedActivePackage != null) {
        _cachedActivePackage = _cachedActivePackage!.copyWith(isActive: false);
        try {
          await _db
              .from('broadcast_packages')
              .update({'is_active': false})
              .eq('id', _cachedActivePackage!.id);
        } catch (_) {}
      }

      cleanupTemporaryMediaFiles();
    } catch (e) {
      debugPrint('resetBoardsMedia error: $e');
      rethrow;
    }
  }

  /// Supabase Storage (S3) için Türkçe karakter, boşluk ve özel sembollerden arındırılmış güvenli anahtar üretir.
  String _sanitizeStorageFileName(String originalFileName, String suffix) {
    String ext = '.jpg';
    final dotIndex = originalFileName.lastIndexOf('.');
    if (dotIndex != -1 && dotIndex < originalFileName.length - 1) {
      final rawExt = originalFileName.substring(dotIndex).toLowerCase().trim();
      if (RegExp(r'^\.[a-z0-9]{2,5}$').hasMatch(rawExt)) {
        ext = rawExt;
      }
    }
    return 'media_${DateTime.now().millisecondsSinceEpoch}_$suffix$ext';
  }

  /// Afiş görselini geçici olarak yükler ve indirme URL'ini döner
  Future<String> uploadMediaImage({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final safeName = _sanitizeStorageFileName(fileName, 'single');
      await _storage.from('updates').uploadBinary(
        safeName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      final publicUrl = _storage.from('updates').getPublicUrl(safeName);
      return publicUrl;
    } catch (e) {
      debugPrint('uploadMediaImage error: $e');
      rethrow;
    }
  }

  /// Supabase Storage updates kovasındaki 3 günden (retentionDays) eski geçici medya kalıntılarını otomatik süpürür.
  /// Tahtaların afişleri yerel disklerine çekebilmeleri için yeni yüklenen afişler en az 3 gün sunucuda kalır.
  Future<int> cleanupExpiredMediaFiles({int retentionDays = 3}) async {
    try {
      final files = await _storage.from('updates').list();
      final toDelete = <String>[];
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));

      for (final file in files) {
        // Tahta güncelleme paketlerini (.zip / .exe) ASLA silme
        if (file.name.endsWith('.zip') || file.name.endsWith('.exe')) continue;

        if (file.name.startsWith('media_')) {
          // Dosya adı deseni: media_{timestamp}_{index}_{fileName}
          final parts = file.name.split('_');
          if (parts.length >= 2) {
            final ms = int.tryParse(parts[1]);
            if (ms != null) {
              final fileDate = DateTime.fromMillisecondsSinceEpoch(ms);
              if (fileDate.isBefore(cutoff)) {
                toDelete.add(file.name);
                continue;
              }
            }
          }
          if (file.createdAt != null) {
            try {
              final dt = DateTime.parse(file.createdAt!);
              if (dt.isBefore(cutoff)) {
                toDelete.add(file.name);
              }
            } catch (_) {}
          }
        }
      }

      if (toDelete.isNotEmpty) {
        await _storage.from('updates').remove(toDelete);
        debugPrint('3 günden eski medya kalıntıları temizlendi (${toDelete.length} dosya).');
        return toDelete.length;
      }
      return 0;
    } catch (e) {
      debugPrint('cleanupExpiredMediaFiles hatası: $e');
      return 0;
    }
  }

  /// Supabase Storage updates kovasındaki eski geçici medya kalıntılarını temizler
  Future<int> cleanupTemporaryMediaFiles() async {
    try {
      final files = await _storage.from('updates').list();
      final toDelete = <String>[];
      for (final file in files) {
        if (file.name.startsWith('media_') || file.name.startsWith('test')) {
          toDelete.add(file.name);
        }
      }
      if (toDelete.isNotEmpty) {
        await _storage.from('updates').remove(toDelete);
        debugPrint('Geçici medya kalıntıları temizlendi (${toDelete.length} dosya).');
        return toDelete.length;
      }
      return 0;
    } catch (e) {
      debugPrint('cleanupTemporaryMediaFiles hatası: $e');
      return 0;
    }
  }

  // ────────────────────────── SUPPORT TICKETS ───────────────────────────

  /// Tüm sorun bildirimlerini (destek biletlerini) getirir
  Future<List<SupportTicketModel>> getSupportTickets({
    String? status,
    String? schoolId,
  }) async {
    try {
      var query = _db.from('support_tickets').select();
      if (status != null && status != 'Tümü') {
        query = query.eq('status', status);
      }
      if (schoolId != null) {
        query = query.eq('school_id', schoolId);
      }
      final response = await query.order('created_at', ascending: false);
      final list = (response as List).map((m) {
        return SupportTicketModel.fromMap(m as Map<String, dynamic>);
      }).toList();
      return list;
    } catch (e) {
      debugPrint('getSupportTickets error: $e');
      return [];
    }
  }

  /// Sorun bildirimleri akışını dinler (realtime)
  Stream<List<SupportTicketModel>> streamSupportTickets() {
    return _client
        .from('support_tickets')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((m) => SupportTicketModel.fromMap(m))
            .toList());
  }

  /// Sorun durumunu günceller ('pending', 'in_progress', 'resolved', 'rejected')
  Future<void> updateTicketStatus({
    required String ticketId,
    required String status,
    String? adminNotes,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (adminNotes != null) {
      updateData['admin_notes'] = adminNotes.trim();
    }
    await _db.from('support_tickets').update(updateData).eq('id', ticketId);
  }

  /// Destek talebini siler
  Future<void> deleteSupportTicket(String ticketId) async {
    await _db.from('support_tickets').delete().eq('id', ticketId);
  }
}

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dartz/dartz.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/itinerary_repository.dart';
import '../../domain/entities/itinerary_group.dart';
import '../../domain/entities/itinerary_item.dart';
import '../../domain/entities/emergency_contacts.dart';
import '../models/itinerary_group_dto.dart';
import '../models/itinerary_item_dto.dart';
import '../../domain/entities/guide_mission.dart';
import '../../../home/domain/entities/mission_entity.dart';
import '../../domain/entities/menu_item.dart';
import '../models/menu_item_dto.dart';

@LazySingleton(as: ItineraryRepository)
class ItineraryRepositoryImpl implements ItineraryRepository {
  final SupabaseClient _supabaseClient;

  ItineraryRepositoryImpl(this._supabaseClient);

  @override
  Future<Either<Exception, ItineraryGroupEntity>> getGroupDetails(
    String groupId,
  ) async {
    try {
      final response =
          await _supabaseClient
              .from('grupos')
              .select('*, missoes(continente, paises)')
              .eq('id', groupId)
              .single();

      final missionData = response['missoes'];
      String? missionLocation;
      if (missionData != null) {
        missionLocation =
            missionData['continente'] ??
            (missionData['paises'] is List &&
                    (missionData['paises'] as List).isNotEmpty
                ? (missionData['paises'] as List).first
                : null);
      }

      final dataWithLocation = {
        ...response,
        'missao_localizacao': missionLocation,
      };

      // Cache the response
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'cached_group_$groupId',
        jsonEncode(dataWithLocation),
      );

      return Right(ItineraryGroupDto.fromJson(dataWithLocation).toEntity());
    } catch (e) {
      // Try cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_group_$groupId');
        if (cached != null) {
          final Map<String, dynamic> json = jsonDecode(cached);
          return Right(ItineraryGroupDto.fromJson(json).toEntity());
        }
      } catch (cacheError) {
        debugPrint('Erro ao ler cache de grupo: $cacheError');
      }
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, List<ItineraryItemEntity>>> getItinerary(
    String groupId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('eventos')
          .select()
          .eq('grupo_id', groupId)
          .order('data')
          .order('hora_inicio');

      final List<dynamic> data = response as List<dynamic>;

      // Cache the response
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_itinerary_$groupId', jsonEncode(data));

      final items =
          data.map((json) {
            final dto = ItineraryItemDto.fromJson(json);
            debugPrint(
              'Evento: ${dto.title ?? dto.oldName} | Cardapio: ${json['cardapio'] ?? json['cardapio_url']} | Anexos: ${json['anexos'] ?? json['anexo']}',
            );
            return dto.toEntity();
          }).toList();

      return Right(items);
    } catch (e) {
      // Try cache
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_itinerary_$groupId');
        if (cached != null) {
          final List<dynamic> data = jsonDecode(cached);
          final items =
              data
                  .map((json) => ItineraryItemDto.fromJson(json).toEntity())
                  .toList();
          return Right(items);
        }
      } catch (cacheError) {
        debugPrint('Erro ao ler cache de itinerário: $cacheError');
      }
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, List<MenuItemEntity>>> getMenu(
    String eventId,
  ) async {
    try {
      final response = await _supabaseClient.rpc(
        'buscar_cardapio_por_evento',
        params: {'p_evento_id': eventId},
      );

      final List<dynamic> data = response as List<dynamic>;

      final items =
          data.map((json) {
            final dto = MenuItemDto.fromJson(json);
            return dto.toEntity();
          }).toList();

      return Right(items);
    } catch (e) {
      debugPrint('Erro ao buscar cardapio: $e');
      return Left(Exception(e.toString()));
    }
  }

  Future<void> _saveTravelTimesToCache(
    String groupId,
    List<dynamic> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_travel_times_$groupId', jsonEncode(list));
    } catch (e) {
      debugPrint('Erro ao salvar tempos de deslocamento no cache: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _getTravelTimesFromCache(
    String groupId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_travel_times_$groupId');
      if (jsonString != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
      }
    } catch (e) {
      debugPrint('Erro ao recuperar tempos de deslocamento do cache: $e');
    }
    return [];
  }

  Future<void> _saveUserGroupIdToCache(String? groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (groupId != null) {
        await prefs.setString('cached_user_group_id', groupId);
      } else {
        await prefs.remove('cached_user_group_id');
      }
    } catch (e) {
      debugPrint('Erro ao salvar ID do grupo no cache: $e');
    }
  }

  Future<String?> _getUserGroupIdFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('cached_user_group_id');
    } catch (e) {
      debugPrint('Erro ao recuperar ID do grupo do cache: $e');
    }
    return null;
  }

  Future<void> _savePendingDocsToCache(List<String> docs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_pending_docs', jsonEncode(docs));
    } catch (e) {
      debugPrint('Erro ao salvar documentos pendentes no cache: $e');
    }
  }

  Future<List<String>> _getPendingDocsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_pending_docs');
      if (jsonString != null) {
        return List<String>.from(jsonDecode(jsonString));
      }
    } catch (e) {
      debugPrint('Erro ao recuperar documentos pendentes do cache: $e');
    }
    return [];
  }

  Future<void> _saveEmergencyContactsToCache(EmergencyContacts contacts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = {
        'police': contacts.police,
        'firefighters': contacts.firefighters,
        'medical': contacts.medical,
        'countryName': contacts.countryName,
      };
      await prefs.setString('cached_emergency_contacts', jsonEncode(json));
    } catch (e) {
      debugPrint('Erro ao salvar contatos de emergência no cache: $e');
    }
  }

  Future<EmergencyContacts?> _getEmergencyContactsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_emergency_contacts');
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        return EmergencyContacts(
          police: json['police'],
          firefighters: json['firefighters'],
          medical: json['medical'],
          countryName: json['countryName'],
        );
      }
    } catch (e) {
      debugPrint('Erro ao recuperar contatos de emergência do cache: $e');
    }
    return null;
  }

  @override
  Future<Either<Exception, List<Map<String, dynamic>>>> getTravelTimes(
    String groupId,
  ) async {
    try {
      final response = await _supabaseClient.rpc(
        'buscar_itinerario_grupo_deslocamento',
        params: {'p_grupo_id': groupId},
      );

      final List<dynamic> data = response as List<dynamic>;
      final list = List<Map<String, dynamic>>.from(data);
      await _saveTravelTimesToCache(groupId, list);

      return Right(list);
    } catch (e) {
      debugPrint(
        'Erro ao buscar tempos de deslocamento online: $e. Tentando cache.',
      );
      final cached = await _getTravelTimesFromCache(groupId);
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return Left(Exception('Erro ao buscar tempos de deslocamento: $e'));
    }
  }

  @override
  Future<Either<Exception, String?>> getUserGroupId() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado'));

      final response =
          await _supabaseClient
              .from('gruposParticipantes')
              .select('grupo_id')
              .eq('user_id', userId)
              .maybeSingle();

      String? groupId;
      if (response != null) {
        groupId = response['grupo_id'] as String?;
      }

      await _saveUserGroupIdToCache(groupId);

      return Right(groupId);
    } catch (e) {
      debugPrint('Erro ao buscar ID do grupo online: $e. Tentando cache.');
      final cached = await _getUserGroupIdFromCache();
      if (cached != null) {
        return Right(cached);
      }
      // If cached is null, it might really be null (user has no group),
      // but if error occurred we can't be sure.
      // However if we had a success before where it was valid, it would be cached.
      // If we had a success where it was null, we removed from cache.
      // So if cache returns null, we can return null? Or error?
      // Step 247 shows getUserGroupId handles maybeSingle.
      // Returning Right(null) is safer than error if we consider "no group" a valid state.
      // But if it's a network error, we should probably error unless we found "no group" in cache logic.
      // My cache logic removes key if null. So _getUserGroupIdFromCache returns null if not found OR if correctly null?
      // Actually if removed, it returns null.
      // So we can't distinguish "not cached" from "cached as null" easily without a separate flag.
      // But typically we only care if we HAVE a group ID cached.
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, List<String>>> getUserPendingDocuments() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado'));

      final response = await _supabaseClient
          .from('documentos')
          .select('tipo, nome_documento')
          .eq('user_id', userId)
          .eq('status', 'PENDENTE');

      final List<dynamic> data = response as List<dynamic>;
      final docTypes =
          data.map((doc) {
            final type = doc['tipo']?.toString();
            if (type != null && type.isNotEmpty) {
              return type[0].toUpperCase() + type.substring(1).toLowerCase();
            }
            return doc['nome_documento']?.toString() ?? 'Documento';
          }).toList();

      await _savePendingDocsToCache(docTypes);

      return Right(docTypes);
    } catch (e) {
      debugPrint(
        'Erro ao buscar documentos pendentes online: $e. Tentando cache.',
      );
      final cached = await _getPendingDocsFromCache();
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return Left(Exception(e.toString()));
    }
  }

  @override
  Future<Either<Exception, EmergencyContacts>> getEmergencyContacts(
    double lat,
    double lng,
  ) async {
    try {
      String? countryName;

      // 1. Try mobile-native geocoding first (not on Web)
      if (!kIsWeb) {
        try {
          final placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            countryName = placemarks.first.country;
          }
        } catch (e) {
          // Failure on mobile geocoding, will try fallback below
        }
      }

      // 2. Web fallback or if mobile native geocoding failed
      if (countryName == null) {
        try {
          final url = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng',
          );
          final response = await http.get(
            url,
            headers: {'User-Agent': 'AgroBravoApp/1.0'},
          );

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            countryName = data['address']?['country'];
          }
        } catch (e) {
          // Continue to error/cache
        }
      }

      if (countryName == null) {
        // Here we failed to get country. Try cache immediately.
        final cached = await _getEmergencyContactsFromCache();
        if (cached != null) return Right(cached);

        return Left(
          Exception('Não foi possível identificar o país desta localização.'),
        );
      }

      final countryRes =
          await _supabaseClient
              .from('paises')
              .select('id, pais')
              .or('pais.ilike.%$countryName%')
              .maybeSingle();

      int? paisId;
      String matchedCountry = countryName;

      if (countryRes != null) {
        paisId = countryRes['id'] as int;
        matchedCountry = countryRes['pais'] as String;
      }

      if (paisId == null) {
        // Try cache before error checking?
        // If we found a countryName but no DB entry, cache might be better if it exists?
        // But likely we have logic error or new country.
        // Let's check cache.
        final cached = await _getEmergencyContactsFromCache();
        if (cached != null) return Right(cached);

        return Left(
          Exception(
            'Contatos de emergência não configurados para $countryName.',
          ),
        );
      }

      final emergencyRes =
          await _supabaseClient
              .from('chamada_emergencia')
              .select()
              .eq('pais_id', paisId)
              .maybeSingle();

      if (emergencyRes == null) {
        final cached = await _getEmergencyContactsFromCache();
        if (cached != null) return Right(cached);

        return Left(
          Exception(
            'Dados de emergência não encontrados para $matchedCountry.',
          ),
        );
      }

      final contacts = EmergencyContacts(
        police: emergencyRes['policia'] ?? '190',
        firefighters: emergencyRes['bombeiro'] ?? '193',
        medical: emergencyRes['ambulancia'] ?? '192',
        countryName: matchedCountry,
      );

      await _saveEmergencyContactsToCache(contacts);

      return Right(contacts);
    } catch (e) {
      debugPrint(
        'Erro ao buscar contatos de emergência online: $e. Tentando cache.',
      );
      final cached = await _getEmergencyContactsFromCache();
      if (cached != null) {
        return Right(cached);
      }
      return Left(Exception('Erro ao buscar contatos de emergência: $e'));
    }
  }

  @override
  Future<Either<Exception, List<GuideMission>>> getGuideMissions() async {
    try {
      final userId = _supabaseClient.auth.currentUser?.id;
      if (userId == null) return Left(Exception('Usuário não autenticado.'));

      final response = await _supabaseClient
          .from('missoes')
          .select('*, grupos(*)')
          .isFilter('deleted_at', null)
          .order('data_inicio', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final List<GuideMission> guideMissions = [];

      for (var missionJson in data) {
        final mission = MissionEntity(
          id: missionJson['id'].toString(),
          name: missionJson['nome'] ?? 'Sem nome',
          logo: missionJson['logo'],
          location:
              missionJson['continente'] ??
              (missionJson['paises'] is List &&
                      (missionJson['paises'] as List).isNotEmpty
                  ? (missionJson['paises'] as List).first
                  : null),
          startDate:
              missionJson['data_inicio'] != null
                  ? DateTime.tryParse(missionJson['data_inicio'])
                  : null,
          endDate:
              missionJson['data_fim'] != null
                  ? DateTime.tryParse(missionJson['data_fim'])
                  : null,
        );

        final List<dynamic> groupsJson = missionJson['grupos'] ?? [];
        final groups =
            groupsJson
                .where((g) => g['deleted_at'] == null)
                .map((g) => ItineraryGroupDto.fromJson(g).toEntity())
                .toList();

        // Only add missions that have at least one valid group
        if (groups.isNotEmpty) {
          guideMissions.add(GuideMission(mission: mission, groups: groups));
        }
      }

      return Right(guideMissions);
    } catch (e) {
      debugPrint('Erro ao buscar todas as missões: $e');
      return Left(Exception('Erro ao buscar missões: $e'));
    }
  }

  @override
  Future<Either<Exception, List<Map<String, dynamic>>>> getGroupParticipants(
    String groupId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('gruposParticipantes')
          .select('id, users(id, nome, foto, cargo)')
          .eq('grupo_id', groupId);

      final List<dynamic> data = response as List<dynamic>;
      final List<Map<String, dynamic>> participants =
          data.map((item) {
            final user = item['users'] as Map<String, dynamic>?;
            return {
              'id': item['id'],
              'userId': user?['id'],
              'name': user?['nome'] ?? 'Usuário sem nome',
              'avatar': user?['foto'],
              'role': user?['cargo'] ?? 'Viajante',
              'isChecked': false,
            };
          }).toList();

      return Right(participants);
    } catch (e) {
      debugPrint('Erro ao buscar participantes do grupo: $e');
      return Left(Exception('Erro ao buscar participantes: $e'));
    }
  }

  @override
  Future<Either<Exception, List<String>>> getEventAttendance(
    String eventId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('eventos_presenca')
          .select('user_id')
          .eq('evento_id', eventId)
          .eq('presente', true);

      final List<dynamic> data = response as List<dynamic>;
      final List<String> presentUserIds =
          data.map((item) => item['user_id'].toString()).toList();

      return Right(presentUserIds);
    } catch (e) {
      debugPrint('Erro ao buscar presença do evento: $e');
      return Left(Exception('Erro ao buscar presença: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateAttendance(
    String eventId,
    String userId,
    bool isPresent,
  ) async {
    try {
      await _supabaseClient.from('eventos_presenca').upsert({
        'evento_id': eventId,
        'user_id': userId,
        'presente': isPresent,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'evento_id, user_id');

      return const Right(null);
    } catch (e) {
      debugPrint('Erro ao atualizar presença: $e');
      return Left(Exception('Erro ao atualizar presença: $e'));
    }
  }
}

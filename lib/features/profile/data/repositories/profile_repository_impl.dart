import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:agrobravo/features/profile/domain/entities/profile_entity.dart';
import 'package:agrobravo/features/profile/domain/repositories/profile_repository.dart';
import 'package:agrobravo/features/home/domain/entities/post_entity.dart';
import 'package:agrobravo/features/home/data/models/post_model.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

@LazySingleton(as: ProfileRepository)
class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _supabaseClient;

  ProfileRepositoryImpl(this._supabaseClient);

  Future<void> _saveProfileToCache(ProfileEntity profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> json = {
        'id': profile.id,
        'name': profile.name,
        'avatarUrl': profile.avatarUrl,
        'coverUrl': profile.coverUrl,
        'jobTitle': profile.jobTitle,
        'bio': profile.bio,
        'missionName': profile.missionName,
        'email': profile.email,
        'phone': profile.phone,
        'cpf': profile.cpf,
        'ssn': profile.ssn,
        'zipCode': profile.zipCode,
        'state': profile.state,
        'city': profile.city,
        'street': profile.street,
        'number': profile.number,
        'neighborhood': profile.neighborhood,
        'complement': profile.complement,
        'birthDate': profile.birthDate?.toIso8601String(),
        'nationality': profile.nationality,
        'passport': profile.passport,
        'foodPreferences': profile.foodPreferences,
        'medicalRestrictions': profile.medicalRestrictions,
        'connectionsCount': profile.connectionsCount,
        'postsCount': profile.postsCount,
        'missionsCount': profile.missionsCount,
        'isGuide': profile.isGuide,
        'company': profile.company,
        'country': profile.country,
        'badgeName': profile.badgeName,
        'emergencyName': profile.emergencyName,
        'emergencyRelationship': profile.emergencyRelationship,
        'emergencyContact': profile.emergencyContact,
        'connectionStatus': profile.connectionStatus.index,
      };
      await prefs.setString('cached_profile_${profile.id}', jsonEncode(json));
    } catch (e) {
      debugPrint('Erro ao salvar perfil no cache: $e');
    }
  }

  Future<ProfileEntity?> _getProfileFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_profile_$userId');
      if (jsonString != null) {
        final Map<String, dynamic> json = jsonDecode(jsonString);
        return ProfileEntity(
          id: json['id'],
          name: json['name'],
          avatarUrl: json['avatarUrl'],
          coverUrl: json['coverUrl'],
          jobTitle: json['jobTitle'],
          bio: json['bio'],
          missionName: json['missionName'],
          email: json['email'],
          phone: json['phone'],
          cpf: json['cpf'],
          ssn: json['ssn'],
          zipCode: json['zipCode'],
          state: json['state'],
          city: json['city'],
          street: json['street'],
          number: json['number'],
          neighborhood: json['neighborhood'],
          complement: json['complement'],
          birthDate:
              json['birthDate'] != null
                  ? DateTime.parse(json['birthDate'])
                  : null,
          nationality: json['nationality'],
          passport: json['passport'],
          foodPreferences: (json['foodPreferences'] as List?)?.cast<String>(),
          medicalRestrictions:
              (json['medicalRestrictions'] as List?)?.cast<String>(),
          connectionsCount: json['connectionsCount'] ?? 0,
          postsCount: json['postsCount'] ?? 0,
          missionsCount: json['missionsCount'] ?? 0,
          isGuide: json['isGuide'] ?? false,
          company: json['company'],
          country: json['country'],
          badgeName: json['badgeName'],
          emergencyName: json['emergencyName'],
          emergencyRelationship: json['emergencyRelationship'],
          emergencyContact: json['emergencyContact'],
          connectionStatus:
              ConnectionStatus.values[json['connectionStatus'] ?? 0],
        );
      }
    } catch (e) {
      debugPrint('Erro ao recuperar perfil do cache: $e');
    }
    return null;
  }

  @override
  Future<Either<Exception, ProfileEntity>> getProfile(String userId) async {
    final currentUserId = _supabaseClient.auth.currentUser?.id;
    try {
      var userResponse =
          await _supabaseClient
              .from('users')
              .select(
                'id, nome, foto, cargo, observacoes, capa_perfil, email, telefone, restricoes_alimentares, restricoes_medicas, cpf, ssn, cep, estado, cidade, rua, numero, bairro, complemento, datanascimento, data_nascimento, nacionalidade, n_passaporte, tipouser, empresa, pais, nome_cracha, nome_contato_emergencia, grau_parentesco_emergencia, contato_emergencia',
              )
              .eq('id', userId)
              .maybeSingle();

      if (userResponse == null && userId == currentUserId) {
        final currentUser = _supabaseClient.auth.currentUser;
        if (currentUser != null) {
          final metaName = currentUser.userMetadata?['name'] ?? currentUser.userMetadata?['full_name'];
          final email = currentUser.email;
          try {
            await _supabaseClient.from('users').insert({
              'id': userId,
              'nome': metaName ?? email?.split('@').first ?? 'Usuário',
              'email': email,
              'tipouser': ['GUIA_PENDENTE'],
            });
            userResponse = await _supabaseClient
                .from('users')
                .select(
                  'id, nome, foto, cargo, observacoes, capa_perfil, email, telefone, restricoes_alimentares, restricoes_medicas, cpf, ssn, cep, estado, cidade, rua, numero, bairro, complemento, datanascimento, data_nascimento, nacionalidade, n_passaporte, tipouser, empresa, pais, nome_cracha, nome_contato_emergencia, grau_parentesco_emergencia, contato_emergencia',
                )
                .eq('id', userId)
                .maybeSingle();
          } catch (insertError) {
            debugPrint('Erro ao inserir usuario auto-cadastro: $insertError');
          }
        }
      }

      if (userResponse == null) {
        if (userId == currentUserId) {
          final fallback = _createFallbackProfile(userId);
          await _saveProfileToCache(fallback);
          return Right(fallback);
        } else {
          return Left(Exception('Perfil não encontrado para o usuário $userId'));
        }
      }

      final userData = userResponse;

      // 2. Fetch Posts Count
      final postsResponse = await _supabaseClient
          .from('posts')
          .select('id')
          .eq('user_id', userId);

      final postsCount = (postsResponse as List).length;

      // 3. Fetch Missions (unique, via groups and direct participation)
      // Step A: collect all group IDs the user belongs to
      final participantGroupsRes = await _supabaseClient
          .from('gruposParticipantes')
          .select('grupo_id')
          .eq('user_id', userId);

      final leaderGroupsRes = await _supabaseClient
          .from('lideresGrupo')
          .select('grupo_id')
          .eq('lider_id', userId);

      final allGroupIds = {
        ...(participantGroupsRes as List).map((r) => r['grupo_id'] as String?),
        ...(leaderGroupsRes as List).map((r) => r['grupo_id'] as String?),
      }.where((id) => id != null).cast<String>().toList();

      // Step B: get unique mission IDs from those groups
      final Set<String> missionIdSet = {};
      if (allGroupIds.isNotEmpty) {
        final groupMissionsRes = await _supabaseClient
            .from('grupos')
            .select('missao_id')
            .inFilter('id', allGroupIds);

        for (final g in groupMissionsRes as List) {
          final mId = g['missao_id'] as String?;
          if (mId != null) missionIdSet.add(mId);
        }
      }

      // Step C: fallback — direct participation
      final directMissionsRes = await _supabaseClient
          .from('missoesParticipantes')
          .select('missoes_id')
          .eq('user_id', userId);

      for (final d in directMissionsRes as List) {
        final mId = d['missoes_id'] as String?;
        if (mId != null) missionIdSet.add(mId);
      }

      // Step D: MASTER/COLABORADOR veem todas as missões ativas (sem vínculo de grupo)
      final userRoles = (userData['tipouser'] as List?)?.cast<String>() ?? [];
      final isAdminRole = userRoles.any((r) => r == 'MASTER' || r == 'COLABORADOR');
      if (missionIdSet.isEmpty && isAdminRole) {
        final allMissionsRes = await _supabaseClient
            .from('missoes')
            .select('id')
            .isFilter('deleted_at', null);

        for (final m in allMissionsRes as List) {
          final mId = m['id'] as String?;
          if (mId != null) missionIdSet.add(mId);
        }
      }

      final missionsCount = missionIdSet.length;

      // Step E: fetch mission names
      String? missionName;
      final List<String> groupAndMissionNames = [];

      if (allGroupIds.isNotEmpty) {
        try {
          final groupsRes = await _supabaseClient
              .from('grupos')
              .select('nome, missoes(nome)')
              .inFilter('id', allGroupIds);

          for (final g in groupsRes as List) {
            final groupName = g['nome'] as String?;
            final missaoData = g['missoes'];
            String? mName;
            if (missaoData is Map) {
              mName = missaoData['nome'] as String?;
            } else if (missaoData is List && missaoData.isNotEmpty) {
              mName = (missaoData[0] as Map)['nome'] as String?;
            }

            if (mName != null && groupName != null) {
              groupAndMissionNames.add('$mName - $groupName');
            } else if (mName != null) {
              groupAndMissionNames.add(mName);
            }
          }
        } catch (e) {
          debugPrint('Erro ao buscar nome de missoes com grupos: $e');
        }
      }

      if (groupAndMissionNames.isEmpty && missionIdSet.isNotEmpty) {
        final missionsNamesRes = await _supabaseClient
            .from('missoes')
            .select('nome')
            .inFilter('id', missionIdSet.toList());

        final names = (missionsNamesRes as List)
            .map((m) => m['nome'] as String?)
            .whereType<String>()
            .toList();

        groupAndMissionNames.addAll(names);
      }

      if (groupAndMissionNames.isNotEmpty) {
        missionName = groupAndMissionNames.first; // Exibir apenas a principal para evitar tamanho gigante
      }

      // 4. Fetch Connections Count
      final connectionsResponse = await _supabaseClient
          .from('conexoes')
          .select('aprovou')
          .or('seguidor_id.eq.$userId,seguido_id.eq.$userId')
          .eq('aprovou', true);

      final connectionsCount = (connectionsResponse as List).length;

      // 5. Fetch Connection Status relative to current user
      ConnectionStatus connectionStatus = ConnectionStatus.none;
      if (currentUserId != null && currentUserId != userId) {
        final statusRes =
            await _supabaseClient
                .from('conexoes')
                .select('*')
                .or(
                  'and(seguidor_id.eq.$currentUserId,seguido_id.eq.$userId),and(seguido_id.eq.$currentUserId,seguidor_id.eq.$userId)',
                )
                .maybeSingle();

        if (statusRes != null) {
          final isAprovou = statusRes['aprovou'] as bool;
          if (isAprovou) {
            connectionStatus = ConnectionStatus.connected;
          } else {
            if (statusRes['seguidor_id'] == currentUserId) {
              connectionStatus = ConnectionStatus.pendingSent;
            } else {
              connectionStatus = ConnectionStatus.pendingReceived;
            }
          }
        }
      }

      final profile = ProfileEntity(
        id: userData['id'],
        name: userData['nome'] ?? 'Sem nome',
        avatarUrl: userData['foto'],
        coverUrl: userData['capa_perfil'],
        jobTitle: userData['cargo'],
        bio: userData['observacoes'],
        missionName: missionName,
        email: userData['email'],
        phone: userData['telefone'],
        cpf: userData['cpf'],
        ssn: userData['ssn'],
        zipCode: userData['cep'],
        state: userData['estado'],
        city: userData['cidade'],
        street: userData['rua'],
        number: userData['numero'],
        neighborhood: userData['bairro'],
        complement: userData['complemento'],
        birthDate:
            userData['datanascimento'] != null
                ? DateTime.tryParse(userData['datanascimento'])
                : (userData['data_nascimento'] != null
                    ? DateTime.tryParse(userData['data_nascimento'])
                    : null),
        nationality: userData['nationality'] ?? userData['nacionalidade'],
        passport: userData['n_passaporte'],
        foodPreferences:
            (userData['restricoes_alimentares'] as List?)?.cast<String>(),
        medicalRestrictions:
            (userData['restricoes_medicas'] as List?)?.cast<String>(),
        connectionsCount: connectionsCount,
        postsCount: postsCount,
        missionsCount: missionsCount,
        isGuide: () {
          final roles = (userData['tipouser'] as List?)?.cast<String>() ?? [];
          return roles.any((r) => r == 'GUIA' || r == 'COLABORADOR' || r == 'MASTER');
        }(),
        company: userData['empresa'],
        country: userData['pais'],
        badgeName: userData['nome_cracha'],
        emergencyName: userData['nome_contato_emergencia'],
        emergencyRelationship: userData['grau_parentesco_emergencia'],
        emergencyContact: userData['contato_emergencia'],
        connectionStatus: connectionStatus,
      );

      await _saveProfileToCache(profile);

      return Right(profile);
    } catch (e) {
      debugPrint('Erro ao buscar perfil online: $e. Tentando cache.');
      final cachedProfile = await _getProfileFromCache(userId);
      if (cachedProfile != null) {
        return Right(cachedProfile);
      }
      if (userId == currentUserId) {
        final fallback = _createFallbackProfile(userId);
        return Right(fallback);
      }
      return Left(Exception('Erro ao buscar perfil e sem cache: $e'));
    }
  }

  ProfileEntity _createFallbackProfile(String userId) {
    final currentUser = _supabaseClient.auth.currentUser;
    final email = currentUser?.email;
    final metaName = currentUser?.userMetadata?['name'] ?? currentUser?.userMetadata?['full_name'];
    return ProfileEntity(
      id: userId,
      name: metaName ?? email?.split('@').first ?? 'Usuário',
      avatarUrl: null,
      coverUrl: null,
      jobTitle: 'Cliente',
      bio: null,
      missionName: null,
      email: email,
      phone: null,
      cpf: null,
      ssn: null,
      zipCode: null,
      state: null,
      city: null,
      street: null,
      number: null,
      neighborhood: null,
      complement: null,
      birthDate: null,
      nationality: null,
      passport: null,
      foodPreferences: const [],
      medicalRestrictions: const [],
      connectionsCount: 0,
      postsCount: 0,
      missionsCount: 0,
      isGuide: false,
      connectionStatus: ConnectionStatus.none,
    );
  }

  Future<void> _saveUserPostsToCache(
    String userId,
    List<dynamic> jsonList,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_posts_$userId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Erro ao salvar posts do usuário no cache: $e');
    }
  }

  Future<List<PostEntity>> _getUserPostsFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_user_posts_$userId');
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final currentUserId = _supabaseClient.auth.currentUser?.id;

        return jsonList.map((postMap) {
          final user = postMap['users'] as Map<String, dynamic>?;
          final missao = postMap['missoes'] as Map<String, dynamic>?;
          final curtidasList = postMap['curtidas'] as List?;
          final commentsList = postMap['comentarios'] as List?;
          final likesCount = curtidasList?.length ?? 0;
          final commentsCount = commentsList?.length ?? 0;
          final isLiked =
              currentUserId != null &&
              curtidasList != null &&
              curtidasList.any((c) => c['user_id'] == currentUserId);

          return PostModel.fromJson(postMap).toEntity().copyWith(
            userName: user?['nome'] ?? 'Usuário',
            userAvatar: user?['foto'],
            missionName: missao?['nome'],
            likesCount: likesCount,
            commentsCount: commentsCount,
            isLiked: isLiked,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Erro ao recuperar posts do usuário do cache: $e');
    }
    return [];
  }

  Future<void> _saveConnectionsToCache(
    String userId,
    List<ProfileEntity> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList =
          list
              .map(
                (p) => {
                  'id': p.id,
                  'name': p.name,
                  'avatarUrl': p.avatarUrl,
                  'coverUrl': p.coverUrl,
                  'jobTitle': p.jobTitle,
                  'bio': p.bio,
                  'email': p.email,
                  'phone': p.phone,
                  'city': p.city,
                  'state': p.state,
                  // minimalistic cache for list view? or full?
                  // storing basic info needed for list usually
                  'connectionStatus': p.connectionStatus.index,
                  'isGuide': p.isGuide,
                },
              )
              .toList();
      await prefs.setString('cached_connections_$userId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Erro ao salvar conexões no cache: $e');
    }
  }

  Future<List<ProfileEntity>> _getConnectionsFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_connections_$userId');
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList
            .map(
              (json) => ProfileEntity(
                id: json['id'],
                name: json['name'],
                avatarUrl: json['avatarUrl'],
                coverUrl: json['coverUrl'],
                jobTitle: json['jobTitle'],
                bio: json['bio'],
                email: json['email'],
                phone: json['phone'],
                city: json['city'],
                state: json['state'],
                connectionStatus:
                    ConnectionStatus.values[json['connectionStatus'] ?? 0],
                // Defaults for others
                connectionsCount: 0,
                postsCount: 0,
                missionsCount: 0,
                isGuide: json['isGuide'] ?? false,
                zipCode: null,
                street: null,
                number: null,
                neighborhood: null,
                complement: null,
                birthDate: null,
                nationality: null,
                passport: null,
                cpf: null,
                ssn: null,
                foodPreferences: null,
                medicalRestrictions: null,
                missionName: null,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Erro ao recuperar conexões do cache: $e');
    }
    return [];
  }

  @override
  Future<Either<Exception, List<PostEntity>>> getUserPosts(
    String userId,
  ) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser?.id;
      final response = await _supabaseClient
          .from('posts')
          .select('''
            *,
            users:user_id (nome, foto),
            missoes:missao_id (nome),
            curtidas:curtidas(user_id),
            comentarios:comentarios(id)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List;
      await _saveUserPostsToCache(userId, data);

      final posts =
          data.map((postMap) {
            final post = PostModel.fromJson(postMap);
            final user = postMap['users'] as Map<String, dynamic>?;
            final missao = postMap['missoes'] as Map<String, dynamic>?;

            final curtidasList = postMap['curtidas'] as List?;
            final commentsList = postMap['comentarios'] as List?;

            final likesCount = curtidasList?.length ?? 0;
            final commentsCount = commentsList?.length ?? 0;

            final isLiked =
                currentUserId != null &&
                curtidasList != null &&
                curtidasList.any((c) => c['user_id'] == currentUserId);

            return post.toEntity().copyWith(
              userName: user?['nome'] ?? 'Usuário',
              userAvatar: user?['foto'],
              missionName: missao?['nome'],
              likesCount: likesCount,
              commentsCount: commentsCount,
              isLiked: isLiked,
            );
          }).toList();

      return Right(posts);
    } catch (e) {
      debugPrint('Erro ao buscar posts do usuário online: $e. Tentando cache.');
      final cachedPosts = await _getUserPostsFromCache(userId);
      if (cachedPosts.isNotEmpty) {
        return Right(cachedPosts);
      }
      return Left(Exception('Erro ao buscar posts do usuário: $e'));
    }
  }

  @override
  Future<Either<Exception, String>> updateProfilePhoto(
    Uint8List bytes,
    String extension,
  ) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$extension';
      final userId = _supabaseClient.auth.currentUser!.id;
      final path = 'avatars/$userId/$fileName';

      await _supabaseClient.storage.from('files').uploadBinary(path, bytes);

      final url = _supabaseClient.storage.from('files').getPublicUrl(path);

      await _supabaseClient
          .from('users')
          .update({'foto': url})
          .eq('id', userId);

      return Right(url);
    } catch (e) {
      return Left(Exception('Erro ao atualizar foto: $e'));
    }
  }

  @override
  Future<Either<Exception, String>> updateCoverPhoto(
    Uint8List bytes,
    String extension,
  ) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_cover.$extension';
      final userId = _supabaseClient.auth.currentUser!.id;
      final path = 'covers/$userId/$fileName';

      await _supabaseClient.storage.from('files').uploadBinary(path, bytes);

      final url = _supabaseClient.storage.from('files').getPublicUrl(path);

      await _supabaseClient
          .from('users')
          .update({'capa_perfil': url})
          .eq('id', userId);

      return Right(url);
    } catch (e) {
      return Left(Exception('Erro ao atualizar capa: $e'));
    }
  }

  @override
  Future<Either<Exception, List<ProfileEntity>>> getConnections(
    String userId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('conexoes')
          .select('seguidor_id, seguido_id')
          .or('seguidor_id.eq.$userId,seguido_id.eq.$userId')
          .eq('aprovou', true);

      final connectionIds =
          (response as List)
              .expand((c) {
                return [c['seguidor_id'], c['seguido_id']];
              })
              .where((id) => id != userId)
              .toSet()
              .toList();

      if (connectionIds.isEmpty) {
        await _saveConnectionsToCache(userId, []);
        return const Right([]);
      }

      final result = await _fetchProfiles(connectionIds);

      // If result is valid, cache it
      result.fold(
        (l) {}, // error, ignore
        (profiles) => _saveConnectionsToCache(userId, profiles),
      );

      return result;
    } catch (e) {
      debugPrint('Erro ao buscar conexões online: $e. Tentando cache.');
      final cached = await _getConnectionsFromCache(userId);
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return Left(Exception('Erro ao buscar conexões: $e'));
    }
  }

  Future<void> _saveRequestsToCache(
    String userId,
    List<ProfileEntity> list,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Reuse connection serialization logic or simplified one
      final jsonList =
          list
              .map(
                (p) => {
                  'id': p.id,
                  'name': p.name,
                  'avatarUrl': p.avatarUrl,
                  // Requests usually just show name/avatar
                  'jobTitle': p.jobTitle,
                  'isGuide': p.isGuide,
                },
              )
              .toList();
      await prefs.setString('cached_requests_$userId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Erro ao salvar solicitações no cache: $e');
    }
  }

  Future<List<ProfileEntity>> _getRequestsFromCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_requests_$userId');
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList
            .map(
              (json) => ProfileEntity(
                id: json['id'],
                name: json['name'],
                avatarUrl: json['avatarUrl'],
                jobTitle: json['jobTitle'],
                // Defaults
                coverUrl: null,
                bio: null,
                email: null,
                phone: null,
                city: null,
                state: null,
                connectionStatus:
                    ConnectionStatus.pendingReceived, // It is a request!
                connectionsCount: 0,
                postsCount: 0,
                missionsCount: 0,
                isGuide: json['isGuide'] ?? false,
                zipCode: null,
                street: null,
                number: null,
                neighborhood: null,
                complement: null,
                birthDate: null,
                nationality: null,
                passport: null,
                cpf: null,
                ssn: null,
                foodPreferences: null,
                medicalRestrictions: null,
                missionName: null,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Erro ao recuperar solicitações do cache: $e');
    }
    return [];
  }

  @override
  Future<Either<Exception, List<ProfileEntity>>> getRequests(
    String userId,
  ) async {
    try {
      final response = await _supabaseClient
          .from('conexoes')
          .select('seguidor_id')
          .eq('seguido_id', userId)
          .eq('aprovou', false);

      final requestIds =
          (response as List).map((c) => c['seguidor_id']).toList();

      if (requestIds.isEmpty) {
        await _saveRequestsToCache(userId, []);
        return const Right([]);
      }

      final result = await _fetchProfiles(requestIds);

      result.fold(
        (l) {}, // ignore error
        (profiles) => _saveRequestsToCache(userId, profiles),
      );

      return result;
    } catch (e) {
      debugPrint('Erro ao buscar solicitações online: $e. Tentando cache.');
      final cached = await _getRequestsFromCache(userId);
      if (cached.isNotEmpty) {
        return Right(cached);
      }
      return Left(Exception('Erro ao buscar solicitações: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> requestConnection(String userId) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser!.id;
      await _supabaseClient.from('conexoes').insert({
        'seguidor_id': currentUserId,
        'seguido_id': userId,
        'aprovou': false,
      });
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao solicitar conexão: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> cancelConnection(String userId) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser!.id;
      await _supabaseClient
          .from('conexoes')
          .delete()
          .eq('seguidor_id', currentUserId)
          .eq('seguido_id', userId);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao cancelar solicitação: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> acceptConnection(String userId) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser!.id;
      await _supabaseClient
          .from('conexoes')
          .update({'aprovou': true})
          .eq('seguidor_id', userId)
          .eq('seguido_id', currentUserId);

      // Notifica o solicitante que foi aceito
      try {
        final acceptorData = await _supabaseClient
            .from('users')
            .select('nome')
            .eq('id', currentUserId)
            .maybeSingle();
        final acceptorName =
            (acceptorData?['nome'] as String?)?.split(' ').first ?? 'Alguém';

        await _supabaseClient.from('notificacoes').insert({
          'user_id': userId,
          'titulo': acceptorName,
          'mensagem': 'aceitou sua solicitação de conexão',
          'assunto': 'CONEXAO_ACEITA',
          'solicitacao_user_id': currentUserId,
          'lido': false,
          'target_route': '/profile/$currentUserId',
        });
      } catch (e) {
        debugPrint('[ProfileRepository] acceptConnection notification error: $e');
      }

      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao aceitar conexão: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> rejectConnection(String userId) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser!.id;
      await _supabaseClient
          .from('conexoes')
          .delete()
          .eq('seguidor_id', userId)
          .eq('seguido_id', currentUserId);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao rejeitar conexão: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> removeConnection(String userId) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser!.id;
      await _supabaseClient
          .from('conexoes')
          .delete()
          .or(
            'and(seguidor_id.eq.$currentUserId,seguido_id.eq.$userId),and(seguidor_id.eq.$userId,seguido_id.eq.$currentUserId)',
          );
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao remover conexão: $e'));
    }
  }

  Future<Either<Exception, List<ProfileEntity>>> _fetchProfiles(
    List<dynamic> userIds,
  ) async {
    try {
      final currentUserId = _supabaseClient.auth.currentUser?.id;
      final usersResponse = await _supabaseClient
          .from('users')
          .select(
            'id, nome, foto, cargo, capa_perfil, observacoes, email, telefone, cpf, ssn, cep, estado, city:cidade, rua, numero, bairro, complemento, datanascimento, data_nascimento, nacionalidade, n_passaporte, restricoes_alimentares, restricoes_medicas',
          )
          .inFilter('id', userIds);

      // Fetch statuses relative to current user for these profiles
      Map<String, ConnectionStatus> statuses = {};
      if (currentUserId != null) {
        final connectionsResponse = await _supabaseClient
            .from('conexoes')
            .select('*')
            .or(
              'and(seguidor_id.eq.$currentUserId,seguido_id.in.(${userIds.join(",")})),and(seguido_id.eq.$currentUserId,seguidor_id.in.(${userIds.join(",")}))',
            );

        for (final c in connectionsResponse as List) {
          final seguidorId = c['seguidor_id'];
          final seguidoId = c['seguido_id'];
          final aprovou = c['aprovou'] as bool;

          if (aprovou) {
            statuses[seguidorId == currentUserId ? seguidoId : seguidorId] =
                ConnectionStatus.connected;
          } else {
            if (seguidorId == currentUserId) {
              statuses[seguidoId] = ConnectionStatus.pendingSent;
            } else {
              statuses[seguidorId] = ConnectionStatus.pendingReceived;
            }
          }
        }
      }

      final profiles =
          (usersResponse as List).map((u) {
            return ProfileEntity(
              id: u['id'],
              name: u['nome'] ?? 'Sem nome',
              avatarUrl: u['foto'],
              coverUrl: u['capa_perfil'],
              jobTitle: u['cargo'],
              bio: u['observacoes'],
              missionName: null,
              email: u['email'],
              phone: u['telefone'],
              cpf: u['cpf'],
              ssn: u['ssn'],
              zipCode: u['cep'],
              state: u['estado'],
              city: u['cidade'],
              street: u['rua'],
              number: u['numero'],
              neighborhood: u['bairro'],
              complement: u['complemento'],
              birthDate:
                  u['datanascimento'] != null
                      ? DateTime.tryParse(u['datanascimento'])
                      : (u['data_nascimento'] != null
                          ? DateTime.tryParse(u['data_nascimento'])
                          : null),
              nationality: u['nacionalidade'],
              passport: u['n_passaporte'],
              foodPreferences:
                  (u['restricoes_alimentares'] as List?)?.cast<String>(),
              medicalRestrictions:
                  (u['restricoes_medicas'] as List?)?.cast<String>(),
              connectionsCount: 0,
              postsCount: 0,
              missionsCount: 0,
              isGuide:
                  (u['cargo'] as String?)?.toLowerCase().contains('guia') ??
                  false,
              connectionStatus: statuses[u['id']] ?? ConnectionStatus.none,
            );
          }).toList();

      return Right(profiles);
    } catch (e) {
      return Left(Exception('Erro ao buscar informações dos usuários: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateFoodPreferences(
    List<String> preferences,
  ) async {
    try {
      final userId = _supabaseClient.auth.currentUser!.id;
      await _supabaseClient
          .from('users')
          .update({'restricoes_alimentares': preferences})
          .eq('id', userId);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao atualizar preferências alimentares: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateMedicalRestrictions(
    List<String> restrictions,
  ) async {
    try {
      final userId = _supabaseClient.auth.currentUser!.id;
      await _supabaseClient
          .from('users')
          .update({'restricoes_medicas': restrictions})
          .eq('id', userId);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao atualizar restrições médicas: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateAccountData({
    required Map<String, dynamic> data,
  }) async {
    try {
      final userId = _supabaseClient.auth.currentUser!.id;

      // Map frontend fields to DB columns
      final dbData = <String, dynamic>{};
      if (data.containsKey('name')) dbData['nome'] = data['name'];
      if (data.containsKey('phone')) dbData['telefone'] = data['phone'];
      if (data.containsKey('cpf')) dbData['cpf'] = data['cpf'];
      if (data.containsKey('zipCode')) dbData['cep'] = data['zipCode'];
      if (data.containsKey('state')) dbData['estado'] = data['state'];
      if (data.containsKey('city')) dbData['cidade'] = data['city'];
      if (data.containsKey('street')) dbData['rua'] = data['street'];
      if (data.containsKey('number')) dbData['numero'] = data['number'];
      if (data.containsKey('neighborhood'))
        dbData['bairro'] = data['neighborhood'];
      if (data.containsKey('complement'))
        dbData['complemento'] = data['complement'];
      if (data.containsKey('birthDate')) {
        final date = data['birthDate'] as DateTime;
        dbData['datanascimento'] = date.toIso8601String();
      }
      if (data.containsKey('nationality'))
        dbData['nacionalidade'] = data['nationality'];
      if (data.containsKey('passport'))
        dbData['n_passaporte'] = data['passport'];
      if (data.containsKey('ssn')) dbData['ssn'] = data['ssn'];
      if (data.containsKey('company')) dbData['empresa'] = data['company'];
      if (data.containsKey('country')) dbData['pais'] = data['country'];
      if (data.containsKey('badgeName')) {
        dbData['nome_cracha'] = data['badgeName'];
      }
      if (data.containsKey('emergencyName')) {
        dbData['nome_contato_emergencia'] = data['emergencyName'];
      }
      if (data.containsKey('emergencyRelationship')) {
        dbData['grau_parentesco_emergencia'] = data['emergencyRelationship'];
      }
      if (data.containsKey('emergencyContact')) {
        dbData['contato_emergencia'] = data['emergencyContact'];
      }

      await _supabaseClient.from('users').update(dbData).eq('id', userId);
      return const Right(null);
    } catch (e) {
      return Left(Exception('Erro ao atualizar dados da conta: $e'));
    }
  }

  @override
  Future<Either<Exception, void>> updateNotificationPreferences(
    Map<String, bool> preferences,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _supabaseClient.auth.currentUser!.id;
      await prefs.setString(
        'notification_prefs_$userId',
        jsonEncode(preferences),
      );
      return const Right(null);
    } catch (e) {
      return Left(
        Exception('Erro ao salvar preferências de notificação localmente: $e'),
      );
    }
  }

  @override
  Future<Either<Exception, Map<String, bool>>>
  getNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _supabaseClient.auth.currentUser!.id;
      final jsonString = prefs.getString('notification_prefs_$userId');
      if (jsonString != null) {
        final Map<String, dynamic> decoed = jsonDecode(jsonString);
        return Right(decoed.cast<String, bool>());
      }
      // Return defaults if not set
      return const Right({
        'pushNotifications': true,
        'emailNotifications': true,
        'documentAlerts': true,
        'missionUpdates': true,
        'connections': true,
      });
    } catch (e) {
      return Left(
        Exception('Erro ao carregar preferências de notificação: $e'),
      );
    }
  }
}

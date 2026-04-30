import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/models/current_user_api_models.dart';
import 'package:chahua/core/network/dio_client.dart';

class CurrentUserApiService {
  const CurrentUserApiService(this._dio);

  final Dio _dio;

  Future<CurrentUserDto> fetchMe() async {
    final response = await _dio.get<Map<String, dynamic>>('/users/me');
    return CurrentUserDto.fromJson(response.data!);
  }
}

final currentUserApiServiceProvider = Provider<CurrentUserApiService>((ref) {
  return CurrentUserApiService(ref.watch(dioProvider));
});

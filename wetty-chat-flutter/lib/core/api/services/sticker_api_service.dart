import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/stickers_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/core/network/dio_client.dart';

class StickerApiService {
  final Dio _dio;

  StickerApiService(this._dio);

  Future<StickerPackListResponseDto> fetchOwnedPacks() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stickers/packs/mine/owned',
    );
    return StickerPackListResponseDto.fromJson(response.data!);
  }

  Future<StickerPackListResponseDto> fetchSubscribedPacks() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stickers/packs/mine/subscribed',
    );
    return StickerPackListResponseDto.fromJson(response.data!);
  }

  Future<StickerPackSummaryDto> createPack(
    CreateStickerPackRequestDto request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/stickers/packs',
      data: request.toJson(),
    );
    return StickerPackSummaryDto.fromJson(response.data!);
  }

  Future<StickerPackSummaryDto> updatePack(
    String packId,
    UpdateStickerPackRequestDto request,
  ) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/stickers/packs/$packId',
      data: request.toJson(),
    );
    return StickerPackSummaryDto.fromJson(response.data!);
  }

  Future<void> deletePack(String packId) async {
    await _dio.delete<void>('/stickers/packs/$packId');
  }

  Future<StickerPackDetailResponseDto> fetchPackDetail(String packId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stickers/packs/$packId',
    );
    return StickerPackDetailResponseDto.fromJson(response.data!);
  }

  Future<void> subscribeToPack(String packId) async {
    await _dio.put<void>('/stickers/packs/$packId/subscription');
  }

  Future<void> unsubscribeFromPack(String packId) async {
    await _dio.delete<void>('/stickers/packs/$packId/subscription');
  }

  Future<StickerSummaryDto> uploadSticker(
    String packId, {
    required String filePath,
    required String fileName,
    required String emoji,
    String? name,
    String? description,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'emoji': emoji,
      'name': ?name,
      'description': ?description,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      '/stickers/packs/$packId/stickers',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return StickerSummaryDto.fromJson(response.data!);
  }

  Future<StickerDetailResponseDto> fetchStickerDetail(String stickerId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stickers/$stickerId',
    );
    return StickerDetailResponseDto.fromJson(response.data!);
  }

  Future<void> addStickerToPack(String packId, String stickerId) async {
    await _dio.put<void>('/stickers/packs/$packId/stickers/$stickerId');
  }

  Future<void> removeStickerFromPack(String packId, String stickerId) async {
    await _dio.delete<void>('/stickers/packs/$packId/stickers/$stickerId');
  }

  Future<FavoriteStickerListResponseDto> fetchFavorites() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stickers/mine/favorites',
    );
    return FavoriteStickerListResponseDto.fromJson(response.data!);
  }

  Future<void> addFavorite(String stickerId) async {
    await _dio.put<void>('/stickers/$stickerId/favorite');
  }

  Future<void> removeFavorite(String stickerId) async {
    await _dio.delete<void>('/stickers/$stickerId/favorite');
  }

  Future<void> saveStickerPackOrder(List<StickerPackOrderItemDto> order) async {
    await _dio.put<void>(
      '/users/me/stickerpack-order',
      data: {'order': order.map((e) => e.toJson()).toList()},
    );
  }
}

final stickerApiServiceProvider = Provider<StickerApiService>((ref) {
  return StickerApiService(ref.watch(dioProvider));
});

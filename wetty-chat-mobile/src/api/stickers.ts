import type { AxiosResponse } from 'axios';
import apiClient from './client';

export interface StickerMedia {
  id: string;
  url: string;
  contentType: string;
  size: number;
  width?: number | null;
  height?: number | null;
}

export interface StickerSummary {
  id: string;
  media: StickerMedia;
  emoji: string;
  name?: string | null;
  description?: string | null;
  createdAt: string;
  isFavorited: boolean;
}

export interface StickerPackPreviewSticker {
  id: string;
  media: StickerMedia;
  emoji: string;
}

export interface StickerPackSummary {
  id: string;
  ownerUid: number;
  ownerName?: string | null;
  name: string;
  description?: string | null;
  createdAt: string;
  updatedAt: string;
  stickerCount: number;
  isSubscribed: boolean;
  previewSticker?: StickerPackPreviewSticker | null;
}

export interface StickerPackListResponse {
  packs: StickerPackSummary[];
}

export interface StickerPackDetailResponse extends StickerPackSummary {
  stickers: StickerSummary[];
}

export interface StickerDetailResponse extends StickerSummary {
  packs: StickerPackSummary[];
}

export interface FavoriteStickerListResponse {
  stickers: StickerSummary[];
}

export interface CreateStickerPackBody {
  name: string;
  description?: string;
}

export interface UpdateStickerPackBody {
  name?: string;
  description?: string;
}

export interface UploadStickerToPackInput {
  file: File;
  emoji: string;
  name?: string;
  description?: string;
}

export function getOwnedStickerPacks(): Promise<AxiosResponse<StickerPackListResponse>> {
  return apiClient.get('/stickers/packs/mine/owned');
}

export function getSubscribedStickerPacks(): Promise<AxiosResponse<StickerPackListResponse>> {
  return apiClient.get('/stickers/packs/mine/subscribed');
}

export function getFavoriteStickers(): Promise<AxiosResponse<FavoriteStickerListResponse>> {
  return apiClient.get('/stickers/mine/favorites');
}

export function getStickerDetail(stickerId: string): Promise<AxiosResponse<StickerDetailResponse>> {
  return apiClient.get(`/stickers/${stickerId}`);
}

export function getStickerPack(packId: string): Promise<AxiosResponse<StickerPackDetailResponse>> {
  return apiClient.get(`/stickers/packs/${packId}`);
}

export function createStickerPack(body: CreateStickerPackBody): Promise<AxiosResponse<StickerPackSummary>> {
  return apiClient.post('/stickers/packs', body);
}

export function updateStickerPack(
  packId: string,
  body: UpdateStickerPackBody,
): Promise<AxiosResponse<StickerPackSummary>> {
  return apiClient.patch(`/stickers/packs/${packId}`, body);
}

export function subscribeStickerPack(packId: string): Promise<AxiosResponse<void>> {
  return apiClient.put(`/stickers/packs/${packId}/subscription`);
}

export function unsubscribeStickerPack(packId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/stickers/packs/${packId}/subscription`);
}

export function uploadStickerToPack(
  packId: string,
  input: UploadStickerToPackInput,
): Promise<AxiosResponse<StickerSummary>> {
  const formData = new FormData();
  formData.append('emoji', input.emoji);
  if (input.name?.trim()) formData.append('name', input.name.trim());
  if (input.description?.trim()) formData.append('description', input.description.trim());
  formData.append('file', input.file);

  return apiClient.post(`/stickers/packs/${packId}/stickers`, formData);
}

export function removeStickerFromPack(packId: string, stickerId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/stickers/packs/${packId}/stickers/${stickerId}`);
}

export function favoriteSticker(stickerId: string): Promise<AxiosResponse<void>> {
  return apiClient.put(`/stickers/${stickerId}/favorite`);
}

export function unfavoriteSticker(stickerId: string): Promise<AxiosResponse<void>> {
  return apiClient.delete(`/stickers/${stickerId}/favorite`);
}

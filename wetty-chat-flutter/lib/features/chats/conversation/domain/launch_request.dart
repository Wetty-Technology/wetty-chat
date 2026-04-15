import 'package:freezed_annotation/freezed_annotation.dart';

part 'launch_request.freezed.dart';

@freezed
sealed class LaunchRequest with _$LaunchRequest {
  const LaunchRequest._();

  const factory LaunchRequest.latest() = LatestLaunchRequest;

  const factory LaunchRequest.unread({required int lastReadMessageId}) =
      UnreadLaunchRequest;

  const factory LaunchRequest.message({
    required int messageId,
    @Default(true) bool highlight,
  }) = MessageLaunchRequest;

  bool get isLatest => this is LatestLaunchRequest;
  bool get isUnread => this is UnreadLaunchRequest;
}

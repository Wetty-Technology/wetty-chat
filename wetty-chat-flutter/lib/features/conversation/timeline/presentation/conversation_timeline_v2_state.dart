import 'package:chahua/features/conversation/timeline/domain/conversation_message_v2.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'conversation_timeline_v2_state.freezed.dart';

enum ConversationTimelineV2ViewportCommandKind {
  none,
  resetToCenterOrigin,
  scrollToBottom,
}

enum ConversationTimelineV2ViewportPlacement { bottomPreferred, topPreferred }

typedef ConversationTimelineV2ViewportCommand = ({
  ConversationTimelineV2ViewportCommandKind kind,
  ConversationTimelineV2ViewportPlacement placement,
});

@freezed
abstract class ConversationTimelineV2State with _$ConversationTimelineV2State {
  const factory ConversationTimelineV2State({
    @Default(<ConversationMessageV2>[])
    List<ConversationMessageV2> beforeMessages,
    @Default(<ConversationMessageV2>[])
    List<ConversationMessageV2> afterMessages,
    @Default(false) bool canLoadOlder,
    @Default(false) bool canLoadNewer,
    @Default(false) bool isLoadingOlder,
    @Default(false) bool isLoadingNewer,
    @Default(false) bool isResolvingJump,
    String? highlightedStableKey,
    @Default((
      kind: ConversationTimelineV2ViewportCommandKind.none,
      placement: ConversationTimelineV2ViewportPlacement.bottomPreferred,
    ))
    ConversationTimelineV2ViewportCommand viewportCommand,
    @Default(0) int viewportCommandGeneration,
    @Default(true) bool isBootstrapping,
  }) = _ConversationTimelineV2State;
}

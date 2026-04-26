class MessageOverlayMetricsV2 {
  const MessageOverlayMetricsV2._();

  static const double screenPadding = 16;
  static const double panelMinWidth = 176;
  static const double panelMaxWidth = 260;
  static const double rowHeight = 48;
  static const double separatorHeight = 1;
  static const double gap = 10;
  static const double reactionBarHeight = 44;

  static double actionPanelHeight(int actionCount) {
    if (actionCount <= 0) {
      return 0;
    }
    return (actionCount * rowHeight) + ((actionCount - 1) * separatorHeight);
  }
}

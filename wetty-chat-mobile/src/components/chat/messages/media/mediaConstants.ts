export const MEDIA_CONSTANTS = {
  // 多图 Grid/Justified 目标比例和限制
  JUSTIFIED_TARGET_ROW_RATIO: 1.8, // 一行目标期望铺满的累计宽高比
  JUSTIFIED_MIN_ROW_RATIO: 1.2, // 一行的最低比例（低于此比例将被限制高度，产生带模糊背景的效果，防止刷屏）
  JUSTIFIED_MIN_ITEM_RATIO: 0.5, // 单图参与网格排版的最极端细长比例
  JUSTIFIED_MAX_ITEM_RATIO: 3.0, // 单图参与网格排版的最极端宽扁比例

  // 图片/视频之间的间距
  GAP: 2,

  // 模糊效果半径
  BLUR_RADIUS: '20px',
  // 暗化背景，防止亮图模糊后文字看不清或对比度太弱
  BLUR_OVERLAY_OPACITY: 0.2,
};

export const getSingleMediaBounds = () => {
  const vh = typeof window !== 'undefined' ? window.innerHeight : 800;
  const vw = typeof window !== 'undefined' ? window.innerWidth : 400;
  return {
    MAX_WIDTH: Math.min(vw * 0.7, 420), // 限制绝对最大宽度，避免桌面端屏幕过大导致气泡巨屏
    MAX_HEIGHT: Math.min(vh * 0.6, 560), // 最大高度限制为 60vh，同时限制绝对最大高度
    MIN_WIDTH: 120, // 高窄图的最小宽度保障
    MIN_HEIGHT: 80, // 宽扁图的最小高度保障
  };
};

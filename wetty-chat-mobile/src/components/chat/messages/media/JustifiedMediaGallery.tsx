import React, { useMemo } from 'react';
import type { Attachment } from '@/api/messages';
import { SingleMediaAttachment } from './SingleMediaAttachment';
import { getSingleMediaBounds, MEDIA_CONSTANTS, MAX_ATTACHMENT_PREVIEWS } from '@/constants/media';
import styles from './JustifiedMediaGallery.module.scss';
import type { ReactNode, CSSProperties } from 'react';

const GAP = MEDIA_CONSTANTS.GAP; // px

interface JustifiedMediaGalleryProps {
  attachments: Attachment[];
  interactive: boolean;
  onView: (id: string) => void;
  renderElement: (id: string, style?: CSSProperties) => ReactNode;
}

/**
 * 真正意义上的 Justified 瀑布流布局算法 (Flickr / Telegram 方案)
 * 1. 绝对保留上传顺序 (left-to-right, top-to-bottom)
 * 2. 探寻最佳的"行划分"（比如 5图分为 2+3 或者 3+2 等），使得裁切或变形拉伸最小化
 * 3. 严格遵从最高 maxHeight / 宽度 maxWidth 的阈值设定，不留缝隙
 */
function calculateJustifiedRows(attachments: Attachment[], maxWidth: number, maxHeight: number) {
  const items = attachments.slice(0, MAX_ATTACHMENT_PREVIEWS);
  const count = items.length;

  // 保底原图比例，并限制单极值避免过宽或过窄导致用户看不清
  const MIN_ITEM_RATIO = 0.5; // 最窄宽/高比，保证细长子图不至于太窄（例如封顶 1:2）
  const MAX_ITEM_RATIO = 2.5; // 最扁宽/高比，保证横向子图不至于太细（例如封顶 2.5:1）

  const ratios = items.map((att) => {
    const w = att.width || 100;
    const h = att.height || 100;
    let ratio = w / h;

    // 夹断极限长宽比，迫使它通过 object-fit: cover 缩放裁切
    if (ratio < MIN_ITEM_RATIO) ratio = MIN_ITEM_RATIO;
    if (ratio > MAX_ITEM_RATIO) ratio = MAX_ITEM_RATIO;

    return ratio;
  });

  // 根据数量提供可能的分行组合
  const configsByCount: Record<number, number[][]> = {
    2: [[2], [1, 1]],
    3: [[3], [2, 1], [1, 2]],
    4: [[2, 2], [3, 1], [1, 3], [4]],
    5: [
      [2, 3],
      [3, 2],
      [1, 2, 2],
      [2, 2, 1],
      [1, 3, 1],
    ],
    6: [
      [3, 3],
      [2, 2, 2],
      [4, 2],
      [2, 4],
      [2, 3, 1],
      [1, 3, 2],
    ],
    7: [
      [3, 4],
      [4, 3],
      [2, 3, 2],
      [3, 2, 2],
      [2, 2, 3],
    ],
    8: [
      [4, 4],
      [3, 3, 2],
      [2, 3, 3],
      [3, 2, 3],
      [2, 4, 2],
    ],
    9: [
      [3, 3, 3],
      [4, 5],
      [5, 4],
      [2, 3, 4],
      [4, 3, 2],
      [3, 4, 2],
      [2, 4, 3],
    ],
  };

  const configs = configsByCount[count] || [[count]]; // Fallback

  let bestScore = Infinity;
  let bestLayout: any[] = [];
  let bestTotalHeight = 0;

  for (const config of configs) {
    let currentItemIndex = 0;
    let totalHeight = 0;
    const rows = [];

    // 对于该切分配置，算出它们如果占满屏幕宽度，各自需要的高度
    for (const itemsInRow of config) {
      const rowItems = items.slice(currentItemIndex, currentItemIndex + itemsInRow);
      const rowRatios = ratios.slice(currentItemIndex, currentItemIndex + itemsInRow);

      const sumRatios = rowRatios.reduce((a, b) => a + b, 0);
      const availableWidth = maxWidth - GAP * (itemsInRow - 1);
      // 该行的基准等比放大高度：
      const rowHeight = availableWidth / sumRatios;

      rows.push({
        items: rowItems.map((item, i) => ({
          item,
          ratio: rowRatios[i],
          index: currentItemIndex + i,
        })),
        height: rowHeight,
      });

      totalHeight += rowHeight;
      currentItemIndex += itemsInRow;
    }

    totalHeight += GAP * (config.length - 1);

    // -- 打分系统 (Score)：分数越低越好 --
    let score = 0;

    // 1. 如果整体极端偏离 max 高度，进行惩罚。
    if (totalHeight > maxHeight * 1.3) {
      score += (totalHeight - maxHeight) * 10;
    }

    // 2. 惩罚奇葩过高或过扁的行
    for (const r of rows) {
      if (r.height > maxWidth * 1.5) {
        score += r.height * 20; // 极其不可接受的极高纵向单幅
      }
      if (r.height < maxWidth * 0.15) {
        score += (maxWidth * 0.15 - r.height) * 5; // 过于扁平
      }
    }

    // 3. 追求矩阵规整性，避免行高方差过大。
    const avgHeight = (totalHeight - GAP * (config.length - 1)) / rows.length;
    for (const r of rows) {
      score += Math.abs(r.height - avgHeight);
    }

    if (score < bestScore) {
      bestScore = score;
      bestLayout = rows;
      bestTotalHeight = totalHeight;
    }
  }

  // 尺寸降维处理限制：
  let finalTotalHeight = bestTotalHeight;
  let scale = 1;
  // 严格遵守边界，不能超长度。如果最优算出来超出最大容器限制，强制进行同占比缩放保底！
  if (bestTotalHeight > maxHeight) {
    scale = (maxHeight - GAP * (bestLayout.length - 1)) / (bestTotalHeight - GAP * (bestLayout.length - 1));
    finalTotalHeight = maxHeight;
  }

  return { rows: bestLayout, scale, finalTotalHeight };
}

export const JustifiedMediaGallery: React.FC<JustifiedMediaGalleryProps> = ({
  attachments,
  interactive,
  onView,
  renderElement,
}) => {
  const { MAX_WIDTH, MAX_HEIGHT } = useMemo(() => getSingleMediaBounds(), []);

  const { rows, scale, finalTotalHeight } = useMemo(() => {
    if (!attachments || attachments.length <= 1) return { rows: [], scale: 1, finalTotalHeight: 0 };
    return calculateJustifiedRows(attachments, MAX_WIDTH, MAX_HEIGHT);
  }, [attachments, MAX_WIDTH, MAX_HEIGHT]);

  if (!attachments || attachments.length === 0) return null;

  if (attachments.length === 1) {
    return (
      <SingleMediaAttachment
        attachment={attachments[0]}
        interactive={interactive}
        onView={() => onView(attachments[0].id)}
        renderElement={renderElement.bind(null, attachments[0].id)}
      />
    );
  }

  // 超过最大预览数时，最后一张图高斯模糊计算超出数量（包含遮罩自身隐藏的那张图）
  const extraCount =
    attachments.length > MAX_ATTACHMENT_PREVIEWS ? attachments.length - MAX_ATTACHMENT_PREVIEWS + 1 : 0;

  return (
    <div
      className={styles.galleryContainer}
      style={{
        width: '100%',
        minWidth: MAX_WIDTH,
        maxWidth: '100%',
        maxHeight: `${MAX_HEIGHT}px`, // Cap the height like single images
        aspectRatio: `${MAX_WIDTH} / ${finalTotalHeight}`, // Let it grow height proportionally to width
        display: 'flex',
        flexDirection: 'column',
        gap: `${GAP}px`,
        overflow: 'hidden',
        position: 'relative',
      }}
    >
      {rows.map((row, rIndex) => {
        // distribute height proportionally using flex-grow
        const flexWeight = row.height * scale;

        return (
          <div
            key={`row-${rIndex}`}
            style={{
              display: 'flex',
              flexDirection: 'row',
              gap: `${GAP}px`,
              width: '100%',
              flex: `${flexWeight} 1 0px`,
              minHeight: 0,
            }}
          >
            {row.items.map((cell: { item: Attachment; ratio: number; index: number }, cIndex: number) => {
              const isLastPreview = rIndex === rows.length - 1 && cIndex === row.items.length - 1;
              const showOverlay = isLastPreview && extraCount > 0;

              return (
                <div
                  key={cell.item.id || cell.index}
                  style={{
                    flex: `${cell.ratio} 1 0%`,
                    position: 'relative',
                    overflow: 'hidden',
                    cursor: interactive ? 'pointer' : 'default',
                    backgroundColor: '#f4f4f5',
                    minHeight: 0,
                  }}
                  onClick={(e) => {
                    if (!interactive) return;
                    e.stopPropagation();
                    onView(cell.item.id);
                  }}
                >
                  {renderElement(cell.item.id, {
                    width: '100%',
                    height: '100%',
                    objectFit: 'cover',
                    display: 'block',
                    position: 'absolute',
                    top: 0,
                    left: 0,
                  })}

                  {showOverlay && (
                    <div className={styles.moreOverlay} style={{ zIndex: 2 }}>
                      +{extraCount}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        );
      })}
    </div>
  );
};

export default JustifiedMediaGallery;

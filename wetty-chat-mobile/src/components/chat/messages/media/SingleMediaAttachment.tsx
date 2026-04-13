import { type ReactNode, type CSSProperties } from 'react';
import { MEDIA_CONSTANTS, getSingleMediaBounds } from '@/constants/media';
import type { Attachment } from '@/api/messages';

interface SingleMediaAttachmentProps {
  attachment: Attachment;
  interactive: boolean;
  onView: () => void;
  renderElement: (style?: CSSProperties) => ReactNode;
}

export function SingleMediaAttachment({ attachment, interactive, onView, renderElement }: SingleMediaAttachmentProps) {
  const { width, height, url } = attachment;
  const { MAX_WIDTH, MAX_HEIGHT, MIN_WIDTH, MIN_HEIGHT } = getSingleMediaBounds();
  const { BLUR_RADIUS } = MEDIA_CONSTANTS;

  // 如果没有宽高信息，fallback 为自动
  if (!width || !height) {
    return (
      <div
        style={{
          width: '100%',
          maxWidth: MAX_WIDTH,
          maxHeight: MAX_HEIGHT,
          aspectRatio: '1',
          position: 'relative',
          overflow: 'hidden',
        }}
        onClick={interactive ? onView : undefined}
      >
        {renderElement({ width: '100%', height: '100%', objectFit: 'contain' })}
      </div>
    );
  }

  const aspectRatio = width / height;

  // 1. 获取原图基础尺寸
  let calcWidth = width || MAX_WIDTH;
  let calcHeight = height || calcWidth / aspectRatio;

  // 2. 超限缩放
  if (calcWidth > MAX_WIDTH) {
    calcWidth = MAX_WIDTH;
    calcHeight = calcWidth / aspectRatio;
  }
  if (calcHeight > MAX_HEIGHT) {
    calcHeight = MAX_HEIGHT;
    calcWidth = calcHeight * aspectRatio;
  }
  if (calcWidth < MIN_WIDTH) {
    const scale = MIN_WIDTH / calcWidth;
    if (calcHeight * scale <= MAX_HEIGHT) {
      calcWidth = MIN_WIDTH;
      calcHeight *= scale;
    }
  }
  if (calcHeight < MIN_HEIGHT) {
    const scale = MIN_HEIGHT / calcHeight;
    if (calcWidth * scale <= MAX_WIDTH) {
      calcHeight = MIN_HEIGHT;
      calcWidth *= scale;
    }
  }

  const finalContainerWidth = Math.max(calcWidth, MIN_WIDTH);
  const finalContainerHeight = Math.max(calcHeight, MIN_HEIGHT);

  const containerStyle: CSSProperties = {
    position: 'relative',
    width: '100%',
    minWidth: finalContainerWidth,
    height: finalContainerHeight,
    maxWidth: '100%',
    overflow: 'hidden',
    cursor: interactive ? 'pointer' : 'default',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#000',
  };

  const wrapElement = (
    <div
      style={containerStyle}
      onClick={
        interactive
          ? (e) => {
              e.stopPropagation();
              onView();
            }
          : undefined
      }
    >
      <>
        <div
          style={{
            position: 'absolute',
            top: -20,
            right: -20,
            bottom: -20,
            left: -20,
            backgroundImage: `url(${url})`,
            backgroundSize: 'cover',
            backgroundPosition: 'center',
            filter: `blur(${BLUR_RADIUS})`,
            opacity: 0.8,
          }}
        />
        <div
          style={{
            position: 'absolute',
            top: 0,
            right: 0,
            bottom: 0,
            left: 0,
            backgroundColor: `rgba(0,0,0,${MEDIA_CONSTANTS.BLUR_OVERLAY_OPACITY})`,
          }}
        />
      </>
      <div
        style={{
          position: 'relative',
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {renderElement({
          maxWidth: '100%',
          maxHeight: '100%',
          objectFit: 'contain', // 如果不溢出就 cover 以免白边
          display: 'block',
        })}
      </div>
    </div>
  );

  return wrapElement;
}

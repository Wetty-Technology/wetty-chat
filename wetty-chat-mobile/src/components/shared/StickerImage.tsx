import type { ImgHTMLAttributes } from 'react';
import styles from './StickerImage.module.scss';

export interface StickerImageProps extends ImgHTMLAttributes<HTMLImageElement> {
  slot?: string;
}

export function StickerImage(props: StickerImageProps) {
  const { src, alt, className, ...rest } = props;
  if (!src) return null;

  const isWebm = src.toLowerCase().endsWith('.webm');

  // className prop takes precedence
  const combinedClassName = className ? `${styles.stickerImage} ${className}` : styles.stickerImage;

  if (isWebm) {
    return <video src={src} autoPlay loop muted playsInline className={combinedClassName} {...(rest as any)} />;
  }

  return <img src={src} alt={alt || ''} className={combinedClassName} {...rest} />;
}

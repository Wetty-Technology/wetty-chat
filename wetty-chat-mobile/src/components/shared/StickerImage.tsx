import type { ImgHTMLAttributes } from 'react';

export interface StickerImageProps extends ImgHTMLAttributes<HTMLImageElement> {
  slot?: string;
}

export function StickerImage(props: StickerImageProps) {
  const { src, alt, className, ...rest } = props;
  if (!src) return null;

  const isWebm = src.toLowerCase().endsWith('.webm');

  if (isWebm) {
    return <video src={src} autoPlay loop muted playsInline className={className} {...(rest as any)} />;
  }

  return <img src={src} alt={alt || ''} className={className} {...rest} />;
}

import type { ImgHTMLAttributes } from 'react';

export interface StickerImageProps extends ImgHTMLAttributes<HTMLImageElement> {
  slot?: string;
}

export function StickerImage(props: StickerImageProps) {
  const { src, alt, ...rest } = props;
  if (!src) return null;

  const isWebm = src.toLowerCase().endsWith('.webm');

  if (isWebm) {
    return <video src={src} autoPlay loop muted playsInline {...(rest as any)} />;
  }

  return <img src={src} alt={alt || ''} {...rest} />;
}

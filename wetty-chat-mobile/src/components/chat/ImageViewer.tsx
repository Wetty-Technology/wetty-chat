import { useEffect } from 'react';
import { createPortal } from 'react-dom';
import { IonIcon } from '@ionic/react';
import { close, download } from 'ionicons/icons';
import styles from './ImageViewer.module.scss';

interface ImageViewerProps {
  src: string;
  onClose: () => void;
  fileName?: string;
}

export function ImageViewer({ src, onClose, fileName }: ImageViewerProps) {
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  const handleDownload = async (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      const response = await fetch(src);
      const blob = await response.blob();
      const blobUrl = URL.createObjectURL(blob);

      const link = document.createElement('a');
      link.href = blobUrl;
      const downloadName = fileName || src.split('/').pop()?.split('?')[0] || 'image';
      link.download = downloadName;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(blobUrl);
    } catch (err) {
      console.error('Failed to download image', err);
      // Fallback: try opening in new tab
      window.open(src, '_blank');
    }
  };

  return createPortal(
    <div className={styles.overlay} onClick={onClose}>
      <div className={styles.toolbar} onClick={e => e.stopPropagation()}>
        <button className={styles.iconButton} onClick={handleDownload} title="Download">
          <IonIcon icon={download} />
        </button>
        <button className={styles.iconButton} onClick={onClose} title="Close">
          <IonIcon icon={close} />
        </button>
      </div>
      <img
        src={src}
        className={styles.image}
        onClick={e => e.stopPropagation()}
        alt="Attachment large view"
      />
    </div>,
    document.body
  );
}

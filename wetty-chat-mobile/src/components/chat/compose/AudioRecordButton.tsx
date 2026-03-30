import {
  type CSSProperties,
  type PointerEvent as ReactPointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { IonIcon } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { arrowUp, mic, trash } from 'ionicons/icons';
import styles from './AudioRecordButton.module.scss';

const DEFAULT_SIZE = 36;
const TARGET_GAP = 20;

type SnapPosition = 'origin' | 'left' | 'top';

interface AudioRecordButtonProps {
  size?: number;
  className?: string;
  onStart?: () => void;
  onCancel?: () => void;
  onComplete?: () => void;
  onSend?: () => void;
}

export function AudioRecordButton({
  size = DEFAULT_SIZE,
  className,
  onStart,
  onCancel,
  onComplete,
  onSend,
}: AudioRecordButtonProps) {
  const buttonRef = useRef<HTMLButtonElement | null>(null);
  const gestureRef = useRef<{
    pointerId: number | null;
    startX: number;
    startY: number;
    active: boolean;
  }>({
    pointerId: null,
    startX: 0,
    startY: 0,
    active: false,
  });
  const [isHolding, setIsHolding] = useState(false);
  const [snapPosition, setSnapPosition] = useState<SnapPosition>('origin');

  const targetOffset = size + TARGET_GAP;
  const midpoint = targetOffset / 2;

  const resetGesture = useCallback(() => {
    gestureRef.current = {
      pointerId: null,
      startX: 0,
      startY: 0,
      active: false,
    };
    setIsHolding(false);
    setSnapPosition('origin');
  }, []);

  const getSnapPosition = useCallback(
    (deltaX: number, deltaY: number): SnapPosition => {
      const leftProgress = -deltaX;
      const upProgress = -deltaY;
      const crossedLeft = leftProgress >= midpoint;
      const crossedTop = upProgress >= midpoint;

      if (!crossedLeft && !crossedTop) {
        return 'origin';
      }

      if (crossedLeft && crossedTop) {
        return leftProgress >= upProgress ? 'left' : 'top';
      }

      return crossedLeft ? 'left' : 'top';
    },
    [midpoint],
  );

  const completeGesture = useCallback(
    (finalPosition: SnapPosition) => {
      if (finalPosition === 'left') {
        onCancel?.();
      } else if (finalPosition === 'top') {
        onSend?.();
      } else {
        onComplete?.();
      }

      if (
        buttonRef.current &&
        gestureRef.current.pointerId != null &&
        buttonRef.current.hasPointerCapture(gestureRef.current.pointerId)
      ) {
        buttonRef.current.releasePointerCapture(gestureRef.current.pointerId);
      }

      resetGesture();
    },
    [onCancel, onComplete, onSend, resetGesture],
  );

  const handlePointerDown = useCallback(
    (event: ReactPointerEvent<HTMLButtonElement>) => {
      event.preventDefault();

      gestureRef.current = {
        pointerId: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        active: true,
      };

      event.currentTarget.setPointerCapture(event.pointerId);
      setIsHolding(true);
      setSnapPosition('origin');
      onStart?.();
    },
    [onStart],
  );

  useEffect(() => {
    if (!isHolding) {
      return;
    }

    const handlePointerMove = (event: PointerEvent) => {
      const gesture = gestureRef.current;
      if (!gesture.active || gesture.pointerId !== event.pointerId) {
        return;
      }

      const nextPosition = getSnapPosition(event.clientX - gesture.startX, event.clientY - gesture.startY);
      setSnapPosition((currentPosition) => (currentPosition === nextPosition ? currentPosition : nextPosition));
    };

    const handlePointerFinish = (event: PointerEvent) => {
      const gesture = gestureRef.current;
      if (!gesture.active || gesture.pointerId !== event.pointerId) {
        return;
      }

      const finalPosition = getSnapPosition(event.clientX - gesture.startX, event.clientY - gesture.startY);
      completeGesture(finalPosition);
    };

    window.addEventListener('pointermove', handlePointerMove);
    window.addEventListener('pointerup', handlePointerFinish);
    window.addEventListener('pointercancel', handlePointerFinish);

    return () => {
      window.removeEventListener('pointermove', handlePointerMove);
      window.removeEventListener('pointerup', handlePointerFinish);
      window.removeEventListener('pointercancel', handlePointerFinish);
    };
  }, [completeGesture, getSnapPosition, isHolding]);

  useEffect(() => resetGesture, [resetGesture]);

  const rootStyle = useMemo(
    () =>
      ({
        '--audio-record-button-size': `${size}px`,
        '--audio-record-button-target-offset': `${targetOffset}px`,
        '--audio-record-button-x': snapPosition === 'left' ? `${-targetOffset}px` : '0px',
        '--audio-record-button-y': snapPosition === 'top' ? `${-targetOffset}px` : '0px',
      }) as CSSProperties,
    [size, snapPosition, targetOffset],
  );

  const rootClassName = className ? `${styles.root} ${className}` : styles.root;
  const buttonIcon = snapPosition === 'left' ? trash : snapPosition === 'top' ? arrowUp : mic;
  const buttonClassName = `${styles.button} ${isHolding ? styles.buttonActive : ''} ${snapPosition === 'left' ? styles.buttonCancel : ''}`;

  return (
    <div className={rootClassName} style={rootStyle}>
      <div className={styles.targets} aria-hidden="true">
        <div
          className={`${styles.target} ${styles.targetLeft} ${isHolding ? styles.targetVisible : ''} ${snapPosition === 'left' ? styles.targetActive : ''}`}
        >
          <IonIcon icon={trash} className={styles.targetIcon} />
        </div>
        <div
          className={`${styles.target} ${styles.targetTop} ${isHolding ? styles.targetVisible : ''} ${snapPosition === 'top' ? styles.targetActive : ''}`}
        >
          <IonIcon icon={arrowUp} className={styles.targetIcon} />
        </div>
      </div>
      <button
        ref={buttonRef}
        type="button"
        className={buttonClassName}
        onPointerDown={handlePointerDown}
        onClick={(event) => event.preventDefault()}
        aria-label={t`Record audio`}
      >
        <IonIcon icon={buttonIcon} className={styles.buttonIcon} />
      </button>
    </div>
  );
}

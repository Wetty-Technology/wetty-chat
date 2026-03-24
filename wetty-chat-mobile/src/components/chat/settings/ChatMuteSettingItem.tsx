import { IonIcon, IonItem, IonLabel, IonNote, useIonActionSheet, useIonToast } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { notifications, notificationsOff } from 'ionicons/icons';
import { useDispatch, useSelector } from 'react-redux';
import { muteChat, unmuteChat } from '@/api/group';
import { setChatMutedUntil } from '@/store/chatsSlice';
import { selectEffectiveLocale } from '@/store/settingsSlice';

interface ChatMuteSettingItemProps {
  chatId: string;
  mutedUntil: string | null | undefined;
}

function isChatMuted(mutedUntil: string | null | undefined): boolean {
  if (!mutedUntil) {
    return false;
  }

  return new Date(mutedUntil) > new Date();
}

function formatMutedUntil(locale: string, mutedUntil: string): string | null {
  const date = new Date(mutedUntil);
  const now = new Date();

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  const diffMs = date.getTime() - now.getTime();
  const diffMinutes = Math.round(diffMs / 60000);
  const diffHours = Math.round(diffMs / 3600000);
  const diffDays = Math.round(diffMs / 86400000);
  const rtf = new Intl.RelativeTimeFormat(locale, { numeric: 'auto' });

  if (Math.abs(diffMinutes) < 60) {
    return rtf.format(diffMinutes === 0 ? 1 : diffMinutes, 'minute');
  }

  if (Math.abs(diffHours) < 24) {
    return rtf.format(diffHours, 'hour');
  }

  if (Math.abs(diffDays) < 7) {
    return rtf.format(diffDays, 'day');
  }

  const isSameYear = date.getFullYear() === now.getFullYear();

  return Intl.DateTimeFormat(locale, {
    ...(isSameYear ? {} : { year: 'numeric' }),
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

function renderMutedUntilLabel(locale: string, mutedUntil: string) {
  if (new Date(mutedUntil).getFullYear() >= 9000) {
    return <Trans>Muted indefinitely</Trans>;
  }

  const formatted = formatMutedUntil(locale, mutedUntil);

  return <Trans>Muted until {formatted ?? mutedUntil}</Trans>;
}

export function ChatMuteSettingItem({ chatId, mutedUntil }: ChatMuteSettingItemProps) {
  const dispatch = useDispatch();
  const locale = useSelector(selectEffectiveLocale);
  const [presentToast] = useIonToast();
  const [presentActionSheet] = useIonActionSheet();
  const muted = isChatMuted(mutedUntil);

  const handleMute = (durationSeconds: number | null) => {
    muteChat(chatId, { duration_seconds: durationSeconds })
      .then((response) => {
        dispatch(setChatMutedUntil({ chatId, mutedUntil: response.data.muted_until }));
        presentToast({ message: t`Notifications muted`, duration: 2000 });
      })
      .catch((error: Error) => {
        presentToast({ message: error.message || t`Failed to mute`, duration: 3000 });
      });
  };

  const handleUnmute = () => {
    unmuteChat(chatId)
      .then(() => {
        dispatch(setChatMutedUntil({ chatId, mutedUntil: null }));
        presentToast({ message: t`Notifications unmuted`, duration: 2000 });
      })
      .catch((error: Error) => {
        presentToast({ message: error.message || t`Failed to unmute`, duration: 3000 });
      });
  };

  const showMuteActionSheet = () => {
    presentActionSheet({
      header: t`Mute notifications`,
      buttons: [
        { text: t`1 hour`, handler: () => handleMute(3600) },
        { text: t`8 hours`, handler: () => handleMute(28800) },
        { text: t`1 day`, handler: () => handleMute(86400) },
        { text: t`7 days`, handler: () => handleMute(604800) },
        { text: t`Forever`, handler: () => handleMute(null), role: 'destructive' },
        { text: t`Cancel`, role: 'cancel' },
      ],
    });
  };

  if (muted && mutedUntil) {
    return (
      <IonItem button detail={false} onClick={handleUnmute}>
        <IonIcon aria-hidden="true" icon={notificationsOff} slot="start" color="danger" />
        <IonLabel color="primary">
          <Trans>Unmute This Group</Trans>
        </IonLabel>
        <IonNote slot="end" color="medium">
          {renderMutedUntilLabel(locale, mutedUntil)}
        </IonNote>
      </IonItem>
    );
  }

  return (
    <IonItem button detail={false} onClick={showMuteActionSheet}>
      <IonIcon aria-hidden="true" icon={notifications} slot="start" color="danger" />
      <IonLabel color="primary">
        <Trans>Mute This Group</Trans>
      </IonLabel>
    </IonItem>
  );
}

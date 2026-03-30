import { useRef, type ChangeEvent } from 'react';
import {
  IonButton,
  IonIcon,
  IonInput,
  IonItem,
  IonLabel,
  IonList,
  IonListHeader,
  IonSelect,
  IonSelectOption,
  IonSpinner,
  IonText,
  IonTextarea,
} from '@ionic/react';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { camera, documentText, eye, people, save } from 'ionicons/icons';
import styles from './ChatSettings.module.scss';

interface ChatAdminSettingsProps {
  name: string;
  description: string;
  visibility: 'public' | 'private';
  avatarUrl: string;
  saving: boolean;
  uploadingAvatar: boolean;
  onNameChange: (value: string) => void;
  onDescriptionChange: (value: string) => void;
  onVisibilityChange: (value: 'public' | 'private') => void;
  onUploadAvatar: (file: File) => Promise<void>;
  onSave: () => void;
}

export function ChatAdminSettings({
  name,
  description,
  visibility,
  avatarUrl,
  saving,
  uploadingAvatar,
  onNameChange,
  onDescriptionChange,
  onVisibilityChange,
  onUploadAvatar,
  onSave,
}: ChatAdminSettingsProps) {
  const fileInputRef = useRef<HTMLInputElement | null>(null);

  const handlePickAvatar = () => {
    if (uploadingAvatar || saving) return;
    fileInputRef.current?.click();
  };

  const handleFileChange = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.target.value = '';
    if (!file) return;
    await onUploadAvatar(file);
  };

  return (
    <>
      <IonListHeader>
        <IonLabel>
          <Trans>Group</Trans>
        </IonLabel>
      </IonListHeader>
      <IonList inset>
        <IonItem>
          <IonIcon aria-hidden="true" icon={people} slot="start" color="primary" />
          <IonLabel position="stacked">
            <Trans>Group Name</Trans>
          </IonLabel>
          <IonInput
            value={name}
            placeholder={t`Enter group name`}
            onIonInput={(event) => onNameChange(event.detail.value ?? '')}
          />
        </IonItem>
        <IonItem>
          <IonIcon aria-hidden="true" icon={documentText} slot="start" color="tertiary" />
          <IonLabel position="stacked">
            <Trans>Description</Trans>
          </IonLabel>
          <IonTextarea
            value={description}
            placeholder={t`Enter group description`}
            onIonInput={(event) => onDescriptionChange(event.detail.value ?? '')}
            rows={3}
          />
        </IonItem>
        <IonItem>
          <IonIcon aria-hidden="true" icon={camera} slot="start" color="medium" />
          <IonLabel className={styles.uploadLabel}>
            <div className={styles.uploadTitle}>
              <Trans>Group Avatar</Trans>
            </div>
            <div className={styles.uploadDescription}>
              {avatarUrl ? (
                <Trans>Choose a new image to replace the current avatar.</Trans>
              ) : (
                <Trans>Upload an image for this group.</Trans>
              )}
            </div>
            {uploadingAvatar ? (
              <IonText color="medium" className={styles.uploadStatus}>
                <IonSpinner name="crescent" />
                <span>
                  <Trans>Uploading avatar...</Trans>
                </span>
              </IonText>
            ) : null}
          </IonLabel>
          <IonButton slot="end" fill="outline" disabled={uploadingAvatar || saving} onClick={handlePickAvatar}>
            <Trans>Upload Avatar</Trans>
          </IonButton>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className={styles.hiddenFileInput}
            onChange={handleFileChange}
          />
        </IonItem>
        <IonItem>
          <IonIcon aria-hidden="true" icon={eye} slot="start" color="secondary" />
          <IonLabel>
            <Trans>Visibility</Trans>
          </IonLabel>
          <IonSelect
            value={visibility}
            onIonChange={(event) => onVisibilityChange(event.detail.value as 'public' | 'private')}
          >
            <IonSelectOption value="public">
              <Trans>Public</Trans>
            </IonSelectOption>
            <IonSelectOption value="private">
              <Trans>Private</Trans>
            </IonSelectOption>
          </IonSelect>
        </IonItem>
        <IonItem button detail={false} disabled={saving || uploadingAvatar} onClick={onSave}>
          <IonIcon aria-hidden="true" icon={save} slot="start" color="primary" />
          <IonLabel color="primary">{saving ? <Trans>Saving...</Trans> : <Trans>Save Settings</Trans>}</IonLabel>
        </IonItem>
      </IonList>
    </>
  );
}

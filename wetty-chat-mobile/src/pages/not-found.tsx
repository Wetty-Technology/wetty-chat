import React from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonBackButton,
  IonButtons,
} from '@ionic/react';

const NotFoundPage: React.FC = () => (
  <IonPage>
    <IonHeader>
      <IonToolbar>
        <IonButtons slot="start">
          <IonBackButton defaultHref="/chats" text="" />
        </IonButtons>
        <IonTitle>Not found</IonTitle>
      </IonToolbar>
    </IonHeader>
    <IonContent>
      <div style={{ padding: '16px' }}>
        <p>Sorry</p>
        <p>Requested content not found.</p>
      </div>
    </IonContent>
  </IonPage>
);

export default NotFoundPage;

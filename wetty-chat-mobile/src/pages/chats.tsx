import { IonPage } from '@ionic/react';
import { ChatList } from '@/components/chat/ChatList';

export default function Chats() {
  return (
    <IonPage className="chats-page">
      <ChatList />
    </IonPage>
  );
}

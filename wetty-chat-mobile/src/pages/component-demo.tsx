import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
} from '@ionic/react';
import { MessageComposeBar } from '../components/chat/MessageComposeBar';

const ComponentDemoPage: React.FC = () => {
  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonTitle>Component Demo</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        <h2>Component Demo</h2>
        <div style={{border: '1px solid #333', borderLeft: 'none', borderRight: 'none'}}>
          <MessageComposeBar onSend={(t) => console.log('send1:', t)} />
        </div>
        <div style={{ height: 100 }} />
        <div style={{border: '1px solid #333', borderLeft: 'none', borderRight: 'none'}}>
          <MessageComposeBar
            onSend={(t) => console.log('send2:', t)}
            replyTo={{ messageId: '123', username: 'Alice', text: 'Hey, did you see the new update? It looks really great and I think we should...' }}
            onCancelReply={() => console.log('cancel reply')}
          />
        </div>
      </IonContent>
    </IonPage>
  );
};

export default ComponentDemoPage;

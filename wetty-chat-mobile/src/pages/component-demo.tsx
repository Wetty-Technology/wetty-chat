import { IonContent, IonHeader, IonPage, IonTitle, IonToolbar } from '@ionic/react';
import { type ComposeUploadInput, MessageComposeBar } from '../components/chat/MessageComposeBar';

const demoUploadAttachment = async ({ onProgress, signal }: ComposeUploadInput) => {
  await new Promise<void>((resolve, reject) => {
    let progress = 0;
    const timer = window.setInterval(() => {
      if (signal.aborted) {
        window.clearInterval(timer);
        reject(new DOMException('Upload aborted', 'AbortError'));
        return;
      }

      progress += 20;
      onProgress(Math.min(progress, 100));

      if (progress >= 100) {
        window.clearInterval(timer);
        resolve();
      }
    }, 150);
  });

  return { attachmentId: `demo_${Date.now()}` };
};

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
        <div style={{ border: '1px solid #333', borderLeft: 'none', borderRight: 'none' }}>
          <MessageComposeBar onSend={(t) => console.log('send1:', t)} uploadAttachment={demoUploadAttachment} />
        </div>
        <div style={{ height: 100 }} />
        <div style={{ border: '1px solid #333', borderLeft: 'none', borderRight: 'none' }}>
          <MessageComposeBar
            onSend={(t) => console.log('send2:', t)}
            uploadAttachment={demoUploadAttachment}
            replyTo={{
              messageId: '123',
              username: 'Alice',
              text: 'Hey, did you see the new update? It looks really great and I think we should...',
            }}
            onCancelReply={() => console.log('cancel reply')}
          />
        </div>
        <div></div>
      </IonContent>
    </IonPage>
  );
};

export default ComponentDemoPage;

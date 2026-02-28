import styles from './ChatBubble.module.scss';

interface ChatBubbleProps {
  senderName: string;
  message: string;
  isSent: boolean;
  avatarColor: string;
}

function getInitials(name: string): string {
  return name.slice(0, 2).toUpperCase();
}

export function ChatBubble({ senderName, message, isSent, avatarColor }: ChatBubbleProps) {
  return (
    <div className={`${styles.row} ${isSent ? styles.sent : styles.received}`}>
      <div className={styles.avatar} style={{ backgroundColor: avatarColor }}>
        {getInitials(senderName)}
      </div>
      <div className={styles.bubble}>
        {!isSent && <div className={styles.senderName}>{senderName}</div>}
        <div className={styles.messageText}>{message}</div>
      </div>
    </div>
  );
}

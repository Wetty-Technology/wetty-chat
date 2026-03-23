import styles from './UserAvatar.module.scss';

interface UserAvatarProps {
  name: string;
  avatarUrl?: string | null;
  size?: number;
  className?: string;
  style?: React.CSSProperties;
  onClick?: () => void;
}

function getInitials(name: string): string {
  return name.slice(0, 2).toUpperCase();
}

function colorForUser(name: string): string {
  let hash = 0;
  for (const char of name) {
    hash = (hash << 5) - hash + char.charCodeAt(0);
    hash |= 0;
  }
  const hue = (((hash * 137) % 360) + 360) % 360;
  return `hsl(${hue}, 55%, 50%)`;
}

export function UserAvatar({ name, avatarUrl, size = 36, className, style, onClick }: UserAvatarProps) {
  const base: React.CSSProperties = {
    width: size,
    height: size,
    ...style,
  };
  const classes = [styles.avatar, onClick ? styles.clickable : null, className].filter(Boolean).join(' ');

  if (avatarUrl) {
    return (
      <div className={classes} style={base} onClick={onClick}>
        <img src={avatarUrl} alt="" className={styles.image} />
      </div>
    );
  }

  return (
    <div
      className={`${classes} ${styles.fallback}`}
      style={{
        ...base,
        backgroundColor: colorForUser(name),
        fontSize: Math.round(size * 0.36),
      }}
      onClick={onClick}
    >
      {getInitials(name)}
    </div>
  );
}

import type { ReactNode } from 'react';
import styles from './InsetContent.module.scss';

interface InsetContentProps {
  children: ReactNode;
  className?: string;
}

export function InsetContent({ children, className }: InsetContentProps) {
  const classes = [styles.root, className].filter(Boolean).join(' ');

  return <div className={classes}>{children}</div>;
}

import React from 'react';
import { Icon } from 'framework7-react';
import './DoubleTickIcon.scss';

interface Props {
  size?: number;
}

export default function DoubleTickIcon({ size = 15 }: Props) {
  return (
    <span className="double-tick-icon">
      <Icon f7="checkmark_alt" size={size} color="primary" />
      <Icon f7="checkmark_alt" size={size} color="primary" />
    </span>
  );
}

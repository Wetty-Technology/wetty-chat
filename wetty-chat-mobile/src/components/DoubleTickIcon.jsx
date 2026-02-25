import React from 'react';
import { Icon } from 'framework7-react';
import './DoubleTickIcon.scss';

export default function DoubleTickIcon(props) {
  const { size = 15 } = props;
  return (
    <span className="double-tick-icon">
      <Icon f7="checkmark_alt" size={size} color="primary" />
      <Icon f7="checkmark_alt" size={size} color="primary" />
    </span>
  );
}

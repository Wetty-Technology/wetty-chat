import React from 'react';

interface FeatureGateProps {
    children: React.ReactNode;
    fallback?: React.ReactNode;
}

export const FeatureGate: React.FC<FeatureGateProps> = ({ children, fallback = null }) => {
    const isEnabled = import.meta.env.DEV;
    return isEnabled ? children : fallback;
};

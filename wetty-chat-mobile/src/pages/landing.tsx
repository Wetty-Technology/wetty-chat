import {
  IonCard,
  IonCardContent,
  IonContent,
  IonHeader,
  IonIcon,
  IonPage,
  IonSegment,
  IonSegmentButton,
  IonText,
  IonTitle,
  IonToolbar,
  isPlatform,
} from '@ionic/react';
import { type ReactNode, useEffect, useState } from 'react';
import {
  ellipsisHorizontal,
  ellipsisVertical,
  logoApple,
  logoChrome,
  logoEdge,
  menuOutline,
  shareOutline,
} from 'ionicons/icons';
import './landing.scss';
import { Redirect, useLocation } from 'react-router';
import { useIsPWA } from '@/hooks/platformHooks';
import { syncJwtTokenFromLanding } from '@/utils/jwtToken';

type PlatformId = 'android' | 'ios' | 'windows' | 'macos' | 'linux';

const platformOptions: Array<{ id: PlatformId; label: string }> = [
  { id: 'android', label: 'Android' },
  { id: 'ios', label: 'iOS' },
  { id: 'windows', label: 'Windows' },
  { id: 'macos', label: 'macOS' },
  { id: 'linux', label: 'Linux' },
];

function IconText({ icon, children }: { icon: string; children: ReactNode }) {
  return (
    <span className="landing-inline-text">
      <IonIcon icon={icon} className="landing-inline-text__icon" />
      <span>{children}</span>
    </span>
  );
}

const detectPlatform = (): PlatformId => {
  if (isPlatform('ios')) {
    return 'ios';
  }
  if (isPlatform('android')) {
    return 'android';
  }

  if (isPlatform('desktop')) {
    const desktopPlatform =
      (navigator as Navigator & { userAgentData?: { platform?: string } }).userAgentData?.platform ??
      navigator.platform;
    const normalizedPlatform = desktopPlatform.toLowerCase();

    if (normalizedPlatform.includes('win')) {
      return 'windows';
    }
    if (normalizedPlatform.includes('mac')) {
      return 'macos';
    }
    if (normalizedPlatform.includes('linux') || normalizedPlatform.includes('x11')) {
      return 'linux';
    }
  }

  return 'android';
};

export default function LandingPage() {
  const detectedPlatform = detectPlatform();
  const isPwa = useIsPWA();
  const [selectedPlatform, setSelectedPlatform] = useState<PlatformId>(detectedPlatform);
  const location = useLocation();

  useEffect(() => {
    syncJwtTokenFromLanding(location.search);
  }, [location]);

  return (
    <IonPage>
      <IonHeader translucent={true}>
        <IonToolbar>
          <IonTitle>安装 茶话</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen={true} className="landing-page">
        <section className="landing-hero">
          <div className="landing-hero__copy">
            <h1>把 茶话 添加到主屏幕</h1>
            <p>安装后可以像原生应用一样从桌面直接启动。</p>
            <p>
              如果你要向朋友推荐，请发送论坛帖子的地址，不要直接发送当前页面地址。当前页面的地址包含你的账号登录信息。
            </p>
            {isPwa && <Redirect to="/" />}
          </div>
        </section>

        <section id="platform-guides" className="landing-content">
          <IonSegment
            mode="ios"
            value={selectedPlatform}
            scrollable={true}
            className="landing-platform-segment"
            onIonChange={(event) => {
              const nextPlatform = event.detail.value;
              if (
                nextPlatform === 'android' ||
                nextPlatform === 'ios' ||
                nextPlatform === 'windows' ||
                nextPlatform === 'macos' ||
                nextPlatform === 'linux'
              ) {
                setSelectedPlatform(nextPlatform);
              }
            }}
          >
            {platformOptions.map((option) => (
              <IonSegmentButton
                key={option.id}
                value={option.id}
                className={option.id === detectedPlatform ? 'landing-platform-segment__button--current' : undefined}
              >
                {option.label}
              </IonSegmentButton>
            ))}
          </IonSegment>

          <IonCard className="landing-card">
            {selectedPlatform === 'android' && (
              <IonCardContent>
                <ol className="landing-steps">
                  <li>
                    使用 <IconText icon={logoChrome}>Chrome 浏览器</IconText> 访问本页
                  </li>
                  <li>
                    点击 <IconText icon={ellipsisVertical}>菜单</IconText>
                  </li>
                  <li>选择“添加到主屏幕”，然后点“安装”</li>
                  <li>确认安装，之后即可从桌面直接打开</li>
                </ol>
                <IonText color="medium">
                  <p className="landing-note">如果浏览器主动弹出了安装界面，直接点安装即可。</p>
                  <p className="landing-note">
                    如果无法使用 Chrome，也可以用 <IconText icon={logoEdge}>Edge 浏览器</IconText>
                    <br />
                    点击 <IconText icon={menuOutline}>菜单</IconText>，选择“添加至手机” (可能会在第二页)。
                  </p>
                </IonText>
              </IonCardContent>
            )}

            {selectedPlatform === 'ios' && (
              <IonCardContent>
                <ol className="landing-steps">
                  <li>
                    使用 <IconText icon={logoApple}>Safari 浏览器</IconText> 访问本页
                  </li>
                  <li>
                    点击 <IconText icon={ellipsisHorizontal}>菜单</IconText>，选择{' '}
                    <IconText icon={shareOutline}>共享</IconText>
                  </li>
                  <li>选择 “添加到主屏幕” (可能会在 “查看更多” 里面)</li>
                  <li>确认添加，之后即可从桌面直接打开</li>
                </ol>
              </IonCardContent>
            )}

            {selectedPlatform === 'windows' && (
              <IonCardContent>
                <ol className="landing-steps">
                  <li>
                    使用 <IconText icon={logoEdge}>Edge 浏览器</IconText> 访问本页。
                  </li>
                  <li>
                    点击 <IconText icon={ellipsisHorizontal}>菜单 </IconText>
                  </li>
                  <li>
                    选择“更多工具” {'>'} “应用” {'>'} “将此站点安装为应用”。
                  </li>
                  <li>自行选择将图标创建在任务栏、开始菜单或桌面。</li>
                </ol>
                <IonText color="medium">
                  <p className="landing-note">如果浏览器在地址栏显示了安装应用按钮，直接点安装即可</p>
                </IonText>
              </IonCardContent>
            )}

            {selectedPlatform === 'macos' && (
              <IonCardContent>
                <ol className="landing-steps">
                  <li>
                    使用 <IconText icon={logoApple}>Safari 浏览器</IconText> 访问本页
                  </li>
                  <li>
                    点击 <IconText icon={shareOutline}>共享</IconText>
                  </li>
                  <li>选择“添加到程序坞”</li>
                  <li>确认添加，之后即可从程序坞或“App”中打开</li>
                </ol>
              </IonCardContent>
            )}

            {selectedPlatform === 'linux' && (
              <IonCardContent>
                <IonText color="medium">
                  <p className="landing-note landing-note--compact">这点小问题想必难不住你 :)</p>
                </IonText>
              </IonCardContent>
            )}
          </IonCard>
        </section>
      </IonContent>
    </IonPage>
  );
}

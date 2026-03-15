import {
  IonBadge,
  IonButton,
  IonCard,
  IonCardContent,
  IonCardHeader,
  IonCardSubtitle,
  IonCardTitle,
  IonContent,
  IonHeader,
  IonIcon,
  IonPage,
  IonText,
  IonTitle,
  IonToolbar,
} from '@ionic/react';
import { arrowForward, downloadOutline, logoAndroid, logoApple, logoWindows, desktopOutline } from 'ionicons/icons';
import './landing.scss';

type PlatformGuide = {
  id: string;
  label: string;
  icon: string;
  accent: string;
  recommendation: string;
  steps: string[];
  note?: string;
};

const platformGuides: PlatformGuide[] = [
  {
    id: 'android',
    label: 'Android',
    icon: logoAndroid,
    accent: 'var(--ion-color-success)',
    recommendation: '推荐使用 Google Chrome。若无法使用，也可以改用 Edge。',
    steps: [
      '打开聊天应用链接。',
      '点击右上角三个点菜单。',
      '选择“添加到主屏幕”或“安装应用”。',
      '确认安装，之后即可从桌面直接打开。',
    ],
    note: '部分 Android 浏览器文案会略有区别，但通常都在右上角菜单里。',
  },
  {
    id: 'ios',
    label: 'iPhone / iPad',
    icon: logoApple,
    accent: 'var(--ion-color-dark)',
    recommendation: '推荐使用 Safari，安装体验最稳定。',
    steps: [
      '在 Safari 中打开聊天应用链接。',
      '点击底部或顶部工具栏里的“分享”。',
      '在分享菜单中选择“添加到主屏幕”。',
      '确认名称后添加，应用图标会出现在主屏幕。',
    ],
    note: '如果你在 iOS 上使用 Chrome 或 Edge，它们底层仍然受 WebKit 限制，建议直接切回 Safari。',
  },
  {
    id: 'windows',
    label: 'Windows',
    icon: logoWindows,
    accent: 'var(--ion-color-primary)',
    recommendation: '推荐使用 Microsoft Edge。',
    steps: [
      '在 Edge 中打开聊天应用链接。',
      '点击右上角三个点菜单。',
      '选择“应用” -> “将此站点安装为应用”或直接点击地址栏里的安装图标。',
      '安装后可从开始菜单或任务栏快速启动。',
    ],
  },
  {
    id: 'macos',
    label: 'macOS',
    icon: logoApple,
    accent: 'var(--ion-color-tertiary)',
    recommendation: '推荐使用 Safari。',
    steps: [
      '在 Safari 中打开聊天应用链接。',
      '点击菜单栏“文件”。',
      '选择“添加到 Dock”。',
      '确认后即可像本地应用一样从 Dock 启动。',
    ],
    note: '如果你的 Safari 版本较旧，看不到该选项，可以先升级系统或临时使用 Chrome/Edge 的安装功能。',
  },
  {
    id: 'linux',
    label: 'Linux',
    icon: desktopOutline,
    accent: 'var(--ion-color-warning)',
    recommendation: 'Chrome、Edge、Chromium 一般都能装，桌面环境不同但思路一样。',
    steps: [
      '用支持 PWA 的浏览器打开聊天应用链接。',
      '查看地址栏右侧是否有安装图标；没有就打开右上角菜单。',
      '选择“安装应用”或“添加到桌面”。',
      '你的桌面环境会替你把剩下的事处理掉。',
    ],
    note: '这点小问题想必难不住你。',
  },
];

const detectPlatform = (): string => {
  const ua = navigator.userAgent.toLowerCase();
  const platform = navigator.platform.toLowerCase();

  if (/iphone|ipad|ipod/.test(ua)) {
    return 'ios';
  }
  if (/android/.test(ua)) {
    return 'android';
  }
  if (platform.includes('win')) {
    return 'windows';
  }
  if (platform.includes('mac')) {
    return 'macos';
  }
  if (platform.includes('linux') || /x11/.test(ua)) {
    return 'linux';
  }

  return 'android';
};

export default function LandingPage() {
  const detectedPlatform = detectPlatform();

  return (
    <IonPage>
      <IonHeader translucent={true}>
        <IonToolbar>
          <IonTitle>安装 Wetty Chat</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent fullscreen={true} className="landing-page">
        <section className="landing-hero">
          <div className="landing-hero__copy">
            <IonBadge color="primary">PWA Install Guide</IonBadge>
            <h1>把 Wetty Chat 放到你的主屏幕上</h1>
            <p>
              安装后可以像原生应用一样从桌面、Dock 或任务栏直接启动，打开更快，也更顺手。
            </p>
            <div className="landing-hero__actions">
              <IonButton routerLink="/chats" shape="round">
                直接进入聊天
                <IonIcon slot="end" icon={arrowForward} />
              </IonButton>
              <IonButton fill="clear" shape="round" href="#platform-guides">
                查看安装步骤
              </IonButton>
            </div>
          </div>
          <div className="landing-hero__panel">
            <div className="landing-hero__panel-header">
              <IonIcon icon={downloadOutline} />
              <span>当前设备建议</span>
            </div>
            <h2>{platformGuides.find((guide) => guide.id === detectedPlatform)?.label}</h2>
            <p>{platformGuides.find((guide) => guide.id === detectedPlatform)?.recommendation}</p>
          </div>
        </section>

        <section className="landing-grid" id="platform-guides">
          {platformGuides.map((guide) => (
            <IonCard key={guide.id} className={guide.id === detectedPlatform ? 'landing-card landing-card--active' : 'landing-card'}>
              <IonCardHeader>
                <div className="landing-card__eyebrow">
                  <div className="landing-card__title-wrap">
                    <IonIcon icon={guide.icon} style={{ color: guide.accent }} />
                    <IonCardTitle>{guide.label}</IonCardTitle>
                  </div>
                  {guide.id === detectedPlatform && (
                    <IonBadge color="dark">当前设备</IonBadge>
                  )}
                </div>
                <IonCardSubtitle>{guide.recommendation}</IonCardSubtitle>
              </IonCardHeader>
              <IonCardContent>
                <ol className="landing-card__steps">
                  {guide.steps.map((step) => (
                    <li key={step}>{step}</li>
                  ))}
                </ol>
                {guide.note && (
                  <IonText color="medium">
                    <p className="landing-card__note">{guide.note}</p>
                  </IonText>
                )}
              </IonCardContent>
            </IonCard>
          ))}
        </section>
      </IonContent>
    </IonPage>
  );
}

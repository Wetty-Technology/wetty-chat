export type BackAction =
  | { type: 'back'; defaultHref: string }
  | { type: 'callback'; onBack: () => void }
  | { type: 'close'; onClose: () => void }

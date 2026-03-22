import Cookies from 'js-cookie';

const JWT_TOKEN_COOKIE_KEY = 'jwt_token';
const JWT_TOKEN_STORAGE_KEY = 'jwt_token';
const JWT_TOKEN_QUERY_PARAM = 'token';
const JWT_TOKEN_COOKIE_OPTIONS = { path: '/', expires: 365 };

function normalizeToken(value: string | null | undefined): string | null {
  const token = value?.trim();
  return token ? token : null;
}

export function getJwtTokenFromQuery(search: string): string | null {
  const searchParams = new URLSearchParams(search);
  return normalizeToken(searchParams.get(JWT_TOKEN_QUERY_PARAM));
}

export function getJwtTokenFromCookie(): string | null {
  return normalizeToken(Cookies.get(JWT_TOKEN_COOKIE_KEY));
}

export function getJwtTokenFromLocalStorage(): string | null {
  if (typeof window === 'undefined') {
    return null;
  }

  return normalizeToken(window.localStorage.getItem(JWT_TOKEN_STORAGE_KEY));
}

export function setJwtTokenCookie(token: string): void {
  Cookies.set(JWT_TOKEN_COOKIE_KEY, token, JWT_TOKEN_COOKIE_OPTIONS);
}

export function setJwtTokenLocalStorage(token: string): void {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.setItem(JWT_TOKEN_STORAGE_KEY, token);
}

export function persistJwtToken(token: string): void {
  setJwtTokenCookie(token);
  setJwtTokenLocalStorage(token);
}

export function syncJwtTokenFromLanding(search: string): string {
  const queryToken = getJwtTokenFromQuery(search);
  if (queryToken) {
    persistJwtToken(queryToken);
    return queryToken;
  }

  return syncStoredJwtToken();
}

export function syncStoredJwtToken(): string {
  const localStorageToken = getJwtTokenFromLocalStorage();
  const cookieToken = getJwtTokenFromCookie();

  if (!localStorageToken && cookieToken) {
    setJwtTokenLocalStorage(cookieToken);
    return cookieToken;
  }

  if (localStorageToken && !cookieToken) {
    setJwtTokenCookie(localStorageToken);
    return localStorageToken;
  }

  return localStorageToken ?? cookieToken ?? '';
}

export function getStoredJwtToken(): string {
  return getJwtTokenFromLocalStorage() ?? getJwtTokenFromCookie() ?? '';
}

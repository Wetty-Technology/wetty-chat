import { openDB, type IDBPDatabase } from 'idb';

const DB_NAME = 'wetty';
const DB_VERSION = 1;

let dbPromise: Promise<IDBPDatabase> | null = null;

export function getDb(): Promise<IDBPDatabase> {
  if (!dbPromise) {
    dbPromise = openDB(DB_NAME, DB_VERSION, {
      upgrade(db) {
        if (!db.objectStoreNames.contains('kv')) {
          db.createObjectStore('kv');
        }
        if (!db.objectStoreNames.contains('notification_hwm')) {
          db.createObjectStore('notification_hwm');
        }
      },
    });
  }
  return dbPromise;
}

export async function kvGet<T>(key: string): Promise<T | undefined> {
  const db = await getDb();
  return db.get('kv', key);
}

export async function kvSet<T>(key: string, value: T): Promise<void> {
  const db = await getDb();
  await db.put('kv', value, key);
}

export async function kvDelete(key: string): Promise<void> {
  const db = await getDb();
  await db.delete('kv', key);
}

export async function getHighWaterMark(chatId: string): Promise<string | undefined> {
  const db = await getDb();
  return db.get('notification_hwm', chatId);
}

export async function setHighWaterMark(chatId: string, messageId: string): Promise<void> {
  const db = await getDb();
  await db.put('notification_hwm', messageId, chatId);
}

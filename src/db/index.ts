import Database from '@tauri-apps/plugin-sql';

let db: Awaited<ReturnType<typeof Database.load>>;

export async function getDb() {
  if (!db) {
    db = await Database.load('sqlite:miji.db');
  }
  return db;
}

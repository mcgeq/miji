// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           tags.ts
// Description:    About Tags Db
// Create   Date:  2025-06-23 23:35:34
// Last Modified:  2025-06-29 16:24:11
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { getDb } from '@/db';
import { Tags } from '@/schema/tags';
import { toCamelCase, toSnakeCase } from '@/utils/common';
import { Lg } from '@/utils/debugLog';

type UpdatableFields = Partial<Record<keyof Tags, string | null>>;

const getTag = async (serialNum: string): Promise<Tags | null> => {
  try {
    const db = await getDb();
    const rows = (await db.select('SELECT * FROM tags WHERE serial_num = ?', [
      serialNum,
    ])) as Tags[];

    if (!rows.length) return null;
    const tag = toCamelCase(rows[0]);
    return tag as Tags;
  } catch (error) {
    Lg.e('TagsDb', error);
    throw new Error('Database error');
  }
};

const list = async (): Promise<Tags[]> => {
  const db = await getDb();
  const rows = await db.select('SELECT * FROM tags');
  return toCamelCase(rows) as Tags[];
};

const insert = async (tag: Tags): Promise<Tags> => {
  const db = await getDb();
  const values = [
    tag.serialNum,
    tag.name,
    tag.description,
    tag.createdAt,
    tag.updatedAt,
  ];
  try {
    await db.execute(
      `INSERT INTO tags (serial_num, name, description, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?)`,
      values,
    );
    return tag;
  } catch (error) {
    Lg.e('TagsDb', error);
    throw new Error('Failed to insert tag');
  }
};

const update = async (tag: Tags): Promise<Tags> => {
  const db = await getDb();
  const values = [tag.name, tag.description, tag.updatedAt, tag.serialNum];
  await db.execute(
    `UPDATE tags SET name = ?, description = ?, updated_at = ? WHERE serial_num = ?`,
    values,
  );
  return tag;
};

const deletes = async (serialNum: string): Promise<void> => {
  const db = await getDb();
  await db.execute('DELETE FROM tags WHERE serial_num = ?', [serialNum]);
};

const updatePartial = async (
  serialNum: string,
  updates: UpdatableFields,
): Promise<void> => {
  const db = await getDb();
  const fields: string[] = [];
  const values: (string | null)[] = [];

  for (const [key, value] of Object.entries(updates)) {
    fields.push(`${toSnakeCase(key)} = ?`);
    values.push(value);
  }

  if (fields.length === 0) return;

  values.push(serialNum);
  const sql = `UPDATE tags SET ${fields.join(', ')} WHERE serial_num = ?`;
  await db.execute(sql, values);
};

export const tagsDb = {
  getTag,
  list,
  insert,
  update,
  deletes,
  updatePartial,
};

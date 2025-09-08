// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           projects.ts
// Description:    About Projects Db
// Create   Date:  2025-06-23 23:35:48
// Last Modified:  2025-06-29 16:25:08
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { getDb } from '@/db';
import { toCamelCase, toSnakeCase } from '@/utils/common';
import { Lg } from '@/utils/debugLog';
import type { Projects } from '@/schema/todos';

type UpdatableFields = Partial<Record<keyof Projects, string | boolean | null>>;

async function getProject(serialNum: string): Promise<Projects | null> {
  try {
    const db = await getDb();
    const rows = (await db.select(
      'SELECT * FROM projects WHERE serial_num = ?',
      [serialNum],
    )) as Projects[];

    if (!rows.length) return null;

    const project = toCamelCase(rows[0]);
    return project as Projects;
  } catch (error) {
    Lg.e('ProjectsDb', error);
    throw new Error('Database error');
  }
}

async function list(): Promise<Projects[]> {
  const db = await getDb();
  const rows = await db.select('SELECT * FROM projects');
  return toCamelCase(rows) as Projects[];
}

async function insert(project: Projects): Promise<Projects> {
  const db = await getDb();
  const values = [
    project.serialNum,
    project.name,
    project.description,
    project.ownerId,
    project.color,
    project.isArchived,
    project.createdAt,
    project.updatedAt,
  ];
  try {
    await db.execute(
      `INSERT INTO projects (
        serial_num, name, description, owner_id, color,
        is_archived, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
      values,
    );
    return project;
  } catch (error) {
    Lg.e('ProjectsDb', error);
    throw new Error('Failed to insert project');
  }
}

async function update(project: Projects): Promise<Projects> {
  const db = await getDb();
  const values = [
    project.name,
    project.description,
    project.ownerId,
    project.color,
    project.isArchived,
    project.updatedAt,
    project.serialNum,
  ];
  await db.execute(
    `UPDATE projects SET
      name = ?, description = ?, owner_id = ?, color = ?,
      is_archived = ?, updated_at = ?
     WHERE serial_num = ?`,
    values,
  );
  return project;
}

async function deletes(serialNum: string): Promise<void> {
  const db = await getDb();
  await db.execute('DELETE FROM projects WHERE serial_num = ?', [serialNum]);
}

async function updatePartial(serialNum: string, updates: UpdatableFields): Promise<void> {
  const db = await getDb();
  const fields: string[] = [];
  const values: (string | boolean | null)[] = [];

  for (const [key, value] of Object.entries(updates)) {
    fields.push(`${toSnakeCase(key)} = ?`);
    values.push(value);
  }

  if (fields.length === 0) return;

  values.push(serialNum);
  const sql = `UPDATE projects SET ${fields.join(', ')} WHERE serial_num = ?`;
  await db.execute(sql, values);
}

export const projectsDb = {
  getProject,
  list,
  insert,
  update,
  deletes,
  updatePartial,
};

// src/lib/api/todos.ts
import { getDb } from '../db';
import type {
  DateRange,
  QueryFilters,
  SortOptions,
  Status,
} from '../schema/common';
import type { Todo } from '../schema/todos';
import { toCamelCase, toSnakeCase } from '../utils/common';
import { Lg } from '../utils/debugLog';

type UpdatableFields = Partial<Record<keyof Todo, Todo[keyof Todo]>>;

/**
 * Fetches a single todo by serialNum from the database.
 * @param serialNum - The unique identifier of the todo.
 * @returns A promise that resolves to the Todo object or null if not found.
 */
const getTodo = async (serialNum: string): Promise<Todo | null> => {
  try {
    const db = await getDb();
    const rows: unknown = await db.select(
      'SELECT * FROM todo WHERE serial_num = ?',
      [serialNum],
    );
    const typedRows = rows as Todo[];
    return typedRows.length > 0 ? toCamelCase(typedRows[0]) : null;
  } catch (error) {
    Lg.e('TodoDb', error);
    throw new Error('Database error');
  }
};

/**
 * Fetches todos from the database, optionally filtered by status.
 * @param status - Optional status to filter todos by.
 * @returns A promise that resolves to an array of Todo objects.
 */
const list = async (
  userSerialNum: string,
  status?: Status,
): Promise<Todo[]> => {
  const db = await getDb();
  let sql: string;
  let params: (string | number | boolean | null)[] = [];

  if (status) {
    sql = 'SELECT * FROM todo WHERE status = ?';
    params = [status];
  } else {
    sql = 'SELECT * FROM todo WHERE ownerId = ?';
    params = [userSerialNum];
  }

  const rows = await db.select(sql, params);
  return toCamelCase(rows) as Todo[];
};

const listPaged = async (
  userSerialNum: string,
  filters: QueryFilters = {},
  page = 1,
  pageSize = 5,
  sortOptions: SortOptions = {},
): Promise<{ rows: Todo[]; totalCount: number }> => {
  const offset = (page - 1) * pageSize;
  const db = await getDb();

  let whereParts: string[] = ['owner_id = ?'];
  const params: (string | number | boolean | null)[] = [userSerialNum];

  if (filters.status) {
    whereParts.push('status = ?');
    params.push(filters.status);
  }

  appendDateRange('created_at', filters.createdAtRange, whereParts, params);
  appendDateRange('completed_at', filters.completedAtRange, whereParts, params);
  appendDateRange('due_at', filters.dueAtRange, whereParts, params);

  const whereClause =
    whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';

  const orderClause = sortOptions.customOrderBy
    ? `ORDER BY ${sortOptions.customOrderBy}`
    : sortOptions.sortBy
      ? `ORDER BY ${sortOptions.sortBy} ${sortOptions.sortDir ?? 'ASC'}`
      : '';

  // 查询当前页数据
  const rows = await db.select(
    `SELECT * FROM todo ${whereClause} ${orderClause} LIMIT ? OFFSET ?`,
    [...params, pageSize, offset],
  );

  // 查询总条数
  const totalRes = await db.select<{ cnt: number }[]>(
    `SELECT COUNT(*) as cnt FROM todo ${whereClause}`,
    params,
  );
  const total = totalRes[0]?.cnt ?? 0;

  return {
    rows: toCamelCase(rows) as Todo[],
    totalCount: total,
  };
};

/**
 * Deletes a todo from the database by its serialNum.
 * @param serialNum - The unique identifier of the todo to delete.
 * @returns A promise that resolves when the deletion is complete.
 */
const deletes = async (serialNum: string): Promise<void> => {
  const db = await getDb();
  await db.execute('DELETE FROM todo WHERE serial_num = ?', [serialNum]);
};

/**
 * Inserts a new todo into the database.
 * @param todo - The todo data without a serialNum.
 * @returns A promise that resolves to the created Todo object.
 */
const insert = async (todo: Todo): Promise<Todo> => {
  await validateForeignKeys(todo);
  const db = await getDb();
  const values = [
    todo.serialNum,
    todo.title,
    todo.description,
    todo.createdAt,
    todo.updatedAt,
    todo.dueAt,
    todo.priority,
    todo.status,
    todo.repeat,
    todo.completedAt,
    todo.assigneeId,
    todo.progress,
    todo.location,
    todo.ownerId,
    todo.isArchived,
    todo.isPinned,
    todo.estimateMinutes,
    todo.reminderCount,
    todo.parentId,
    todo.subtaskOrder,
  ];

  try {
    await db.execute(
      `INSERT INTO todo (
        serial_num, title, description, created_at, updated_at, due_at, priority, status,
        repeat, completed_at, assignee_id, progress, location, owner_id, is_archived,
        is_pinned, estimate_minutes, reminder_count, parent_id, subtask_order
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      values,
    );
    return todo;
  } catch (error) {
    Lg.e('TodoDb', error);
    throw new Error('Failed to insert todo into database');
  }
};
/**
 * Updates an existing todo in the database.
 * @param todo - The todo object with updated fields, including serialNum.
 * @returns A promise that resolves to the updated Todo object.
 */
const update = async (todo: Todo): Promise<Todo> => {
  const db = await getDb();
  const values = [
    todo.title,
    todo.description,
    todo.updatedAt,
    todo.dueAt,
    todo.priority,
    todo.status,
    todo.repeat,
    todo.completedAt,
    todo.assigneeId,
    todo.progress,
    todo.location,
    todo.ownerId,
    todo.isArchived,
    todo.isPinned,
    todo.estimateMinutes,
    todo.reminderCount,
    todo.parentId,
    todo.subtaskOrder,
    todo.serialNum,
  ];
  await db.execute(
    `UPDATE todo SET
    title = ?, description = ?, updated_at = ?, due_at = ?, priority = ?, status = ?,
    repeat = ?, completed_at = ?, assignee_id = ?, progress = ?, location = ?,
    owner_id = ?, is_archived = ?, is_pinned = ?, estimate_minutes = ?,
    reminder_count = ?, parent_id = ?, subtask_order = ?
  WHERE serial_num = ?`,
    values,
  );
  return todo;
};

/**
 * Updates a todo in the database, only applying changed fields.
 * @param newTodo - The new todo object with updated fields.
 * @returns A promise that resolves when the update is complete.
 */
const updateSmart = async (newTodo: Todo): Promise<void> => {
  const oldTodo = toCamelCase(await getTodo(newTodo.serialNum));
  if (!oldTodo) return;

  const updates: UpdatableFields = {};
  for (const key in newTodo) {
    const k = key as keyof Todo;
    const oldVal = oldTodo[k];
    const newVal = newTodo[k];

    // Compare: ignore differences between undefined and null, or customize as needed
    const isEqual = JSON.stringify(oldVal) === JSON.stringify(newVal);
    if (!isEqual) {
      updates[k] = newVal;
    }
  }

  if (Object.keys(updates).length === 0) {
    Lg.e('TodoDb', 'No changes detected');
    return;
  }

  await updatePartial(newTodo.serialNum, updates);
};

/**
 * Updates specific fields of a todo in the database.
 * @param serialNum - The unique identifier of the todo.
 * @param updates - Partial Todo object with fields to update.
 * @returns A promise that resolves when the update is complete.
 */
const updatePartial = async (
  serialNum: string,
  updates: UpdatableFields,
): Promise<void> => {
  const db = await getDb();
  const fields: string[] = [];
  const values: (string | number | boolean | null)[] = [];

  for (const [key, value] of Object.entries(updates)) {
    const snakeKey = toSnakeCase(key);
    fields.push(`${snakeKey} = ?`);
    if (
      typeof value === 'object' &&
      value !== null &&
      !(value instanceof Date)
    ) {
      values.push(JSON.stringify(value));
    } else {
      values.push(value as string | number | boolean | null);
    }
  }

  if (fields.length === 0) return;

  values.push(serialNum);
  const sql = `UPDATE todo SET ${fields.join(', ')} WHERE serial_num = ?`;
  await db.execute(sql, values);
};

async function validateForeignKeys(todo: Todo) {
  const db = await getDb();
  if (todo.ownerId) {
    const ownerExists = await db.select(
      'SELECT * FROM users WHERE serial_num = ?',
      [todo.ownerId],
    );
    if (!ownerExists) {
      throw new Error(
        `Foreign key constraint failed: ownerId "${todo.ownerId}" does not exist in users`,
      );
    }
  }
}

const appendDateRange = (
  field: string,
  range: DateRange | undefined,
  whereParts: string[],
  params: (string | number | boolean | null)[],
) => {
  if (!range) return;
  if (range.start) {
    whereParts.push(`${field} >= ?`);
    params.push(range.start);
  }
  if (range.end) {
    whereParts.push(`${field} <= ?`);
    params.push(range.end);
  }
};

export const todosDb = {
  list,
  listPaged,
  insert,
  deletes,
  update,
  updateSmart,
};

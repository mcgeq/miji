// src/lib/stores/auth.ts
import { writable } from 'svelte/store';
import type { User } from '../schema/user';

export const user = writable<User | null>(null);

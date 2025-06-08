// src/types/index.ts
export interface Todo {
  id: number;
  title: string;
  completed: boolean;
}

export interface Checklist {
  id: number;
  title: string;
  items: string[];
}

export interface Transaction {
  id: number;
  amount: number;
  category: string;
  date: string;
}

export interface Period {
  id: number;
  startDate: string;
  endDate: string;
  symptoms: string[];
}

export interface User {
  id: number;
  username: string;
  token: string;
}

export interface Credentials {
  username: string; // Changed from username to match form
  email: string;
  password: string;
  code: string;
}

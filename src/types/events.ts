export interface TodoInputEvents {
  add: { text: string };
}

export interface TodoListEvents {
  toggle: { serialNum: string };
  remove: { serialNum: string };
}

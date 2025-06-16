export type TodoInputEvents = {
  add: { text: string };
};

export type TodoListEvents = {
  toggle: { serial_num: string };
  remove: { serial_num: string };
};

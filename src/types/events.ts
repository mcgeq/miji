export type TodoInputEvents = {
  add: { text: string };
};

export type TodoListEvents = {
  toggle: { serialNum: string };
  remove: { serialNum: string };
};

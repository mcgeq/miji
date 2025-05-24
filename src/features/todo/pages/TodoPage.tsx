import { invoke } from '@tauri-apps/api/core';

export default function TodoPage() {
  const greet = async () => {
    const name = await invoke('greet', { name: 'mcgeq' });
    console.log(name);
  };
  return (
    <>
      <div className="text-xl font-bold">📝 Todo Page</div>{' '}
      <button type="button" onClick={greet}>
        Greet
      </button>
    </>
  );
}

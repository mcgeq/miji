import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import '@unocss/reset/tailwind.css';
import 'virtual:uno.css';
import 'virtual:unocss-devtools';
import { attachConsole } from '@tauri-apps/plugin-log';

attachConsole();

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);

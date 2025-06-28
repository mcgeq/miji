import { createApp } from 'vue';
import App from './App.vue';
import 'uno.css';
import 'virtual:unocss-devtools';

window.onload = () => import('uno:icons.css');
createApp(App).mount('#app');

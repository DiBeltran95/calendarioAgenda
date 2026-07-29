import { mount } from 'svelte'
// Tipografía e iconos empaquetados en la app. Antes venían de Google Fonts por
// CDN, así que sin internet los iconos se veían como texto ("close", "delete").
import 'material-icons/iconfont/filled.css'
import '@fontsource/roboto/300.css'
import '@fontsource/roboto/400.css'
import '@fontsource/roboto/500.css'
import '@fontsource/roboto/700.css'
import './app.css'
import App from './App.svelte'

const app = mount(App, {
  target: document.getElementById('app')!,
})

export default app

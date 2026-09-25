import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/geist'
import '@fontsource-variable/geist-mono'
import '@fontsource-variable/outfit'
import '@fontsource-variable/fraunces'
import '@fontsource-variable/roboto'
import '../styles/global.css'
import '../styles/screens.css'
import { PalliPage } from '../pages/PalliPage'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <PalliPage />
  </StrictMode>,
)

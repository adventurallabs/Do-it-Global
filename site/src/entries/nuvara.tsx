import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/geist'
import '@fontsource-variable/geist-mono'
import '@fontsource-variable/archivo'
import '@fontsource-variable/plus-jakarta-sans'
import '../styles/global.css'
import '../styles/screens.css'
import { NuvaraPage } from '../pages/NuvaraPage'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <NuvaraPage />
  </StrictMode>,
)

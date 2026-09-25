import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import '@fontsource-variable/geist'
import '@fontsource-variable/geist-mono'
import '../styles/global.css'
import { CompanyPage } from '../pages/CompanyPage'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <CompanyPage />
  </StrictMode>,
)

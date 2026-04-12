import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import './i18n'

// Note: Removed React.StrictMode temporarily
// StrictMode runs effects twice in dev to detect issues, causing API calls to repeat
// This is intended behavior in dev, but we'll disable for testing
ReactDOM.createRoot(document.getElementById('root')!).render(
  <App />
)

import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import en from './en.json'
import fr from './fr.json'

const savedLang = localStorage.getItem('gg_lang') || 'en'

i18n
  .use(initReactI18next)
  .init({
    resources: { en: { translation: en }, fr: { translation: fr } },
    lng: savedLang,
    fallbackLng: 'en',
    interpolation: { escapeValue: false },
  })

export function setLanguage(lang: 'en' | 'fr') {
  i18n.changeLanguage(lang)
  localStorage.setItem('gg_lang', lang)
}

export default i18n

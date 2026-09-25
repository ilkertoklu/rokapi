export function pluralize(forms, count) {
  const form = new Intl.PluralRules(document.documentElement.lang).select(count)
  return (forms[form] ?? forms.other).replace("%{count}", count)
}

---
name: localization
description: Use this skill to translate localization files
---

## Adding missing translations
First you should extract anything that needs to be translated by using

```sh
npm run extract
```

Then you should examine translation files in `locales/<language>/messages.po`
`msgstr ""` would indicate an item is missing translation

Fill in the missing translation with appropiate adaptation for the target language.

---
name: localization
description: Use this skill when you need to update the localization of the PWA app (wetty-chat-mobile)
---

## Adding missing translations for the PWA
First you should extract anything that needs to be translated by using
the following command in `wetty-chat-mobile` directory
```sh
npm run lingui:extract
```

Then you should examine translation files in `locales/<language>/messages.po`
`msgstr ""` would indicate an item is missing translation

If a string got commented out after running extract that's likely because it is
not used any more. It is a good idea to remove it.

Fill in the missing translation with appropiate adaptation for the target language.

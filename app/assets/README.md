# App Assets

This folder contains the app's visual assets.

## Required Files

The following files are referenced in `app.json` but are optional for development:

- `icon.png` - App icon (1024x1024px recommended)
- `splash.png` - Splash screen image
- `adaptive-icon.png` - Android adaptive icon (1024x1024px)
- `favicon.png` - Web favicon (48x48px)

## Development Note

These assets are not required to run the app during development. Expo will use default placeholders if they are missing.

## Creating Assets

If you want to add custom branding:

1. **App Icon (`icon.png`):**
   - Size: 1024x1024px
   - Format: PNG with transparency
   - Should work well at small sizes

2. **Splash Screen (`splash.png`):**
   - Size: 1284x2778px (scales for all devices)
   - Format: PNG
   - Center important content

3. **Adaptive Icon (`adaptive-icon.png`):**
   - Size: 1024x1024px
   - Format: PNG with transparency
   - Keep important content in the center 66% (safe zone)

4. **Favicon (`favicon.png`):**
   - Size: 48x48px or larger
   - Format: PNG

## Using Asset Generators

You can use online tools to generate all required assets from a single image:
- [Expo Asset Generator](https://github.com/expo/expo-cli)
- [App Icon Generator](https://www.appicon.co/)

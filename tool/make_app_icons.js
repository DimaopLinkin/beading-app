#!/usr/bin/env node
// Рисует иконки iOS и macOS из docs/design/app_icon.svg по размерам из Contents.json.
// Запуск: node tool/make_app_icons.js   (нужен пакет playwright с Chromium).
// iOS: квадрат без прозрачности, маску накладывает система. macOS: скруглённая плитка с полями и прозрачными углами.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const svg = fs.readFileSync(path.join(root, 'docs/design/app_icon.svg'), 'utf8');
const sets = {
  ios: path.join(root, 'ios/Runner/Assets.xcassets/AppIcon.appiconset'),
  macos: path.join(root, 'macos/Runner/Assets.xcassets/AppIcon.appiconset'),
};

function pixelSizes(dir) {
  const { images } = JSON.parse(fs.readFileSync(path.join(dir, 'Contents.json'), 'utf8'));
  const out = new Map();
  for (const i of images) {
    const base = parseFloat(i.size);
    out.set(i.filename, Math.round(base * parseFloat(i.scale)));
  }
  return out;
}

function html(px, mac) {
  // Плитка macOS: 824 из 1024 (по шаблону Apple), радиус 22,5%.
  const inner = mac
    ? `<div style="width:${px}px;height:${px}px;display:flex;align-items:center;justify-content:center"><div style="width:80.47%;height:80.47%;border-radius:22.5%;overflow:hidden;box-shadow:0 ${px * 0.01}px ${px * 0.02}px rgba(0,0,0,.3)">${svg}</div></div>`
    : svg;
  return `<html><body style="margin:0;background:${mac ? 'transparent' : '#9C3F14'}"><style>svg{width:${mac ? '100%' : px + 'px'};height:${mac ? '100%' : px + 'px'};display:block}</style>${inner}</body></html>`;
}

(async () => {
  const browser = await chromium.launch();
  for (const [name, dir] of Object.entries(sets)) {
    for (const [file, px] of pixelSizes(dir)) {
      const page = await browser.newPage({ viewport: { width: px, height: px } });
      await page.setContent(html(px, name === 'macos'));
      await page.screenshot({ path: path.join(dir, file), omitBackground: name === 'macos' });
      await page.close();
    }
  }
  await browser.close();
})();

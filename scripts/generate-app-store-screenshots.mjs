import fs from "node:fs/promises";
import path from "node:path";
import sharp from "sharp";

const root = process.cwd();
const sourceDir = path.join(root, ".development_document", "source");
const outputRoot = path.join(root, "app-store-assets");
const requiredDir = path.join(outputRoot, "6.9-inch-1320x2868");
const backupDir = path.join(outputRoot, "6.7-inch-1290x2796");

const W = 1320;
const H = 2868;

const asset = (name) => path.join(sourceDir, name);

const slides = [
  {
    file: "01-photo-summon-card.png",
    title: "拍照召喚戰鬥卡",
    subtitle: "把日常物件變成專屬怪獸",
    screenshot: asset("手機截圖1.png"),
    hero: asset("snap-fighter-banner.png"),
    accent: "#f6c34a",
    titleY: 220,
    phoneY: 700,
  },
  {
    file: "02-ai-card-generation.png",
    title: "AI 生成卡面與屬性",
    subtitle: "照片、元素、技能一次完成",
    screenshot: asset("手機截圖2.png"),
    hero: asset("snap-fighter-banner.png"),
    accent: "#55d5ff",
    titleY: 210,
    phoneY: 735,
  },
  {
    file: "03-build-two-card-deck.png",
    title: "雙卡牌組編成",
    subtitle: "主將副將搭配進場效果",
    screenshot: asset("手機截圖5.png"),
    hero: asset("snap-fighter-女角.png"),
    accent: "#f6c34a",
    titleY: 2060,
    phoneY: 260,
  },
  {
    file: "04-turn-based-battle.png",
    title: "回合制魔法決鬥",
    subtitle: "攻擊、防禦、技能、換卡自由選",
    screenshot: asset("手機截圖3.png"),
    hero: asset("snap-fighter-banner.png"),
    accent: "#c44fc8",
    titleY: 210,
    phoneY: 720,
  },
  {
    file: "05-victory-collection.png",
    title: "勝利收藏你的卡牌",
    subtitle: "每場戰鬥都留下新的牌組故事",
    screenshot: asset("手機截圖4.png"),
    hero: asset("snap-fighter-banner.png"),
    accent: "#f6c34a",
    titleY: 2050,
    phoneY: 260,
  },
];

function escapeXml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function textSvg({ title, subtitle, accent, y }) {
  const titleLines = title.length > 9 ? [title.slice(0, 7), title.slice(7)] : [title];
  const lineGap = 154;
  const titleBlock = titleLines
    .map((line, index) => {
      const yy = y + index * lineGap;
      return `
        <text x="92" y="${yy + 10}" class="title shadow">${escapeXml(line)}</text>
        <text x="92" y="${yy}" class="title">${escapeXml(line)}</text>
      `;
    })
    .join("");
  const subtitleY = y + titleLines.length * lineGap + 38;

  return Buffer.from(`
    <svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
      <style>
        .label { font-family: "PingFang TC", "Noto Sans TC", system-ui, sans-serif; font-size: 40px; font-weight: 900; letter-spacing: 8px; }
        .title { font-family: "PingFang TC", "Noto Sans TC", system-ui, sans-serif; font-size: 126px; font-weight: 1000; letter-spacing: 0; fill: #fffaf1; }
        .shadow { fill: #161016; stroke: #161016; stroke-width: 18px; paint-order: stroke; opacity: .88; }
        .subtitle { font-family: "PingFang TC", "Noto Sans TC", system-ui, sans-serif; font-size: 58px; font-weight: 900; fill: #fffaf1; }
        .subtitleShadow { fill: #151019; stroke: #151019; stroke-width: 12px; paint-order: stroke; opacity: .9; }
      </style>
      <text x="94" y="${y - 82}" class="label" fill="${accent}">攝靈者卡牌</text>
      ${titleBlock}
      <text x="94" y="${subtitleY + 8}" class="subtitle subtitleShadow">${escapeXml(subtitle)}</text>
      <text x="94" y="${subtitleY}" class="subtitle">${escapeXml(subtitle)}</text>
    </svg>
  `);
}

function chromeSvg({ accent, phoneW, phoneH }) {
  const r = 92;
  return Buffer.from(`
    <svg width="${phoneW}" height="${phoneH}" viewBox="0 0 ${phoneW} ${phoneH}" xmlns="http://www.w3.org/2000/svg">
      <rect x="0" y="0" width="${phoneW}" height="${phoneH}" rx="${r}" fill="#070913"/>
      <rect x="16" y="16" width="${phoneW - 32}" height="${phoneH - 32}" rx="${r - 16}" fill="none" stroke="${accent}" stroke-opacity=".78" stroke-width="8"/>
      <rect x="${phoneW * 0.36}" y="34" width="${phoneW * 0.28}" height="34" rx="17" fill="#070913"/>
    </svg>
  `);
}

function clipSvg({ width, height, radius }) {
  return Buffer.from(`
    <svg width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" xmlns="http://www.w3.org/2000/svg">
      <rect width="${width}" height="${height}" rx="${radius}" ry="${radius}" fill="#fff"/>
    </svg>
  `);
}

function glowSvg(accent) {
  return Buffer.from(`
    <svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
      <defs>
        <radialGradient id="g1" cx="72%" cy="34%" r="58%">
          <stop offset="0%" stop-color="${accent}" stop-opacity=".44"/>
          <stop offset="52%" stop-color="${accent}" stop-opacity=".1"/>
          <stop offset="100%" stop-color="${accent}" stop-opacity="0"/>
        </radialGradient>
        <radialGradient id="g2" cx="18%" cy="84%" r="64%">
          <stop offset="0%" stop-color="#c44fc8" stop-opacity=".32"/>
          <stop offset="68%" stop-color="#55d5ff" stop-opacity=".08"/>
          <stop offset="100%" stop-color="#55d5ff" stop-opacity="0"/>
        </radialGradient>
        <pattern id="dots" width="34" height="34" patternUnits="userSpaceOnUse">
          <circle cx="4" cy="4" r="2.2" fill="#fff" opacity=".18"/>
        </pattern>
      </defs>
      <rect width="${W}" height="${H}" fill="url(#g1)"/>
      <rect width="${W}" height="${H}" fill="url(#g2)"/>
      <rect y="${H - 540}" width="${W}" height="540" fill="url(#dots)" opacity=".55"/>
      <path d="M-80 ${H - 400} C280 ${H - 610} 820 ${H - 120} 1400 ${H - 330}" stroke="${accent}" stroke-width="18" stroke-opacity=".42" fill="none"/>
    </svg>
  `);
}

async function coverImage(input, width, height, blur = 0) {
  let img = sharp(input).resize(width, height, { fit: "cover", position: "center" });
  if (blur) img = img.blur(blur);
  return img.png().toBuffer();
}

async function makePhoneComposite(screenshotPath, accent, phoneY) {
  const phoneW = 720;
  const innerW = 660;
  const innerH = Math.round(innerW * 2532 / 1170);
  const phoneH = innerH + 74;
  const x = Math.round((W - phoneW) / 2);
  const innerX = x + Math.round((phoneW - innerW) / 2);
  const innerY = phoneY + 42;

  const screenshot = await sharp(screenshotPath)
    .resize(innerW, innerH, { fit: "cover", position: "top" })
    .composite([{ input: clipSvg({ width: innerW, height: innerH, radius: 64 }), blend: "dest-in" }])
    .png()
    .toBuffer();

  return [
    {
      input: Buffer.from(`
        <svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
          <ellipse cx="${W / 2}" cy="${phoneY + phoneH - 80}" rx="410" ry="76" fill="#000" opacity=".44"/>
          <ellipse cx="${W / 2}" cy="${phoneY + 280}" rx="440" ry="620" fill="${accent}" opacity=".18"/>
        </svg>
      `),
      top: 0,
      left: 0,
    },
    { input: chromeSvg({ accent, phoneW, phoneH }), left: x, top: phoneY },
    { input: screenshot, left: innerX, top: innerY },
  ];
}

async function renderSlide(slide) {
  const base = await coverImage(slide.hero, W, H, 12);
  const phoneLayers = await makePhoneComposite(slide.screenshot, slide.accent, slide.phoneY);

  const overlays = [
    { input: glowSvg(slide.accent), left: 0, top: 0 },
    {
      input: Buffer.from(`
        <svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
          <rect width="${W}" height="${H}" fill="#070913" opacity=".54"/>
          <rect width="${W}" height="${H}" fill="url(#v)"/>
          <defs>
            <linearGradient id="v" x1="0" x2="0" y1="0" y2="1">
              <stop offset="0%" stop-color="#070913" stop-opacity=".1"/>
              <stop offset="48%" stop-color="#070913" stop-opacity=".12"/>
              <stop offset="100%" stop-color="#070913" stop-opacity=".74"/>
            </linearGradient>
          </defs>
        </svg>
      `),
      left: 0,
      top: 0,
    },
    ...phoneLayers,
    { input: textSvg({ title: slide.title, subtitle: slide.subtitle, accent: slide.accent, y: slide.titleY }), left: 0, top: 0 },
  ];

  const out = await sharp(base).composite(overlays).png().toBuffer();
  const requiredPath = path.join(requiredDir, slide.file);
  const backupPath = path.join(backupDir, slide.file);
  await sharp(out).png().toFile(requiredPath);
  await sharp(out).resize(1290, 2796, { fit: "fill" }).png().toFile(backupPath);
}

async function main() {
  await fs.mkdir(requiredDir, { recursive: true });
  await fs.mkdir(backupDir, { recursive: true });
  for (const slide of slides) {
    await renderSlide(slide);
    console.log(`created ${slide.file}`);
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

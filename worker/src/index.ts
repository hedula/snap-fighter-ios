export interface Env {
  AI: Ai;
  ALLOWED_ORIGINS?: string;
  RATE_LIMIT_PER_MINUTE?: string;
}

type MonsterResponse = {
  name: string;
  element: "火" | "水" | "草" | "電" | "暗" | "一般";
  hp: number;
  atk: number;
  def: number;
  skill: string;
};

type WorkersAiResponse = {
  response?: unknown;
};

const DEFAULT_VISION_MODEL = "@cf/meta/llama-3.2-11b-vision-instruct";
const MAX_ANALYZE_ATTEMPTS = 2;
const DEFAULT_RATE_LIMIT_PER_MINUTE = 20;
const fantasyNamePrefixes: Record<MonsterResponse["element"], string[]> = {
  "火": ["焰冠", "熔核", "赤燼"],
  "水": ["潮冕", "霜潮", "深淵"],
  "草": ["藤冠", "森咒", "翠牙"],
  "電": ["雷核", "閃煌", "天鳴"],
  "暗": ["冥影", "夜咒", "黑曜"],
  "一般": ["星鐵", "幻界", "秘銀"]
};
const fantasyNameSuffixes = ["獸", "王", "騎士", "守衛", "獵手", "魔將", "使", "機兵"];
const fantasyNameMarkers = [
  "焰", "炎", "熔", "燼", "潮", "霜", "淵", "藤", "森", "翠",
  "雷", "閃", "鳴", "冥", "影", "夜", "咒", "曜", "星", "幻",
  "秘", "龍", "魔", "王", "皇", "騎士", "守衛", "獵手", "魔將",
  "使", "獸", "機兵"
];
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const requestId = crypto.randomUUID();
    const origin = request.headers.get("Origin");

    if (request.method === "OPTIONS") {
      if (!isOriginAllowed(origin, env.ALLOWED_ORIGINS, true)) {
        return json({ error: "Origin not allowed", requestId }, 403, requestId);
      }
      return new Response(null, {
        status: 204,
        headers: corsHeaders(requestId)
      });
    }

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true, requestId }, 200, requestId);
    }

    if (request.method !== "POST" || url.pathname !== "/analyze") {
      return json({ error: "Not found", requestId }, 404, requestId);
    }

    try {
      if (!isOriginAllowed(origin, env.ALLOWED_ORIGINS)) {
        return json({ error: "Origin not allowed", requestId }, 403, requestId);
      }

      const clientIp = request.headers.get("CF-Connecting-IP") || "unknown";
      const limitPerMinute = parseRateLimit(env.RATE_LIMIT_PER_MINUTE);
      if (!consumeRateLimit(clientIp, limitPerMinute)) {
        return json({ error: "Rate limit exceeded", requestId }, 429, requestId);
      }

      const body = (await request.json()) as { imageBase64?: string };
      if (!body?.imageBase64) {
        return json({ error: "Missing imageBase64", requestId }, 400, requestId);
      }

      const image = `data:image/jpeg;base64,${body.imageBase64}`;
      const rawMonster = await analyzeMonsterWithRetry(env, image, requestId);
      const monster = normalizeMonster(rawMonster);

      console.info("[workers_ai_analyze_success]", {
        requestId,
        model: DEFAULT_VISION_MODEL
      });

      return json(monster, 200, requestId, {
        "X-AI-Provider": "workers-ai",
        "X-AI-Model": DEFAULT_VISION_MODEL
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown worker error";
      console.error("[analyze_error]", { requestId, message });
      return json({ error: message, requestId }, 500, requestId);
    }
  }
};

async function analyzeMonsterWithRetry(env: Env, image: string, requestId: string): Promise<unknown> {
  let lastError: Error | null = null;

  for (let attempt = 1; attempt <= MAX_ANALYZE_ATTEMPTS; attempt += 1) {
    try {
      const modelPayload = await runWorkersAiVisionModel(env, image, attempt);
      return parseMonsterJson(modelPayload);
    } catch (error) {
      const normalized = error instanceof Error ? error : new Error("Unknown Workers AI parse error");
      lastError = normalized;

      console.warn("[workers_ai_analyze_retry]", {
        requestId,
        attempt,
        maxAttempts: MAX_ANALYZE_ATTEMPTS,
        message: normalized.message
      });

      if (attempt >= MAX_ANALYZE_ATTEMPTS || !isRetryableModelOutputError(normalized)) {
        throw normalized;
      }
    }
  }

  throw lastError ?? new Error("Workers AI analyze retry exhausted");
}

async function runWorkersAiVisionModel(env: Env, image: string, attempt: number): Promise<unknown> {
  const messages = [
    { role: "system", content: buildSystemPrompt(attempt) },
    { role: "user", content: buildUserPrompt(attempt) }
  ];

  const result = await env.AI.run(DEFAULT_VISION_MODEL, {
    messages,
    image,
    max_tokens: 300,
    temperature: attempt == 1 ? 0.2 : 0.1
  }) as WorkersAiResponse;

  const payload = extractWorkersAiText(result);
  if (payload == null) {
    throw new Error("Workers AI returned empty content");
  }

  return payload;
}

function buildSystemPrompt(attempt: number): string {
  const prompt = [
    "你是一個中二奇幻怪物卡牌命名師。",
    "先辨識圖片中最明顯的主物件，再將它擬人化為戰鬥角色。",
    "name 必須保留主物件線索，例如杯、貓、燈、瓶、鞋、鍵盤、背包、椅等，不能只寫神秘生物或未知物體。",
    "name 風格要像 JRPG 怪物或少年漫畫稱號：中二、遊戲化、有戰鬥感，但不要使用真實品牌、人名、英文、數字或標點。",
    "name 建議格式：屬性/氣質稱號 + 物件線索 + 身分尾綴。例：冥焰杯王、雷核鍵盤使、潮瓶守衛、影牙背包獸、星鐵滑鼠皇。",
    "你必須只輸出 JSON，且不得輸出 markdown。",
    "不得輸出額外說明、前言、註解。",
    "JSON schema:",
    '{"name":"4~8字中文中二怪物名","element":"火|水|草|電|暗|一般","hp":50~100,"atk":30~80,"def":20~60,"skill":"8~16字中文招式名"}',
    "skill 請對應主物件與屬性，例如杯可用沸騰、鍵盤可用連打、鞋可用疾走。"
  ];

  if (attempt > 1) {
    prompt.push("這是重試。請特別確保 JSON 完整閉合，所有字串都正確加上雙引號並結尾。");
  }

  return prompt.join("\n");
}

function buildUserPrompt(attempt: number): string {
  if (attempt > 1) {
    return "上一次輸出格式不完整。這次請只回傳一行完整 JSON，禁止換行與禁止 markdown。";
  }
  return "請依照 schema 回傳 JSON。";
}

function extractWorkersAiText(result: WorkersAiResponse): unknown | null {
  const response = result.response;
  if (typeof response === "string") {
    return response;
  }
  if (response && typeof response === "object") {
    return response;
  }
  return null;
}

function parseMonsterJson(payload: unknown): unknown {
  if (payload && typeof payload === "object") {
    return payload;
  }

  if (typeof payload !== "string") {
    throw new Error("Workers AI output is not a string/object JSON payload");
  }

  const cleaned = payload
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();

  return JSON.parse(cleaned);
}

function isRetryableModelOutputError(error: Error): boolean {
  const message = error.message.toLowerCase();
  return message.includes("unterminated string")
    || message.includes("unexpected end of json input")
    || message.includes("expected ',' or '}'")
    || message.includes("workers ai returned empty content");
}

function normalizeMonster(raw: unknown): MonsterResponse {
  if (!raw || typeof raw !== "object") {
    throw new Error("Model output is not an object");
  }

  const r = raw as Record<string, unknown>;
  const allowedElements = new Set(["火", "水", "草", "電", "暗", "一般"]);

  const element = typeof r.element === "string" && allowedElements.has(r.element)
    ? (r.element as MonsterResponse["element"])
    : "一般";

  return {
    name: gamifyMonsterName(r.name, element),
    element,
    hp: clampNumber(r.hp, 50, 100, 70),
    atk: clampNumber(r.atk, 30, 80, 50),
    def: clampNumber(r.def, 20, 60, 35),
    skill: clampString(r.skill, "普通一擊：穩定輸出", 6, 40)
  };
}

function gamifyMonsterName(value: unknown, element: MonsterResponse["element"]): string {
  const normalized = normalizeNameToken(value);
  if (normalized && isFantasyMonsterName(normalized)) {
    return normalized.slice(0, 8);
  }

  const objectClue = extractObjectClue(normalized);
  const source = objectClue || "召喚";
  const prefix = pickByHash(fantasyNamePrefixes[element], `${element}:${source}`);
  const suffix = chooseSuffix(prefix, source, `${source}:${element}`);
  const maxObjectLength = Math.max(2, 8 - prefix.length - suffix.length);
  const compactObject = source.slice(0, maxObjectLength);

  return `${prefix}${compactObject}${suffix}`.slice(0, 8);
}

function normalizeNameToken(value: unknown): string {
  if (typeof value !== "string") return "";
  return value
    .trim()
    .replace(/[A-Za-z0-9\s"'`.,，。:：;；!?！？()[\]{}<>《》「」『』【】／/\\|_-]/g, "")
    .slice(0, 12);
}

function isFantasyMonsterName(name: string): boolean {
  if (name.length < 4) return false;
  if (/(神秘|未知|普通|一般|物體|東西|生物)/.test(name)) return false;
  return fantasyNameMarkers.some((marker) => name.includes(marker));
}

function extractObjectClue(name: string): string {
  return name
    .replace(/^(神秘|未知|普通|一般|可愛|小小|這個|一隻|一個)+/, "")
    .replace(/(怪物|怪獸|生物|物體|東西|角色)+$/g, "")
    .slice(0, 6);
}

function chooseSuffix(prefix: string, objectClue: string, seed: string): string {
  const availableLength = 8 - prefix.length - objectClue.length;
  const candidates = fantasyNameSuffixes.filter((suffix) => suffix.length <= availableLength);
  return pickByHash(candidates.length > 0 ? candidates : ["獸"], seed);
}

function pickByHash<T>(values: T[], seed: string): T {
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return values[hash % values.length];
}

function clampNumber(value: unknown, min: number, max: number, fallback: number): number {
  if (typeof value !== "number" || Number.isNaN(value)) return fallback;
  return Math.max(min, Math.min(max, Math.round(value)));
}

function clampString(value: unknown, fallback: string, minLen: number, maxLen: number): string {
  if (typeof value !== "string") return fallback;
  const trimmed = value.trim();
  if (!trimmed) return fallback;
  if (trimmed.length < minLen) return fallback;
  return trimmed.slice(0, maxLen);
}

function json(data: unknown, status = 200, requestId?: string, extraHeaders?: HeadersInit): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(requestId),
      ...(extraHeaders || {})
    }
  });
}

function corsHeaders(requestId?: string): HeadersInit {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
  };

  if (requestId) {
    headers["X-Request-Id"] = requestId;
  }

  return headers;
}

function isOriginAllowed(origin: string | null, allowedOriginsRaw?: string, isPreflight = false): boolean {
  if (!allowedOriginsRaw || !allowedOriginsRaw.trim()) return true;
  if (!origin) return !isPreflight;

  const allowed = allowedOriginsRaw
    .split(",")
    .map((v) => v.trim())
    .filter((v) => v.length > 0);

  return allowed.includes(origin);
}

function parseRateLimit(value?: string): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return DEFAULT_RATE_LIMIT_PER_MINUTE;
  return Math.floor(parsed);
}

function consumeRateLimit(key: string, limitPerMinute: number): boolean {
  const now = Date.now();
  const windowMs = 60_000;
  const existing = rateLimitStore.get(key);

  if (!existing || now >= existing.resetAt) {
    rateLimitStore.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }

  if (existing.count >= limitPerMinute) {
    return false;
  }

  existing.count += 1;
  return true;
}

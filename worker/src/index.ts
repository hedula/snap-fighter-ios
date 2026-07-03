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
    "你是一個奇幻角色生成器。",
    "分析圖片中最明顯的物體，將它擬人化為一個戰鬥角色。",
    "你必須只輸出 JSON，且不得輸出 markdown。",
    "不得輸出額外說明、前言、註解。",
    "JSON schema:",
    '{"name":"2~6字中文","element":"火|水|草|電|暗|一般","hp":50~100,"atk":30~80,"def":20~60,"skill":"10~20字中文"}',
    "skill 請保持精簡，避免超過 16 個中文字。"
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
    name: clampString(r.name, "神秘生物", 2, 8),
    element,
    hp: clampNumber(r.hp, 50, 100, 70),
    atk: clampNumber(r.atk, 30, 80, 50),
    def: clampNumber(r.def, 20, 60, 35),
    skill: clampString(r.skill, "普通一擊：穩定輸出", 6, 40)
  };
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

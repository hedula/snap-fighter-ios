export interface Env {
  HF_TOKEN: string;
  HF_MODEL?: string;
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

type HfChatCompletionResponse = {
  choices?: Array<{
    message?: {
      content?: unknown;
    };
  }>;
  error?: {
    message?: string;
    type?: string;
    code?: string | number;
  };
};

const DEFAULT_HF_MODEL = "openai/gpt-oss-120b:fastest";
const HF_CHAT_COMPLETIONS_URL = "https://router.huggingface.co/v1/chat/completions";
const DEFAULT_RATE_LIMIT_PER_MINUTE = 20;
const rateLimitStore = new Map<string, { count: number; resetAt: number }>();

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const requestId = crypto.randomUUID();
    const origin = request.headers.get("Origin");

    if (request.method === "OPTIONS") {
      if (!isOriginAllowed(origin, env.ALLOWED_ORIGINS)) {
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

      if (!env.HF_TOKEN) {
        return json({ error: "Server missing HF_TOKEN", requestId }, 500, requestId);
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

      const dataUrl = `data:image/jpeg;base64,${body.imageBase64}`;
      const systemPrompt = [
        "你是一個奇幻角色生成器。",
        "分析圖片中最明顯的物體，將它擬人化為一個戰鬥角色。",
        "你必須只輸出 JSON，且不得輸出 markdown。",
        "JSON schema:",
        '{"name":"2~6字中文","element":"火|水|草|電|暗|一般","hp":50~100,"atk":30~80,"def":20~60,"skill":"10~20字中文"}'
      ].join("\n");

      const aiResult = await runHfVisionModel(env, systemPrompt, dataUrl);
      const modelPayload = extractHfMessageContent(aiResult);
      if (modelPayload == null) {
        return json({ error: "Hugging Face returned empty content", requestId }, 502, requestId);
      }

      const monster = normalizeMonster(parseMonsterJson(modelPayload));
      return json(monster, 200, requestId);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown worker error";
      console.error("[analyze_error]", { requestId, message });
      return json({ error: message, requestId }, 500, requestId);
    }
  }
};

async function runHfVisionModel(env: Env, systemPrompt: string, dataUrl: string): Promise<HfChatCompletionResponse> {
  const model = env.HF_MODEL || DEFAULT_HF_MODEL;

  const response = await fetch(HF_CHAT_COMPLETIONS_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.HF_TOKEN}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [
            { type: "image_url", image_url: { url: dataUrl } },
            { type: "text", text: "請依照 schema 回傳 JSON。" }
          ]
        }
      ],
      max_tokens: 300,
      temperature: 0.7
    })
  });

  const rawText = await response.text();
  const parsed = tryParseJson(rawText) as HfChatCompletionResponse | null;

  if (!response.ok) {
    const providerMessage = parsed?.error?.message || rawText || `HTTP ${response.status}`;
    throw new Error(`HF API ${response.status}: ${providerMessage}`);
  }

  if (!parsed) {
    throw new Error("HF API returned non-JSON response");
  }

  return parsed;
}

function extractHfMessageContent(result: HfChatCompletionResponse): unknown {
  const content = result.choices?.[0]?.message?.content;
  if (content == null) return null;

  if (typeof content === "string") {
    return content;
  }

  if (Array.isArray(content)) {
    const textParts = content
      .map((part) => {
        if (!part || typeof part !== "object") return null;
        const p = part as { type?: unknown; text?: unknown };
        if (p.type === "text" && typeof p.text === "string") return p.text;
        return null;
      })
      .filter((v): v is string => typeof v === "string");

    if (textParts.length > 0) {
      return textParts.join("\n");
    }
  }

  return content;
}

function parseMonsterJson(payload: unknown): unknown {
  if (payload && typeof payload === "object") {
    return payload;
  }

  if (typeof payload !== "string") {
    throw new Error("Model output is not a string/object JSON payload");
  }

  const cleaned = payload
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();

  return JSON.parse(cleaned);
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

function tryParseJson(text: string): unknown | null {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

function json(data: unknown, status = 200, requestId?: string): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...corsHeaders(requestId) }
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

function isOriginAllowed(origin: string | null, allowedOriginsRaw?: string): boolean {
  if (!allowedOriginsRaw || !allowedOriginsRaw.trim()) return true;
  if (!origin) return false;

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

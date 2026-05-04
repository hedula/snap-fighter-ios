interface AiBinding {
  run(model: string, options: Record<string, unknown>): Promise<unknown>;
}

export interface Env {
  AI: AiBinding;
}

type MonsterResponse = {
  name: string;
  element: "火" | "水" | "草" | "電" | "暗" | "一般";
  hp: number;
  atk: number;
  def: number;
  skill: string;
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders()
      });
    }

    if (request.method === "GET" && url.pathname === "/health") {
      return json({ ok: true });
    }

    if (request.method !== "POST" || url.pathname !== "/analyze") {
      return json({ error: "Not found" }, 404);
    }

    try {
      const body = (await request.json()) as { imageBase64?: string };
      if (!body?.imageBase64) {
        return json({ error: "Missing imageBase64" }, 400);
      }

      const dataUrl = `data:image/jpeg;base64,${body.imageBase64}`;

      const systemPrompt = [
        "你是一個奇幻角色生成器。",
        "分析圖片中最明顯的物體，將它擬人化為一個戰鬥角色。",
        "你必須只輸出 JSON，且不得輸出 markdown。",
        "JSON schema:",
        '{"name":"2~6字中文","element":"火|水|草|電|暗|一般","hp":50~100,"atk":30~80,"def":20~60,"skill":"10~20字中文"}'
      ].join("\n");

      const aiResult = await runVisionModelWithAutoAgree(env, systemPrompt, dataUrl);

      const text = extractText(aiResult);
      if (!text) {
        return json({ error: "Workers AI returned empty content" }, 502);
      }

      const monster = normalizeMonster(parseMonsterJson(text));
      return json(monster);
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown worker error";
      return json({ error: message }, 500);
    }
  }
};

async function runVisionModelWithAutoAgree(env: Env, systemPrompt: string, dataUrl: string): Promise<unknown> {
  let agreedOnce = false;

  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      return await runVisionModel(env, systemPrompt, dataUrl);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (!message.includes("5016")) {
        throw error;
      }

      if (!agreedOnce) {
        // One-time license gate for this account/model.
        await env.AI.run("@cf/meta/llama-3.2-11b-vision-instruct", { prompt: "agree" });
        agreedOnce = true;
      }

      // Cloudflare may still return a transient 5016 confirmation message once after agreement.
      await sleep(600);
    }
  }

  throw new Error("5016: license gate retry exhausted");
}

async function runVisionModel(env: Env, systemPrompt: string, dataUrl: string): Promise<unknown> {
  return await env.AI.run("@cf/meta/llama-3.2-11b-vision-instruct", {
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
  });
}

function extractText(result: unknown): string | null {
  if (!result || typeof result !== "object") return null;
  const r = result as { response?: string; result?: { response?: string } };
  return r.response ?? r.result?.response ?? null;
}

function parseMonsterJson(text: string): unknown {
  const cleaned = text
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

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...corsHeaders() }
  });
}

function corsHeaders(): HeadersInit {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "GET,POST,OPTIONS"
  };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

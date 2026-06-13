import json
import httpx

OLLAMA_BASE_URL = "http://localhost:11434"


async def generate(
    model: str,
    system: str,
    user: str,
    timeout: int = 60,
) -> dict:
    payload = {
        "model": model,
        "system": system,
        "prompt": user,
        "format": "json",
        "stream": False,
    }
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(
            f"{OLLAMA_BASE_URL}/api/generate",
            json=payload,
        )
        response.raise_for_status()
        data = response.json()
        raw = data.get("response", "{}")
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return {}


async def is_available() -> bool:
    try:
        async with httpx.AsyncClient(timeout=3) as client:
            r = await client.get(f"{OLLAMA_BASE_URL}/api/tags")
            return r.status_code == 200
    except Exception:
        return False

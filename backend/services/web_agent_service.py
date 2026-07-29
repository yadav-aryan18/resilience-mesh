"""
Opportunistic Web Agent — triggered only when internet is available.
Fetches live weather, satellite imagery metadata, and hazard APIs.
"""

import logging
import asyncio
import socket
from typing import Optional

import httpx

logger = logging.getLogger("resiliencemesh.web_agent")

DUCKDUCKGO_URL = "https://html.duckduckgo.com/html/"
OPENMETEO_URL = "https://api.open-meteo.com/v1/forecast"


class WebAgentService:
    async def check_connectivity(self, host: str = "8.8.8.8", port: int = 53, timeout: float = 2.0) -> bool:
        """Quick socket check — no HTTP overhead."""
        try:
            reader, writer = await asyncio.wait_for(
                asyncio.open_connection(host, port), timeout=timeout
            )
            writer.close()
            await writer.wait_closed()
            return True
        except Exception:
            return False

    async def gather_context(self, sector: Optional[str], query: str) -> str:
        """Fetch live context from web APIs."""
        parts = []

        # Weather context if sector implies location
        weather = await self._fetch_weather()
        if weather:
            parts.append(f"Current Weather: {weather}")

        # DuckDuckGo search for disaster-specific updates
        search = await self._search_web(f"disaster response {query}")
        if search:
            parts.append(f"Live Search Results:\n{search}")

        return "\n\n".join(parts) if parts else ""

    async def _fetch_weather(self, lat: float = 0.0, lon: float = 0.0) -> Optional[str]:
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(
                    OPENMETEO_URL,
                    params={
                        "latitude": lat,
                        "longitude": lon,
                        "current": "temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m",
                    },
                )
                data = resp.json()
                current = data.get("current", {})
                return (
                    f"Temp: {current.get('temperature_2m')}°C, "
                    f"Humidity: {current.get('relative_humidity_2m')}%, "
                    f"Wind: {current.get('wind_speed_10m')} km/h"
                )
        except Exception as e:
            logger.debug(f"Weather fetch failed: {e}")
            return None

    async def _search_web(self, query: str) -> Optional[str]:
        import re
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.post(
                    DUCKDUCKGO_URL,
                    data={"q": query, "kl": "us-en"},
                    headers={"User-Agent": "ResilienceMesh/1.0"},
                )
                text = resp.text
                snippets = []
                for line in text.split("\n"):
                    if "result__snippet" in line and len(line) > 60:
                        clean = re.sub(r"<[^>]+>", "", line).strip()
                        if clean and len(clean) > 20:
                            snippets.append(clean)
                    if len(snippets) >= 3:
                        break
                return "\n".join(snippets[:3]) if snippets else None
        except Exception as e:
            logger.debug(f"Web search failed: {e}")
            return None

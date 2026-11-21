import base64
from abc import ABC, abstractmethod

from .models import Protocol
from .transport import UpstreamError, request_json


class OracleProvider(ABC):
    @abstractmethod
    def generate(self, provider, *, messages, model=None):
        """Return generated text."""

    def stream(self, provider, *, messages, model=None):
        raise UpstreamError("streaming_unavailable")

    def health_check(self, provider):
        return request_json(provider, health=True)


class VisionProvider(ABC):
    @abstractmethod
    def recognize_batch(self, provider, *, items, system, deck_id=None):
        """Return a result for every item, keyed by item ID."""

    def recognize(self, provider, *, item, system, deck_id=None):
        return self.recognize_batch(
            provider, items=[item], system=system, deck_id=deck_id,
        )[item["itemId"]]

    def health_check(self, provider):
        return request_json(provider, health=True)


class OpenAIChat(OracleProvider):
    def generate(self, provider, *, messages, model=None):
        data = request_json(provider, {
            "model": model or provider.model, "messages": messages,
            "stream": False, "max_tokens": 1800,
        })
        try:
            text = data["choices"][0]["message"]["content"]
        except (TypeError, IndexError, KeyError):
            raise UpstreamError("provider_invalid_response") from None
        if not isinstance(text, str) or not text.strip() or len(text) > 16000:
            raise UpstreamError("provider_invalid_response")
        return text.strip()


class HttpVision(VisionProvider):
    def recognize_batch(self, provider, *, items, system, deck_id=None):
        data = request_json(provider, {
            "model": provider.model, "system": system, "deckId": deck_id,
            "items": [
                {"itemId": item["itemId"], "mimeType": item["mimeType"],
                 "imageBase64": base64.b64encode(item["bytes"]).decode("ascii")}
                for item in items
            ],
        })
        if not isinstance(data, dict) or not isinstance(data.get("results"), list):
            raise UpstreamError("provider_invalid_response")
        results = {}
        for item in data["results"]:
            if not isinstance(item, dict) or not isinstance(item.get("itemId"), str) or item["itemId"] in results:
                raise UpstreamError("provider_invalid_response")
            results[item["itemId"]] = item
        if results.keys() != {item["itemId"] for item in items}:
            raise UpstreamError("provider_invalid_response")
        return results


ADAPTERS = {Protocol.OPENAI_CHAT: OpenAIChat(), Protocol.HTTP_VISION: HttpVision()}

from decimal import Decimal
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from apps.core.api import Problem

from .adapters import ADAPTERS
from .models import Capability, Lease, Provider, RoutingPolicy, Usage
from .transport import UpstreamError, credentials, endpoint_allowed


def reserve(candidate):
    with transaction.atomic():
        provider = Provider.objects.select_for_update().get(pk=candidate.pk)
        if not provider.enabled or provider.capability != candidate.capability:
            raise UpstreamError("provider_unavailable")
        if candidate.is_paid != provider.is_paid or candidate.priority != provider.priority:
            raise UpstreamError("provider_unavailable")
        if not endpoint_allowed(provider.endpoint, provider.capability):
            raise UpstreamError("provider_unavailable")
        credentials(provider)
        now = timezone.now()
        leases = Lease.objects.filter(provider=provider)
        leases.filter(expires_at__lte=now).delete()
        if leases.count() >= provider.concurrency_limit:
            raise UpstreamError("provider_busy")
        usage, _ = Usage.objects.get_or_create(provider=provider, day=now.date())
        cost = provider.max_cost_per_request if provider.is_paid else Decimal("0")
        if provider.is_paid and (cost <= 0 or not provider.daily_spending_limit):
            raise UpstreamError("provider_unavailable")
        if usage.count >= provider.daily_request_limit or (
            provider.daily_spending_limit is not None
            and usage.reserved_cost + cost > provider.daily_spending_limit
        ):
            raise UpstreamError("provider_quota_exhausted")
        usage.count += 1
        usage.reserved_cost += cost
        usage.save(update_fields=["count", "reserved_cost"])
        return provider, leases.create(
            provider=provider, expires_at=now + timedelta(seconds=provider.connect_timeout + provider.inference_timeout + 20)
        )


def route(capability, invoke, *, provider_id=None):
    providers = list(Provider.objects.filter(capability=capability))
    if provider_id is not None:
        providers = [provider for provider in providers if provider.pk == provider_id]
    allow_paid_fallback = RoutingPolicy.objects.filter(capability=capability, allow_paid_fallback=True).exists()
    last = UpstreamError("provider_unavailable")
    for index, candidate in enumerate(providers):
        if not candidate.enabled:
            continue
        if index and candidate.is_paid and not allow_paid_fallback:
            continue
        for attempt in range(candidate.retries + 1):
            try:
                provider, lease = reserve(candidate)
            except (UpstreamError, Provider.DoesNotExist) as exc:
                last = exc if isinstance(exc, UpstreamError) else UpstreamError("provider_unavailable")
                break
            try:
                return invoke(ADAPTERS[provider.protocol], provider), provider.name
            except UpstreamError as exc:
                last = exc
                if provider.is_paid and not exc.safe_retry:
                    break
                if not exc.safe_retry and exc.code not in {"provider_timeout", "provider_error"}:
                    break
            finally:
                lease.delete()
        if candidate.is_paid and last.code in {"provider_error", "provider_timeout", "provider_invalid_response"}:
            break
    status = {"provider_busy": 503, "provider_quota_exhausted": 429, "provider_timeout": 504,
              "provider_error": 502, "provider_invalid_response": 502}.get(last.code, 503)
    raise Problem(last.code, status, "AI service could not complete this request.")


def generate(messages, *, provider_id=None, model=None):
    return route(
        Capability.ORACLE, lambda adapter, provider: adapter.generate(provider, messages=messages, model=model),
        provider_id=provider_id,
    )


def recognize(items, *, system, deck_id=None):
    def invoke(adapter, provider):
        if len(items) == 1:
            item = items[0]
            return {item["itemId"]: adapter.recognize(provider, item=item, system=system, deck_id=deck_id)}
        return adapter.recognize_batch(provider, items=items, system=system, deck_id=deck_id)

    return route(Capability.VISION, invoke)


def probe(provider):
    status = "unchecked"
    if provider.health_path:
        try:
            ADAPTERS[provider.protocol].health_check(provider)
        except UpstreamError as exc:
            status = exc.code
        else:
            status = "available"
    Provider.objects.filter(pk=provider.pk).update(health=status, health_checked_at=timezone.now())
    return status

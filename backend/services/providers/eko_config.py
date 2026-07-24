"""Load all Eko (eps.eko.in) credentials from environment — never hardcode.

Paste your Eko keys in the backend `.env` file (see `.env.example`):

    EKO_DEVELOPER_KEY=...
    EKO_KEY=...
    EKO_INITIATOR_ID=...
    EKO_USER_CODE=...
    EKO_ENV=sandbox   # or "production"

For UAT/testing, Eko publishes shared sandbox credentials at
https://developers.eko.in/docs/platform-credentials — use those for
EKO_DEVELOPER_KEY / EKO_KEY / EKO_INITIATOR_ID while EKO_ENV=sandbox.
Production keys are issued to you directly by Eko over email once your
organisation's KYC and UAT sign-off are complete.
"""

from dataclasses import dataclass

from django.conf import settings


@dataclass(frozen=True)
class EkoSettings:
    developer_key: str
    key: str  # "Key" from Eko — used to derive secret-key / secret-key-timestamp
    initiator_id: str
    user_code: str
    environment: str
    base_url: str
    api_version: str  # 'v3', 'v2', 'v1' — see EKO_API_VERSION below

    @property
    def is_configured(self) -> bool:
        return bool(self.developer_key and self.key and self.initiator_id)

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in ('production', 'prod', 'live')


def _env(name: str, default: str = '') -> str:
    return (getattr(settings, name, None) or default).strip()


def eko_settings() -> EkoSettings:
    env = _env('EKO_ENV', 'sandbox')
    is_prod = env.lower() in ('production', 'prod', 'live')

    # Staging: staging.eko.in:25004 · Production: api.eko.in:25002
    default_base = 'https://api.eko.in:25002' if is_prod else 'https://staging.eko.in:25004'

    return EkoSettings(
        developer_key=_env('EKO_DEVELOPER_KEY'),
        key=_env('EKO_KEY'),
        initiator_id=_env('EKO_INITIATOR_ID'),
        user_code=_env('EKO_USER_CODE'),
        environment=env,
        base_url=_env('EKO_BASE_URL', default_base),
        # Eko's own docs say a "No mapping rule matched" error is usually fixed by
        # swapping the API version segment in the URL (v3 <-> v2 <-> v1) — expose
        # it as a setting so that can be tried without a code change.
        api_version=_env('EKO_API_VERSION', 'v3'),
    )

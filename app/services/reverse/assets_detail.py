"""
Reverse interface: asset detail.
"""

from typing import Any
from urllib.parse import urlparse

from curl_cffi.requests import AsyncSession

from app.core.config import get_config
from app.core.exceptions import UpstreamException
from app.core.logger import logger
from app.core.proxy_pool import (
    build_http_proxies,
    get_current_proxy_from,
    rotate_proxy,
    should_rotate_proxy,
)
from app.services.reverse.utils.headers import build_headers
from app.services.reverse.utils.retry import retry_on_status
from app.services.token.service import TokenService

DETAIL_API = "https://grok.com/rest/assets/{asset_id}"


class AssetsDetailReverse:
    """/rest/assets/{asset_id} reverse interface."""

    @staticmethod
    async def request(session: AsyncSession, token: str, asset_id: str) -> Any:
        try:
            referer = get_config("app.app_url") or "https://grok.com/"
            parsed_referer = urlparse(referer)
            origin = (
                f"{parsed_referer.scheme}://{parsed_referer.netloc}"
                if parsed_referer.scheme and parsed_referer.netloc
                else "https://grok.com"
            )
            headers = build_headers(
                cookie_token=token,
                content_type="application/json",
                origin=origin,
                referer=referer,
            )

            timeout = get_config("asset.list_timeout")
            browser = get_config("proxy.browser")
            active_proxy_key = None

            async def _do_request():
                nonlocal active_proxy_key
                active_proxy_key, proxy_url = get_current_proxy_from(
                    "proxy.asset_proxy_url",
                    "proxy.base_proxy_url",
                )
                proxies = build_http_proxies(proxy_url)
                response = await session.get(
                    DETAIL_API.format(asset_id=asset_id),
                    headers=headers,
                    proxies=proxies,
                    timeout=timeout,
                    impersonate=browser,
                )

                if response.status_code != 200:
                    logger.error(
                        f"AssetsDetailReverse: Detail failed, {response.status_code}",
                        extra={"error_type": "UpstreamException"},
                    )
                    raise UpstreamException(
                        message=f"AssetsDetailReverse: Detail failed, {response.status_code}",
                        details={"status": response.status_code},
                    )

                return response

            async def _on_retry(
                attempt: int, status_code: int, error: Exception, delay: float
            ):
                if active_proxy_key and should_rotate_proxy(status_code):
                    rotate_proxy(active_proxy_key)

            return await retry_on_status(_do_request, on_retry=_on_retry)

        except Exception as e:
            if isinstance(e, UpstreamException):
                status = None
                if e.details and "status" in e.details:
                    status = e.details["status"]
                else:
                    status = getattr(e, "status_code", None)
                if status == 401:
                    try:
                        await TokenService.record_fail(
                            token, status, "assets_detail_auth_failed"
                        )
                    except Exception:
                        pass
                raise

            logger.error(
                f"AssetsDetailReverse: Detail failed, {str(e)}",
                extra={"error_type": type(e).__name__},
            )
            raise UpstreamException(
                message=f"AssetsDetailReverse: Detail failed, {str(e)}",
                details={"status": 502, "error": str(e)},
            )


__all__ = ["AssetsDetailReverse"]

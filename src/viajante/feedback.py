"""A prefilled GitHub issue link. Viajante sends nothing; the issue exists only once submitted."""

import platform
import sys
import webbrowser
from urllib.parse import quote, urlencode

from viajante.runtime import package_version

NEW_ISSUE_URL = "https://github.com/felipebasurto/viajante/issues/new"
TITLE_LIMIT = 80
MESSAGE_LIMIT = 1000
REMINDER = "<!-- Remove private travel details and credentials before submitting. -->"


def issue_url(message: str = "") -> str:
    text = message.strip()
    title = text.splitlines()[0][:TITLE_LIMIT] if text else ""
    facts = (
        f"Viajante {package_version()}\n"
        f"Python {platform.python_version()}\n"
        f"Platform {platform.platform()}"
    )
    body = "\n\n".join(part for part in (text, facts, REMINDER) if part)
    return f"{NEW_ISSUE_URL}?{urlencode({'title': title, 'body': body}, quote_via=quote)}"


def run_feedback(message: str, *, open_browser: bool) -> int:
    text = message.strip()
    if len(text) > MESSAGE_LIMIT:
        print(
            f"viajante feedback: the message is over {MESSAGE_LIMIT} characters",
            file=sys.stderr,
        )
        return 1
    url = issue_url(text)
    print(url)
    if open_browser:
        webbrowser.open(url)
    return 0

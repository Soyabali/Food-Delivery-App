"""Outgoing email over SMTP (Gmail, Outlook, SendGrid, Mailgun... all speak SMTP).

When SMTP is not configured (local development), messages are written to the
server log instead, so flows like password reset can still be tested.
"""

import logging
import smtplib
import ssl
from email.message import EmailMessage

from app.core.config import get_settings

log = logging.getLogger("apna_food.email")


def smtp_configured() -> bool:
    s = get_settings()
    return bool(s.smtp_host and s.smtp_username and s.smtp_password)


def send_email(to: str, subject: str, text: str, html: str | None = None) -> None:
    """Send one email. Runs in a background task, so failures are logged
    rather than raised to the client."""
    s = get_settings()
    if not smtp_configured():
        log.warning("SMTP not configured - email NOT sent. To: %s | Subject: %s\n%s", to, subject, text)
        return

    msg = EmailMessage()
    msg["From"] = s.smtp_from or s.smtp_username
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(text)
    if html:
        msg.add_alternative(html, subtype="html")

    try:
        if s.smtp_port == 465:
            with smtplib.SMTP_SSL(s.smtp_host, s.smtp_port, context=ssl.create_default_context(), timeout=20) as smtp:
                smtp.login(s.smtp_username, s.smtp_password)
                smtp.send_message(msg)
        else:
            with smtplib.SMTP(s.smtp_host, s.smtp_port, timeout=20) as smtp:
                smtp.starttls(context=ssl.create_default_context())
                smtp.login(s.smtp_username, s.smtp_password)
                smtp.send_message(msg)
        log.info("Email sent to %s (%s)", to, subject)
    except (smtplib.SMTPException, OSError) as exc:
        log.error("Failed to send email to %s: %s", to, exc)


def send_account_deletion_code(to: str, name: str, code: str, minutes: int) -> None:
    subject = f"{code} is your Apna Food account deletion code"
    text = (
        f"Hi {name},\n\n"
        "Someone asked to delete the Apna Food account for this email address.\n\n"
        f"If it was you, enter this code on the deletion page: {code}\n\n"
        f"It expires in {minutes} minutes. If you didn't ask for this, ignore this email; "
        "your account stays as it is.\n\n"
        "- Team Apna Food"
    )
    html = f"""\
<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;color:#121c2a">
  <h2 style="color:#ff6b35;margin:0 0 16px">Apna Food</h2>
  <p>Hi {name},</p>
  <p>Someone asked to <b>delete</b> the Apna Food account for this email address.
     If it was you, enter this code on the deletion page:</p>
  <p style="font-size:32px;font-weight:bold;letter-spacing:8px;background:#eff4ff;
            padding:16px;text-align:center;border-radius:12px">{code}</p>
  <p style="color:#594139">It expires in {minutes} minutes. If you didn't ask for this,
     ignore this email; your account stays as it is.</p>
</div>"""
    send_email(to, subject, text, html)


def send_password_reset_code(to: str, name: str, code: str, minutes: int) -> None:
    subject = f"{code} is your Apna Food password reset code"
    text = (
        f"Hi {name},\n\n"
        f"Your Apna Food password reset code is: {code}\n\n"
        f"It expires in {minutes} minutes. If you didn't ask to reset your password, "
        "you can ignore this email; your password won't change.\n\n"
        "- Team Apna Food"
    )
    html = f"""\
<div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;padding:24px;color:#121c2a">
  <h2 style="color:#ff6b35;margin:0 0 16px">Apna Food</h2>
  <p>Hi {name},</p>
  <p>Use this code to reset your password:</p>
  <p style="font-size:32px;font-weight:bold;letter-spacing:8px;background:#eff4ff;
            padding:16px;text-align:center;border-radius:12px">{code}</p>
  <p style="color:#594139">It expires in {minutes} minutes. If you didn't request this,
     you can safely ignore this email.</p>
</div>"""
    send_email(to, subject, text, html)

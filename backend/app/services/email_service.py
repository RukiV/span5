# =============================================================================
# E-posversending (SMTP via Gmail)
# Vloei:  calendar endpoint / reminder_scheduler → hierdie funksies
#         Hierdie word NIE deur die NotificationService gebruik nie.
#         email_enabled in NotificationPreference word tans nie hier gelees nie.
# Konfigurasie: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, EMAIL_FROM in .env
# =============================================================================
import os
import smtplib
import logging
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

logger = logging.getLogger(__name__)

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER", "")
SMTP_PASS = os.getenv("SMTP_PASS", "")
EMAIL_FROM = os.getenv("EMAIL_FROM", "")

# --- Stuur bevestiging wanneer 'n kalender-afspraak geskep word (slegs as notify_email=True op die gebeurtenis) ---
def send_event_created(
    to_email: str,
    event_title: str,
    start_datetime_str: str,
    location: str = "",
    description: str = "",
) -> bool:
    if not SMTP_USER or not SMTP_PASS:
        logger.warning("SMTP nie gekonfigureer. Stuur geen e-pos nie.")
        return False

    try:
        msg = MIMEMultipart()
        msg["From"] = EMAIL_FROM or SMTP_USER
        msg["To"] = to_email
        msg["Subject"] = f"Afspraak Geskep: {event_title}"

        location_html = f"<p><b>Plek:</b> {location}</p>" if location else ""
        desc_html = f"<p>{description}</p>" if description else ""

        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px;">
            <div style="background: #0E1E3B; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
                <h2 style="margin: 0;">Afspraak Geskep</h2>
            </div>
            <div style="padding: 20px; border: 1px solid #ddd; border-radius: 0 0 8px 8px;">
                <p style="font-size: 16px;">Jou afspraak is suksesvol geskep:</p>
                <h3 style="color: #0E1E3B;">{event_title}</h3>
                <p><b>Tyd:</b> {start_datetime_str}</p>
                {location_html}
                {desc_html}
                <hr style="border: none; border-top: 1px solid #eee;">
                <p style="color: #666; font-size: 12px;">
                    Akademia Fasiliteitbestuurstelsel
                </p>
            </div>
        </div>
        """

        msg.attach(MIMEText(body, "html"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)

        logger.info(f"Bevestiging e-pos gestuur na {to_email} vir '{event_title}'")
        return True

    except smtplib.SMTPAuthenticationError:
        logger.error("Gmail SMTP authenticatie fout — check SMTP_USER/SMTP_PASS in .env")
        return False
    except smtplib.SMTPException as e:
        logger.error(f"SMTP fout: {e}")
        return False
    except Exception as e:
        logger.error(f"Onverwagte fout met e-pos stuur: {e}")
        return False


# --- Stuur e-pos wanneer 'n werksopdrag toegewys word
#     LET WEL: Hierdie funksie word tans NERENS geroep nie (dooie kode).
#     As jy dit wil aktiveer, roep dit in die job.py endpoint. ---
def send_jobcard_assigned(
    to_email: str,
    job_desc: str,
    scheduled_str: str,
    cc_emails: list[str] | None = None,
) -> bool:
    if not SMTP_USER or not SMTP_PASS:
        logger.warning("SMTP nie gekonfigureer. Stuur geen e-pos nie.")
        return False

    try:
        msg = MIMEMultipart()
        msg["From"] = EMAIL_FROM or SMTP_USER
        msg["To"] = to_email
        msg["Subject"] = f"Werksopdrag Toegewys: {job_desc}"

        if cc_emails:
            msg["Cc"] = ", ".join(cc_emails)

        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px;">
            <div style="background: #0E1E3B; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
                <h2 style="margin: 0;">Werksopdrag Toegewys</h2>
            </div>
            <div style="padding: 20px; border: 1px solid #ddd; border-radius: 0 0 8px 8px;">
                <p style="font-size: 16px;">'n Werksopdrag is aan jou toegewys:</p>
                <h3 style="color: #0E1E3B;">{job_desc}</h3>
                <p><b>Geskeduleer:</b> {scheduled_str}</p>
                <hr style="border: none; border-top: 1px solid #eee;">
                <p style="color: #666; font-size: 12px;">
                    Akademia Fasiliteitbestuurstelsel
                </p>
            </div>
        </div>
        """

        msg.attach(MIMEText(body, "html"))

        recipients = [to_email] + (cc_emails or [])
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)

        logger.info(f"Werksopdrag toegewys e-pos gestuur na {to_email} (CC: {cc_emails or 'none'})")
        return True

    except smtplib.SMTPAuthenticationError:
        logger.error("Gmail SMTP authenticatie fout — check SMTP_USER/SMTP_PASS in .env")
        return False
    except smtplib.SMTPException as e:
        logger.error(f"SMTP fout: {e}")
        return False
    except Exception as e:
        logger.error(f"Onverwagte fout met e-pos stuur: {e}")
        return False


# --- Stuur 'n kalender-herinnering per e-pos
#     Geroep deur reminder_scheduler.py vir CalendarEvent waar notify_email=True ---
def send_reminder(
    to_email: str,
    event_title: str,
    start_datetime_str: str,
    location: str = "",
    description: str = "",
) -> bool:
    if not SMTP_USER or not SMTP_PASS:
        logger.warning("SMTP nie gekonfigureer. Stuur geen e-pos nie.")
        return False

    try:
        msg = MIMEMultipart()
        msg["From"] = EMAIL_FROM or SMTP_USER
        msg["To"] = to_email
        msg["Subject"] = f"Herinnering: {event_title}"

        location_html = f"<p><b>Plek:</b> {location}</p>" if location else ""
        desc_html = f"<p>{description}</p>" if description else ""

        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px;">
            <div style="background: #0E1E3B; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
                <h2 style="margin: 0;">Kalender Herinnering</h2>
            </div>
            <div style="padding: 20px; border: 1px solid #ddd; border-radius: 0 0 8px 8px;">
                <h3 style="color: #0E1E3B;">{event_title}</h3>
                <p><b>Tyd:</b> {start_datetime_str}</p>
                {location_html}
                {desc_html}
                <hr style="border: none; border-top: 1px solid #eee;">
                <p style="color: #666; font-size: 12px;">
                    Akademia Fasiliteitbestuurstelsel
                </p>
            </div>
        </div>
        """

        msg.attach(MIMEText(body, "html"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)

        logger.info(f"E-pos herinnering gestuur na {to_email} vir '{event_title}'")
        return True

    except smtplib.SMTPAuthenticationError:
        logger.error("Gmail SMTP authenticatie fout — check SMTP_USER/SMTP_PASS in .env")
        return False
    except smtplib.SMTPException as e:
        logger.error(f"SMTP fout: {e}")
        return False
    except Exception as e:
        logger.error(f"Onverwagte fout met e-pos stuur: {e}")
        return False


def send_password_reset(to_email: str, reset_url: str) -> bool:
    if not SMTP_USER or not SMTP_PASS:
        logger.warning("SMTP nie gekonfigureer. Stuur geen wagwoordherstel-e-pos nie.")
        return False

    try:
        msg = MIMEMultipart()
        msg["From"] = EMAIL_FROM or SMTP_USER
        msg["To"] = to_email
        msg["Subject"] = "Wagwoord Herstel - Akademia FBS"

        body = f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px;">
            <div style="background: #0E1E3B; color: white; padding: 20px; border-radius: 8px 8px 0 0;">
                <h2 style="margin: 0;">Wagwoord Herstel</h2>
            </div>
            <div style="padding: 20px; border: 1px solid #ddd; border-radius: 0 0 8px 8px;">
                <p style="font-size: 16px;">Jy het 'n versoek ontvang om jou wagwoord te herstel.</p>
                <p>Kliek op die skakel hieronder om jou wagwoord te herstel. Die skakel is geldig vir 1 uur.</p>
                <div style="text-align: center; margin: 30px 0;">
                    <a href="{reset_url}" style="background: #0E1E3B; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-size: 16px; display: inline-block;">
                        Herstel Wagwoord
                    </a>
                </div>
                <p style="color: #666; font-size: 13px;">As jy nie 'n wagwoordherstel versoek het nie, ignoreer hierdie e-pos.</p>
                <hr style="border: none; border-top: 1px solid #eee;">
                <p style="color: #666; font-size: 12px;">
                    Akademia Fasiliteitbestuurstelsel
                </p>
            </div>
        </div>
        """

        msg.attach(MIMEText(body, "html"))

        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)

        logger.info(f"Wagwoordherstel-e-pos gestuur na {to_email}")
        return True

    except smtplib.SMTPAuthenticationError:
        logger.error("Gmail SMTP authenticatie fout — check SMTP_USER/SMTP_PASS in .env")
        return False
    except smtplib.SMTPException as e:
        logger.error(f"SMTP fout: {e}")
        return False
    except Exception as e:
        logger.error(f"Onverwagte fout met e-pos stuur: {e}")
        return False

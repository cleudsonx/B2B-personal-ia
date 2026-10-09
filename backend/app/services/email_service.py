import os
import logging
from typing import Dict, Any, Optional
import httpx
from app.core.config import settings

logger = logging.getLogger(__name__)


class EmailService:
    """
    Serviço transacional de e-mails para o Mr. Coach.
    Suporta Resend API com fallback em mock resiliente.
    """

    def __init__(self, api_key: Optional[str] = None, email_from: Optional[str] = None):
        self.api_key = api_key or settings.RESEND_API_KEY
        self.email_from = email_from or settings.EMAIL_FROM

    def _get_template_html(
        self,
        confirmation_url: str,
        student_name: str,
        trainer_name: str,
    ) -> str:
        """
        Carrega o template HTML de confirmação de cadastro e injeta variáveis dinâmicas.
        """
        template_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))),
            "supabase",
            "templates",
            "confirm_signup.html",
        )

        try:
            if os.path.exists(template_path):
                with open(template_path, "r", encoding="utf-8") as f:
                    content = f.read()
                    # Injeta variáveis reais
                    content = content.replace("{{ .ConfirmationURL }}", confirmation_url)
                    content = content.replace("Prof. Responsável Vinculado", f"Prof. {trainer_name}")
                    return content
        except Exception as e:
            logger.warning(f"Não foi possível ler template customizado em {template_path}: {e}")

        # Fallback inline elegante
        return f"""
        <div style="font-family: sans-serif; padding: 24px; background: #FAFAF9; color: #111;">
          <h2 style="color: #059669;">MR. COACH • CONVITE EXCLUSIVO</h2>
          <p>Olá, <strong>{student_name}</strong>!</p>
          <p>Seu Personal Trainer <strong>Prof. {trainer_name}</strong> convidou você para o Mr. Coach.</p>
          <p><a href="{confirmation_url}" style="display:inline-block; padding: 14px 28px; background: #0F172A; color: #FFF; text-decoration: none; border-radius: 12px; font-weight: bold;">Confirmar Acesso & Iniciar Anamnese →</a></p>
          <p style="font-size: 12px; color: #666;">Se o botão não funcionar, acesse: {confirmation_url}</p>
        </div>
        """

    async def send_student_invitation_email(
        self,
        student_email: str,
        student_name: str,
        trainer_name: str,
        confirmation_url: str,
    ) -> Dict[str, Any]:
        """
        Dispara o e-mail estilizado de confirmação/convite para o aluno.
        """
        subject = f"Seu Personal {trainer_name} te convidou para o Mr. Coach 🏅"
        html_body = self._get_template_html(
            confirmation_url=confirmation_url,
            student_name=student_name,
            trainer_name=trainer_name,
        )

        # Se não houver chave Resend configurada, opera em modo Mock sem falhar
        if not self.api_key:
            logger.info(
                f"[Email Mock] Enviando e-mail de convite para {student_email} (De: {self.email_from}): {subject}"
            )
            return {
                "status": "success",
                "mode": "mock",
                "recipient": student_email,
                "subject": subject,
                "confirmation_url": confirmation_url,
            }

        # Disparo via Resend API oficial
        try:
            url = "https://api.resend.com/emails"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }
            payload = {
                "from": self.email_from,
                "to": [student_email],
                "subject": subject,
                "html": html_body,
            }

            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(url, headers=headers, json=payload)
                if res.status_code in (200, 201):
                    logger.info(f"E-mail de convite enviado via Resend para {student_email} (De: {payload['from']})")
                    return {"status": "sent", "provider": "resend", "data": res.json()}
                elif res.status_code == 403 and "not verified" in res.text.lower():
                    logger.warning(f"Domínio em '{self.email_from}' ainda não foi verificado no Resend. Executando fallback temporário com 'onboarding@resend.dev'...")
                    payload["from"] = "Mr. Coach <onboarding@resend.dev>"
                    fallback_res = await client.post(url, headers=headers, json=payload)
                    if fallback_res.status_code in (200, 201):
                        logger.info(f"E-mail enviado com sucesso via fallback do Resend para {student_email}")
                        return {
                            "status": "sent",
                            "provider": "resend",
                            "data": fallback_res.json(),
                            "note": "Enviado via sandbox temporário enquanto o domínio shaipados.com propaga as entradas DNS."
                        }
                    else:
                        logger.warning(f"Fallback Resend retornou {fallback_res.status_code}: {fallback_res.text}")
                        if fallback_res.status_code == 403:
                            return {"status": "error", "code": fallback_res.status_code, "detail": "Sua conta Resend é nova e precisa de um domínio verificado para enviar e-mails a terceiros. No momento (Sandbox), apenas e-mails verificados no painel podem receber mensagens."}
                        return {"status": "error", "code": fallback_res.status_code, "detail": fallback_res.text}
                elif res.status_code == 403:
                    logger.warning(f"Resend erro de permissão (403): {res.text}")
                    return {"status": "error", "code": res.status_code, "detail": "Sua conta Resend é nova e precisa de um domínio verificado para enviar e-mails a terceiros. No momento (Sandbox), apenas e-mails verificados no painel podem receber mensagens."}
                else:
                    logger.warning(f"Resend retornou status {res.status_code}: {res.text}")
                    return {"status": "error", "code": res.status_code, "detail": res.text}
        except Exception as e:
            logger.error(f"Erro ao disparar e-mail via Resend: {e}")
            return {"status": "failed", "error": str(e)}

    async def send_recovery_otp_email(
        self,
        recipient_email: str,
        user_name: str,
        otp_code: str,
    ) -> Dict[str, Any]:
        """
        Dispara o e-mail com código de segurança (OTP) de recuperação de senha.
        """
        subject = f"Seu código de recuperação Mr. Coach: {otp_code} 🔑"
        html_body = f"""
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; padding: 32px 24px; background: #0b141a; color: #e9edef; max-width: 520px; margin: 0 auto; border-radius: 16px;">
          <div style="text-align: center; margin-bottom: 24px;">
            <h1 style="color: #25d366; font-size: 22px; font-weight: 800; letter-spacing: 0.5px; margin: 0;">MR. COACH</h1>
            <p style="color: #8696a0; font-size: 13px; margin: 4px 0 0 0;">Segurança da Conta</p>
          </div>
          <div style="background: #111b21; border: 1px solid #202c33; border-radius: 12px; padding: 24px; text-align: center;">
            <p style="color: #e9edef; font-size: 15px; margin: 0 0 16px 0;">Olá, <strong>{user_name}</strong>!</p>
            <p style="color: #8696a0; font-size: 14px; line-height: 1.5; margin: 0 0 20px 0;">
              Recebemos uma solicitação para redefinir o acesso à sua conta. Use o código de verificação abaixo:
            </p>
            <div style="display: inline-block; padding: 14px 28px; background: #202c33; border: 1px solid #25d366; border-radius: 10px; font-size: 28px; font-weight: 800; letter-spacing: 6px; color: #25d366;">
              {otp_code}
            </div>
            <p style="color: #8696a0; font-size: 12px; margin: 20px 0 0 0;">
              Este código é válido por <strong>10 minutos</strong>.<br/>
              Se você não solicitou a redefinição, ignore este e-mail.
            </p>
          </div>
          <p style="text-align: center; font-size: 11px; color: #8696a0; margin-top: 24px;">
            Mr. Coach • Plataforma B2B para Personal Trainers &amp; Alunos
          </p>
        </div>
        """

        if not self.api_key:
            logger.info(
                f"[Email Mock] OTP de recuperação para {recipient_email} (Código: {otp_code})"
            )
            return {
                "status": "success",
                "mode": "mock",
                "recipient": recipient_email,
                "subject": subject,
                "otp_code": otp_code,
            }

        try:
            url = "https://api.resend.com/emails"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }
            payload = {
                "from": self.email_from,
                "to": [recipient_email],
                "subject": subject,
                "html": html_body,
            }

            async with httpx.AsyncClient(timeout=10.0) as client:
                res = await client.post(url, headers=headers, json=payload)
                if res.status_code in (200, 201):
                    logger.info(f"OTP de recuperação enviado via Resend para {recipient_email}")
                    return {"status": "sent", "provider": "resend", "data": res.json()}
                elif res.status_code == 403 and "not verified" in res.text.lower():
                    payload["from"] = "Mr. Coach <onboarding@resend.dev>"
                    fallback_res = await client.post(url, headers=headers, json=payload)
                    if fallback_res.status_code in (200, 201):
                        logger.info(f"OTP enviado via sandbox Resend para {recipient_email}")
                        return {"status": "sent", "provider": "resend", "data": fallback_res.json()}
                    return {"status": "error", "code": fallback_res.status_code, "detail": fallback_res.text}
                else:
                    logger.warning(f"Resend retornou status {res.status_code} no envio do OTP: {res.text}")
                    return {"status": "error", "code": res.status_code, "detail": res.text}
        except Exception as e:
            logger.error(f"Erro ao disparar OTP via Resend: {e}")
            return {"status": "failed", "error": str(e)}


email_service = EmailService()


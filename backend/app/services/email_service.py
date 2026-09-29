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
                    logger.info(f"E-mail de convite enviado via Resend para {student_email}")
                    return {"status": "sent", "provider": "resend", "data": res.json()}
                else:
                    logger.warning(f"Resend retornou status {res.status_code}: {res.text}")
                    return {"status": "error", "code": res.status_code, "detail": res.text}
        except Exception as e:
            logger.error(f"Erro ao disparar e-mail via Resend: {e}")
            return {"status": "failed", "error": str(e)}


email_service = EmailService()

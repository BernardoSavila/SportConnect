import nodemailer from 'nodemailer';

let transporterPromise: Promise<nodemailer.Transporter> | null = null;

/**
 * Em desenvolvimento/demonstração académica não temos uma conta de email
 * real configurada, por isso usamos o Ethereal (https://ethereal.email) —
 * um serviço de SMTP falso, feito exatamente para testes como este. Os
 * emails nunca chegam a uma caixa de entrada real; em vez disso, o
 * nodemailer devolve um link de pré-visualização que mostra o email tal
 * como teria sido recebido. Esse link fica visível na consola do servidor.
 *
 * Para produção a sério, bastaria substituir isto por um transporter com
 * as credenciais de um serviço real (SendGrid, Mailgun, SMTP institucional,
 * etc.) — o resto do código (o texto do email, quando é chamado) mantém-se
 * igual.
 */
async function getTransporter(): Promise<nodemailer.Transporter> {
  if (!transporterPromise) {
    transporterPromise = (async () => {
      if (process.env.SMTP_HOST) {
        return nodemailer.createTransport({
          host: process.env.SMTP_HOST,
          port: Number(process.env.SMTP_PORT) || 587,
          secure: false,
          auth: process.env.SMTP_USER
            ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS }
            : undefined,
        });
      }
      const testAccount = await nodemailer.createTestAccount();
      return nodemailer.createTransport({
        host: 'smtp.ethereal.email',
        port: 587,
        secure: false,
        auth: { user: testAccount.user, pass: testAccount.pass },
      });
    })();
  }
  return transporterPromise;
}

export async function sendPasswordResetEmail(to: string, name: string, code: string): Promise<void> {
  const transporter = await getTransporter();
  const info = await transporter.sendMail({
    from: '"SportConnect" <no-reply@sportconnect.pt>',
    to,
    subject: 'Código de recuperação de password — SportConnect',
    text:
      `Olá ${name},\n\n` +
      `Recebemos um pedido para recuperar a tua password no SportConnect.\n\n` +
      `O teu código de recuperação é: ${code}\n\n` +
      `Este código é válido durante 15 minutos e só pode ser usado uma vez.\n\n` +
      `Se não pediste esta recuperação, ignora este email — a tua password mantém-se inalterada.`,
    html:
      `<p>Olá ${name},</p>` +
      `<p>Recebemos um pedido para recuperar a tua password no <strong>SportConnect</strong>.</p>` +
      `<p style="font-size:28px;font-weight:bold;letter-spacing:4px;">${code}</p>` +
      `<p>Este código é válido durante <strong>15 minutos</strong> e só pode ser usado uma vez.</p>` +
      `<p>Se não pediste esta recuperação, ignora este email — a tua password mantém-se inalterada.</p>`,
  });

  const previewUrl = nodemailer.getTestMessageUrl(info);
  if (previewUrl) {
    // eslint-disable-next-line no-console
    console.log(`\n📧 Email de recuperação (pré-visualização): ${previewUrl}\n`);
  }
}

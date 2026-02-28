import nodemailer from 'npm:nodemailer@6.9.16';

const host = Deno.env.get('SMTP_HOST') ?? 'smtp.gmail.com';
const port = Number(Deno.env.get('SMTP_PORT') ?? '587');
const user = Deno.env.get('SMTP_USER') ?? '';
const pass = Deno.env.get('SMTP_PASS') ?? '';
const from = Deno.env.get('EMAIL_FROM') ?? user;

function hasSmtpConfig() {
  return user.length > 0 && pass.length > 0;
}

function createTransport() {
  return nodemailer.createTransport({
    host,
    port,
    secure: port == 465,
    auth: { user, pass },
  });
}

export type OrderEmailItem = {
  name: string;
  quantity: number;
  unitPrice: number;
};

export async function sendOrderInvoiceEmail(params: {
  to: string;
  orderId: string;
  customerName: string;
  totalAmount: number;
  trackingNumber: string;
  shippingAddress: string;
  shippingCost: number;
  items: OrderEmailItem[];
}) {
  if (!hasSmtpConfig() || params.to.length == 0) {
    console.warn('SMTP config missing or recipient empty. Skipping invoice email.');
    return;
  }

  const transport = createTransport();
  const date = new Date().toLocaleDateString('es-ES');

  const rows = params.items
    .map((item) => {
      const total = ((item.unitPrice * item.quantity) / 100).toFixed(2);
      const unit = (item.unitPrice / 100).toFixed(2);
      return `<tr>
          <td style="padding:8px;border-bottom:1px solid #eee;">${item.name}</td>
          <td style="padding:8px;border-bottom:1px solid #eee;text-align:center;">${item.quantity}</td>
          <td style="padding:8px;border-bottom:1px solid #eee;text-align:right;">€${unit}</td>
          <td style="padding:8px;border-bottom:1px solid #eee;text-align:right;">€${total}</td>
        </tr>`;
    })
    .join('');

  await transport.sendMail({
    from,
    to: params.to,
    subject: `Factura pedido ${params.orderId.substring(0, 8).toUpperCase()}`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:700px;margin:0 auto;padding:20px;">
        <h2 style="margin:0;color:#0f172a;">Aurum Fashion</h2>
        <p style="color:#475569;">Gracias por tu compra, ${params.customerName}.</p>
        <p><strong>Pedido:</strong> #${params.orderId.substring(0, 8).toUpperCase()}<br/>
        <strong>Fecha:</strong> ${date}<br/>
        <strong>Seguimiento:</strong> ${params.trackingNumber}</p>
        <p><strong>Envio:</strong> ${params.shippingAddress}</p>

        <table style="width:100%;border-collapse:collapse;margin-top:12px;">
          <thead>
            <tr>
              <th style="text-align:left;padding:8px;border-bottom:2px solid #ddd;">Producto</th>
              <th style="text-align:center;padding:8px;border-bottom:2px solid #ddd;">Cantidad</th>
              <th style="text-align:right;padding:8px;border-bottom:2px solid #ddd;">Precio</th>
              <th style="text-align:right;padding:8px;border-bottom:2px solid #ddd;">Total</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
        
        <div style="text-align:right;margin-top:16px;">
          <p style="font-size:16px;margin:4px 0;">Gastos de envío: €${(params.shippingCost / 100).toFixed(2)}</p>
          <p style="font-size:18px;margin:4px 0;"><strong>Total: €${(params.totalAmount / 100).toFixed(2)}</strong></p>
        </div>
      </div>
    `,
  });
}

export async function sendBroadcastEmail(params: {
  to: string;
  subject: string;
  title: string;
  message: string;
  couponCode?: string;
  couponLabel?: string;
}) {
  if (!hasSmtpConfig()) {
    throw new Error('SMTP config is missing');
  }
  if (!params.to || params.to.trim().length == 0) {
    throw new Error('Recipient email is required');
  }

  const transport = createTransport();
  const safeTitle = params.title.trim().length > 0 ? params.title : 'Aurum Fashion';
  const couponHtml = params.couponCode
    ? `
      <div style="margin:16px 0;padding:12px;border:1px dashed #0f172a;border-radius:8px;background:#f8fafc;">
        <p style="margin:0 0 8px 0;font-weight:700;">${params.couponLabel ?? 'Tu cupon'}</p>
        <p style="margin:0;font-size:22px;font-weight:800;letter-spacing:1px;">${params.couponCode}</p>
      </div>
    `
    : '';

  await transport.sendMail({
    from,
    to: params.to,
    subject: params.subject,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:700px;margin:0 auto;padding:20px;">
        <h2 style="margin:0 0 12px 0;color:#0f172a;">${safeTitle}</h2>
        <div style="color:#334155;line-height:1.6;white-space:pre-wrap;">${params.message}</div>
        ${couponHtml}
      </div>
    `,
  });
}

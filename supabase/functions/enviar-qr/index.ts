import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { enviarCorreoBrevo, remitenteContacto } from "../_shared/brevo.ts";

// --- 1. CABECERAS CORS (Obligatorias para llamar desde React) ---
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SUPABASE_URL = Deno.env.get("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const PIE_DE_FIRMA_URL = "https://evjocwzmlsyjixzihxep.supabase.co/storage/v1/object/public/imagenes/PIE-DE-FIRMA.png"; 

serve(async (req) => {
  // --- 2. MANEJO DE PREFLIGHT (CORS) ---
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const registro = payload.record;

    if (!registro || !registro.email) {
      return new Response("Sin email destinatario", { 
        status: 200, 
        headers: corsHeaders 
      });
    }

    // 2. Obtener info del evento
    const { data: evento, error: errorEvento } = await supabase
      .from("eventos")
      .select("nombre, tipo_registro, fecha, lugar, direccion")
      .eq("id", registro.evento_id)
      .single();

    if (errorEvento) throw errorEvento;

    const nombreEvento = evento?.nombre || "Evento Transworld";

    // 3. Obtener el nombre del usuario de la App que hizo el registro
    let nombreRegistrador = "nuestro equipo";
    if (registro.ingresado_por) {
        const { data: perfil } = await supabase
            .from("perfiles")
            .select("nombre_completo")
            .eq("id", registro.ingresado_por)
            .single();
            
        if (perfil?.nombre_completo) {
            nombreRegistrador = perfil.nombre_completo;
        }
    }
    
    // 4. Formatear la fecha 
    let fechaTexto = evento?.fecha || "[Fecha]";
    let anio = "2026", mes = "01", dia = "01";
    
    if (evento?.fecha && evento.fecha.includes('-')) {
        [anio, mes, dia] = evento.fecha.split('-');
        fechaTexto = `${dia}-${mes}-${anio}`;
    }

    // Calcular el día siguiente para el calendario
    const fechaObj = new Date(parseInt(anio), parseInt(mes) - 1, parseInt(dia));
    fechaObj.setDate(fechaObj.getDate() + 1);
    const anioFin = fechaObj.getFullYear();
    const mesFin = String(fechaObj.getMonth() + 1).padStart(2, '0');
    const diaFin = String(fechaObj.getDate()).padStart(2, '0');

    const lugarEvento = evento?.lugar || "Lugar del evento";
    const direccionEvento = evento?.direccion || "nuestras dependencias";
    
    // --- ENLACES PARA BOTONES DE CALENDARIO ---
    const ubicacion = `${direccionEvento}, ${lugarEvento}`;
    let desc = "";
    
    if (evento?.tipo_registro === "cliente") {
        desc = "Recuerda presentar tu código QR enviado al correo para la acreditación.";
    } else {
        desc = `Te esperamos en ${nombreEvento}. Contacto: contacto@transworld.cl`;
    }
    
    const googleCalUrl = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${encodeURIComponent(nombreEvento)}&dates=${anio}${mes}${dia}/${anioFin}${mesFin}${diaFin}&details=${encodeURIComponent(desc)}&location=${encodeURIComponent(ubicacion)}`;
    const outlookCalUrl = `https://outlook.live.com/calendar/0/deeplink/compose?path=/calendar/action/compose&rru=addevent&subject=${encodeURIComponent(nombreEvento)}&startdt=${anio}-${mes}-${dia}&enddt=${anioFin}-${mesFin}-${diaFin}&allday=true&body=${encodeURIComponent(desc)}&location=${encodeURIComponent(ubicacion)}`;
    // ------------------------------------------

    // 5. CONSTRUCCIÓN DEL CORREO (DOS PLANTILLAS)
    let htmlContent = "";

    if (evento?.tipo_registro === "cliente") {
        // ==========================================
        // PLANTILLA 1: EVENTO CON QR (Cliente)
        // ==========================================
        const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${registro.id}`;
        
        htmlContent = `
          <!DOCTYPE html>
          <html>
            <body style="font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px; color: #000; margin: 0;">
              <div style="max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f4f4f4;">
                
                <p style="font-size: 16px; margin-bottom: 5px;">Hola <strong>${registro.nombre_completo}</strong>.</p>
                <p style="font-size: 16px; line-height: 1.5; margin-top: 5px;">
                  Tu registro ha finalizado exitosamente para asistir a <strong>${nombreEvento}</strong> a realizarse el <strong>${fechaTexto}</strong> en <strong>${lugarEvento}</strong>, ubicado en <strong>${direccionEvento}</strong>.
                </p>
                

                
                <p style="font-size: 16px; margin-bottom: 40px; margin-top: 40px; text-align: center;">
                  Presenta el siguiente Código QR en la acreditación del evento para poder ingresar:
                </p>
                
                <div style="text-align: center; margin-bottom: 40px;">
                   <img src="${qrUrl}" alt="Código QR" width="250" height="250" style="display: block; margin: 0 auto; background-color: #fff;" />
                </div>
                
                <div style="text-align: center; font-size: 16px; font-weight: bold; margin-bottom: 50px;">
                  <p style="margin: 0;">Consultas a</p>
                  <p style="margin: 0; color: #206591; text-decoration: underline;">contacto@transworld.cl</p>
                </div>
                                <div style="margin-top: 35px; margin-bottom: 45px; text-align: center;">
                  <p style="font-size: 15px; margin-bottom: 20px; color: #555;">Agéndalo en tu calendario:</p>
                  
                  <table border="0" cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                    <tr>
                      <td align="center" style="padding: 0 10px 10px 10px;">
                        <table border="0" cellspacing="0" cellpadding="0">
                          <tr>
                            <td align="center" bgcolor="#0078D4" style="border-radius: 6px;">
                              <a href="${outlookCalUrl}" target="_blank" style="font-size: 15px; font-family: Arial, sans-serif; color: #ffffff; text-decoration: none; padding: 12px 24px; display: inline-block; font-weight: bold; border-radius: 6px; border: 1px solid #0078D4;">
                                📅 Outlook
                              </a>
                            </td>
                          </tr>
                        </table>
                      </td>
                      <td align="center" style="padding: 0 10px 10px 10px;">
                        <table border="0" cellspacing="0" cellpadding="0">
                          <tr>
                            <td align="center" bgcolor="#4285F4" style="border-radius: 6px;">
                              <a href="${googleCalUrl}" target="_blank" style="font-size: 15px; font-family: Arial, sans-serif; color: #ffffff; text-decoration: none; padding: 12px 24px; display: inline-block; font-weight: bold; border-radius: 6px; border: 1px solid #4285F4;">
                                📅 Google Calendar
                              </a>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </div>
                
                <div style="font-size: 16px; margin-bottom: 10px;">
                  <p style="margin: 0; text-decoration: underline; font-weight: bold;">Saludos cordiales.</p>
                  <p style="margin: 0;">Marketing</p>
                  <p style="margin: 0; font-weight: bold;">Transworld</p>
                </div>

                <div>
                   <img src="${PIE_DE_FIRMA_URL}" alt="Transworld" width="560" style="width: 100%; max-width: 560px; height: auto; display: block; border: none;" />
                </div>

              </div>
            </body>
          </html>
        `;
    } else {
        // ==========================================
        // PLANTILLA 2: EVENTO SIN QR (Comercial)
        // ==========================================
        htmlContent = `
          <!DOCTYPE html>
          <html>
            <body style="font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px; color: #000; margin: 0;">
              <div style="max-width: 600px; margin: 0 auto; padding: 20px; background-color: #f4f4f4;">
                
                <p style="font-size: 16px; margin-bottom: 5px;">Hola <strong>${registro.nombre_completo}</strong>.</p>
                
                <p style="font-size: 16px; line-height: 1.5; margin-top: 5px;">
                  Te informamos que <strong>${nombreRegistrador}</strong> te ha registrado para participar en el evento/actividad <strong>${nombreEvento}</strong> a realizarse el <strong>${fechaTexto}</strong> en <strong>${lugarEvento}</strong>, ubicado en <strong>${direccionEvento}</strong>.
                </p>
                
                <p style="font-size: 16px; line-height: 1.5; margin-top: 15px;">
                  Si tienes alguna consulta, comunícate con <strong>${nombreRegistrador}</strong> o escríbenos a <a href="mailto:contacto@transworld.cl" style="color: #206591; text-decoration: underline;">contacto@transworld.cl</a>.
                </p>

                <div style="margin-top: 35px; margin-bottom: 55px; text-align: center;">
                  <p style="font-size: 16px; margin-bottom: 20px; font-weight: bold; color: #333;">¡Agéndalo para que no te lo pierdas!</p>
                  
                  <table border="0" cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                    <tr>
                      <td align="center" style="padding: 0 10px 10px 10px;">
                        <table border="0" cellspacing="0" cellpadding="0">
                          <tr>
                            <td align="center" bgcolor="#0078D4" style="border-radius: 6px;">
                              <a href="${outlookCalUrl}" target="_blank" style="font-size: 15px; font-family: Arial, sans-serif; color: #ffffff; text-decoration: none; padding: 12px 24px; display: inline-block; font-weight: bold; border-radius: 6px; border: 1px solid #0078D4;">
                                📅 Outlook
                              </a>
                            </td>
                          </tr>
                        </table>
                      </td>
                      <td align="center" style="padding: 0 10px 10px 10px;">
                        <table border="0" cellspacing="0" cellpadding="0">
                          <tr>
                            <td align="center" bgcolor="#4285F4" style="border-radius: 6px;">
                              <a href="${googleCalUrl}" target="_blank" style="font-size: 15px; font-family: Arial, sans-serif; color: #ffffff; text-decoration: none; padding: 12px 24px; display: inline-block; font-weight: bold; border-radius: 6px; border: 1px solid #4285F4;">
                                📅 Google Calendar
                              </a>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </div>

                <div style="font-size: 16px; margin-bottom: 10px;">
                  <p style="margin: 0; text-decoration: underline; font-weight: bold;">Saludos cordiales.</p>
                  <p style="margin: 0;">Marketing</p>
                  <p style="margin: 0; font-weight: bold;">Transworld</p>
                </div>

                <div>
                   <img src="${PIE_DE_FIRMA_URL}" alt="Transworld" width="560" style="width: 100%; max-width: 560px; height: auto; display: block; border: none;" />
                </div>

              </div>
            </body>
          </html>
        `;
    }

    // 6. Enviar correo usando BREVO API (prioridad alta para Outlook)
    const res = await enviarCorreoBrevo({
      sender: {
        name: `Registro evento ${nombreEvento}`,
        email: remitenteContacto.email,
      },
      replyTo: remitenteContacto,
      to: [
        { email: registro.email, name: registro.nombre_completo },
      ],
      subject: `Confirmación de Registro a ${nombreEvento}`,
      htmlContent: htmlContent,
      tags: ["confirmacion-registro"],
    });

    if (!res.ok) {
        const errorData = await res.text();
        console.error("Error Brevo:", errorData);
        throw new Error(`Error enviando email: ${errorData}`);
    }

    const data = await res.json();
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });

  } catch (error) {
    console.error("Error Edge Function:", error.message);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 500,
    });
  }
});
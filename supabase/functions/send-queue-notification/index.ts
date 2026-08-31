import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    const body = await req.json();

    const ticketId = body.ticket_id;
    const type = body.type ?? "called";

    if (!ticketId) {
      return new Response(
        JSON.stringify({
          error: "ticket_id_required",
        }),
        {
          status: 400,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // =====================================================
    // SUPABASE
    // =====================================================

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: ticket, error } =
      await supabase
        .from("queue_tickets")
        .select(
          `
          id,
          ticket_number,
          customer_name,
          phone,
          status,
          fcm_token
          `,
        )
        .eq("id", ticketId)
        .maybeSingle();

    if (error) {
      throw error;
    }

    if (!ticket) {
      return new Response(
        JSON.stringify({
          error: "ticket_not_found",
        }),
        {
          status: 404,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    if (!ticket.fcm_token) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "FCM_TOKEN_NOT_FOUND",
        }),
        {
          status: 200,
          headers: {
            ...corsHeaders,
            "Content-Type": "application/json",
          },
        },
      );
    }

    // =====================================================
    // FIREBASE
    // =====================================================

    const firebaseProjectId =
      Deno.env.get("FIREBASE_PROJECT_ID")!;

    const serviceAccountJson =
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

    if (!firebaseProjectId ||
        !serviceAccountJson) {
      throw new Error(
        "FIREBASE_CONFIGURATION_MISSING",
      );
    }

    const serviceAccount =
      JSON.parse(serviceAccountJson);

    // =====================================================
    // GET GOOGLE ACCESS TOKEN
    // =====================================================

    const accessToken =
      await createGoogleAccessToken(
        serviceAccount,
      );

    // =====================================================
    // NOTIFICATION CONTENT
    // =====================================================

    let title = "";
    let message = "";

    switch (type) {
      case "called":
        title = "🔔 حان دورك";
        message =
          `الزبون رقم ${ticket.ticket_number}، حان دورك الآن.`;
        break;

      case "near":
        title = "⏳ دورك اقترب";
        message =
          `دورك رقم ${ticket.ticket_number} اقترب. استعد.`;
        break;

      case "cancelled":
        title = "❌ تم إلغاء الدور";
        message =
          `تم إلغاء دورك رقم ${ticket.ticket_number}.`;
        break;

      case "completed":
        title = "✅ انتهى دورك";
        message =
          `تم الانتهاء من دورك رقم ${ticket.ticket_number}.`;
        break;

      default:
        title = "تحديث الدور";
        message =
          `هناك تحديث بخصوص دورك رقم ${ticket.ticket_number}.`;
    }

    // =====================================================
    // FCM HTTP V1
    // =====================================================

    const fcmUrl =
      `https://fcm.googleapis.com/v1/projects/` +
      `${firebaseProjectId}/messages:send`;

    const fcmResponse = await fetch(
      fcmUrl,
      {
        method: "POST",
        headers: {
          "Authorization":
            `Bearer ${accessToken}`,
          "Content-Type":
            "application/json",
        },
        body: JSON.stringify({
          message: {
            token: ticket.fcm_token,

            notification: {
              title: title,
              body: message,
            },

            data: {
              type: type,
              ticket_id:
                ticket.id.toString(),
              ticket_number:
                ticket.ticket_number.toString(),
            },

            android: {
              priority: "high",

              notification: {
                channel_id:
                  "queue_notifications",

                sound: "default",

                default_sound: true,

                notification_priority:
                  "PRIORITY_HIGH",
              },
            },
          },
        }),
      },
    );

    const fcmResult =
      await fcmResponse.json();

    if (!fcmResponse.ok) {
      console.error(
        "FCM ERROR:",
        fcmResult,
      );

      return new Response(
        JSON.stringify({
          success: false,
          error: "FCM_SEND_FAILED",
          details: fcmResult,
        }),
        {
          status: 500,
          headers: {
            ...corsHeaders,
            "Content-Type":
              "application/json",
          },
        },
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        message_id:
          fcmResult.name ?? null,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type":
            "application/json",
        },
      },
    );
  } catch (error) {
    console.error(error);

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders,
          "Content-Type":
            "application/json",
        },
      },
    );
  }
});


// =========================================================
// GOOGLE ACCESS TOKEN
// =========================================================

async function createGoogleAccessToken(
  serviceAccount: any,
): Promise<string> {
  const now =
    Math.floor(Date.now() / 1000);

  const header = {
    alg: "RS256",
    typ: "JWT",
  };

  const payload = {
    iss: serviceAccount.client_email,

    scope:
      "https://www.googleapis.com/auth/firebase.messaging",

    aud:
      "https://oauth2.googleapis.com/token",

    iat: now,

    exp: now + 3600,
  };

  const unsignedToken =
    `${base64url(JSON.stringify(header))}.` +
    `${base64url(JSON.stringify(payload))}`;

  const privateKey =
    await importPrivateKey(
      serviceAccount.private_key,
    );

  const signature =
    await crypto.subtle.sign(
      {
        name: "RSASSA-PKCS1-v1_5",
      },
      privateKey,
      new TextEncoder().encode(
        unsignedToken,
      ),
    );

  const jwt =
    `${unsignedToken}.${base64urlBytes(
      new Uint8Array(signature),
    )}`;

  const response = await fetch(
    "https://oauth2.googleapis.com/token",
    {
      method: "POST",

      headers: {
        "Content-Type":
          "application/x-www-form-urlencoded",
      },

      body:
        "grant_type=" +
        encodeURIComponent(
          "urn:ietf:params:oauth:grant-type:jwt-bearer",
        ) +
        "&assertion=" +
        encodeURIComponent(jwt),
    },
  );

  const result =
    await response.json();

  if (!response.ok) {
    throw new Error(
      JSON.stringify(result),
    );
  }

  return result.access_token;
}


// =========================================================
// RSA PRIVATE KEY
// =========================================================

async function importPrivateKey(
  pem: string,
): Promise<CryptoKey> {
  const pemContents =
    pem
      .replace(
        "-----BEGIN PRIVATE KEY-----",
        "",
      )
      .replace(
        "-----END PRIVATE KEY-----",
        "",
      )
      .replace(/\s/g, "");

  const binary =
    Uint8Array.from(
      atob(pemContents),
      (c) => c.charCodeAt(0),
    );

  return crypto.subtle.importKey(
    "pkcs8",
    binary.buffer,
    {
      name:
        "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );
}


// =========================================================
// BASE64 URL
// =========================================================

function base64url(
  input: string,
): string {
  return btoa(input)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

function base64urlBytes(
  bytes: Uint8Array,
): string {
  let binary = "";

  for (
    let i = 0;
    i < bytes.length;
    i++
  ) {
    binary += String.fromCharCode(
      bytes[i],
    );
  }

  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}